import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/salvar_arquivo.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

const _categorias = {
  '': 'Todas',
  'operador': 'Operador',
  'supervisor': 'Supervisor',
  'prestador': 'Prestador de Serviço',
};

/// Relatórios: registros de acesso (1ª entrada e última saída por pessoa/dia).
class RelatoriosScreen extends StatefulWidget {
  final VoidCallback onMenu;
  final ValueListenable<int> tabRefresh;
  const RelatoriosScreen({super.key, required this.onMenu, required this.tabRefresh});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> with TabRefresh {
  late Future<RelatorioData> _future;
  final _busca = TextEditingController();
  Timer? _debounce;

  // Vazio = padrão do servidor (do dia 1 do mês até hoje).
  DateTime? _de;
  DateTime? _ate;
  String _categoria = '';
  int _pagina = 1;
  bool _exportando = false;

  // Período realmente aplicado, devolvido pelo servidor.
  String _deAplicado = '';
  String _ateAplicado = '';

  @override
  ValueListenable<int> get tabRefresh => widget.tabRefresh;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  Map<String, String> get _query => {
        if (_de != null) 'de': isoData(_de!),
        if (_ate != null) 'ate': isoData(_ate!),
        'busca': _busca.text.trim(),
        'categoria': _categoria,
        'pagina': '$_pagina',
      };

  Future<RelatorioData> _load() async {
    final res = await AppScope.read(context).api.get('/relatorios', query: _query);
    final data = RelatorioData.fromJson(res);
    _pagina = data.pagina;
    _deAplicado = data.de;
    _ateAplicado = data.ate;
    return data;
  }

  @override
  void reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  /// Muda um filtro e volta para a página 1.
  void _filtrar(VoidCallback change) {
    _pagina = 1;
    change();
    reload();
  }

  void _onBuscaChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _filtrar(() {}));
  }

  void _preset(DateTime de, DateTime ate) => _filtrar(() {
        _de = de;
        _ate = ate;
      });

  Future<void> _pickRange() async {
    final hoje = DateTime.now();
    final atualDe = parseIso(_deAplicado) ?? DateTime(hoje.year, hoje.month, 1);
    final atualAte = parseIso(_ateAplicado) ?? hoje;

    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      initialDateRange: DateTimeRange(start: atualDe, end: atualAte.isAfter(hoje) ? hoje : atualAte),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecionar período',
      saveText: 'Aplicar',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.accent, onPrimary: Colors.black),
        ),
        child: child!,
      ),
    );
    if (r != null) _preset(r.start, r.end);
  }

  Future<void> _exportar() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final q = _query..remove('pagina');
      final csv = await AppScope.read(context).api.getText('/relatorios/exportar', query: q);
      final nome = 'relatorio-acessos_${_deAplicado}_a_$_ateAplicado.csv';
      if (exportaParaPasta) {
        // Windows: salva em Downloads e oferece abrir a pasta
        final caminho = await salvarCsvNosDownloads(nome, csv);
        messenger.showSnackBar(SnackBar(
          content: const Text('Relatório salvo na pasta Downloads.'),
          action: SnackBarAction(label: 'Abrir pasta', onPressed: () => mostrarNaPasta(caminho)),
        ));
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(utf8.encode(csv), mimeType: 'text/csv', name: nome)],
          fileNameOverrides: [nome],
          subject: 'Relatório de acessos',
        ));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Não foi possível exportar o relatório.')));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Relatórios',
          subtitle: 'Registros de acesso do sistema',
          onMenu: widget.onMenu,
          actions: [
            IconButton(
              tooltip: 'Exportar CSV',
              onPressed: _exportando ? null : _exportar,
              icon: _exportando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Icon(Icons.file_download_outlined, color: context.pal.text),
            ),
          ],
        ),
        Expanded(
          child: AsyncBody<RelatorioData>(
            future: _future,
            onRefresh: _refresh,
            onRetry: reload,
            builder: (context, d) => PageList(children: [
              CardGrid(children: [
                StatCard(CardResumo(chave: 'rel_total', label: 'Total de Registros', valorTexto: fmtNum(d.total))),
                StatCard(CardResumo(chave: 'rel_hoje', label: 'Registros Hoje', valorTexto: fmtNum(d.hoje))),
                StatCard(CardResumo(chave: 'rel_duracao', label: 'Duração Média', valorTexto: d.duracaoMedia)),
                StatCard(CardResumo(chave: 'rel_pico', label: 'Pico de Entrada', valorTexto: d.pico)),
              ]),
              _Filtros(
                busca: _busca,
                onBusca: _onBuscaChanged,
                periodo: '${isoParaBr(_deAplicado)} - ${isoParaBr(_ateAplicado)}',
                onPeriodo: _pickRange,
                categoria: _categoria,
                onCategoria: (c) => _filtrar(() => _categoria = c),
                onPreset: _preset,
              ),
              _Registros(d),
              if (d.registros.isNotEmpty)
                _Paginacao(
                  data: d,
                  onPrev: d.pagina > 1 ? () => _filtrar(() => _pagina = d.pagina - 1) : null,
                  onNext: d.pagina < d.paginas ? () => _filtrar(() => _pagina = d.pagina + 1) : null,
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Filtros extends StatelessWidget {
  final TextEditingController busca;
  final ValueChanged<String> onBusca;
  final String periodo;
  final VoidCallback onPeriodo;
  final String categoria;
  final ValueChanged<String> onCategoria;
  final void Function(DateTime de, DateTime ate) onPreset;

  const _Filtros({
    required this.busca,
    required this.onBusca,
    required this.periodo,
    required this.onPeriodo,
    required this.categoria,
    required this.onCategoria,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hoje = DateTime.now();

    Widget preset(String label, DateTime de) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(label, style: TextStyle(fontSize: 12.5, color: pal.text, fontWeight: FontWeight.w600)),
            backgroundColor: pal.card,
            side: BorderSide(color: pal.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => onPreset(de, hoje),
          ),
        );

    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: busca,
            onChanged: onBusca,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: pal.text, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou função...',
              hintStyle: TextStyle(color: pal.textMuted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: pal.textMuted),
              filled: true,
              fillColor: pal.chip,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: border(pal.border),
              enabledBorder: border(pal.border),
              focusedBorder: border(AppColors.accent, 1.4),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPeriodo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: pal.chip,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pal.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: pal.textMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(periodo, style: AppText.strong(context, size: 14))),
                  Icon(Icons.keyboard_arrow_down_rounded, color: pal.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                preset('Hoje', hoje),
                preset('7 dias', hoje.subtract(const Duration(days: 6))),
                preset('30 dias', hoje.subtract(const Duration(days: 29))),
                preset('Este mês', DateTime(hoje.year, hoje.month, 1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Função', style: AppText.muted(context, size: 12.5)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final e in _categorias.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: categoria == e.key,
                  onSelected: (_) => onCategoria(e.key),
                  showCheckmark: false,
                  selectedColor: AppColors.accent,
                  backgroundColor: pal.card,
                  side: BorderSide(color: categoria == e.key ? AppColors.accent : pal.border),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: categoria == e.key ? Colors.black : pal.text,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Registros extends StatelessWidget {
  final RelatorioData data;
  const _Registros(this.data);

  @override
  Widget build(BuildContext context) {
    if (data.registros.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: context.pal.textMuted),
            const SizedBox(height: 10),
            Text('Nenhum registro encontrado', style: AppText.strong(context, size: 15)),
            const SizedBox(height: 4),
            Text('Ajuste os filtros ou o período.', style: AppText.muted(context)),
          ],
        ),
      );
    }
    final hoje = isoData(DateTime.now());
    return Column(
      children: [
        for (final r in data.registros) ...[
          _RegistroTile(r, noLocal: r.saida == null && r.dia == hoje),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RegistroTile extends StatelessWidget {
  final RegistroAcesso r;
  final bool noLocal;
  const _RegistroTile(this.r, {required this.noLocal});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (bg, fg) = switch (r.categoria) {
      'supervisor' => (const Color(0x1F7C3AED), AppColors.purple),
      'prestador' => (pal.warningBg, AppColors.warning),
      _ => (pal.accentSoft, AppColors.accentText),
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.black,
                child: Text(iniciais(r.nome), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nome, style: AppText.strong(context, size: 15), overflow: TextOverflow.ellipsis),
                    Text(r.cargo, style: AppText.muted(context, size: 12.5), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Pill(r.categoriaRotulo, background: bg, foreground: fg),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _info(context, Icons.event_rounded, isoParaBr(r.dia)),
              _info(context, Icons.login_rounded, r.entrada ?? '—'),
              _info(context, Icons.logout_rounded, r.saida ?? '—'),
              noLocal
                  ? const Pill('No local', background: Color(0x2922C55E), foreground: AppColors.success)
                  : _info(context, Icons.timer_outlined, r.duracao ?? '—', bold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String text, {bool bold = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.pal.textMuted),
          const SizedBox(width: 4),
          Text(text, style: bold ? AppText.strong(context, size: 12.5) : AppText.muted(context, size: 12.5)),
        ],
      );
}

class _Paginacao extends StatelessWidget {
  final RelatorioData data;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Paginacao({required this.data, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    final de = (data.pagina - 1) * data.porPagina + 1;
    final ate = de + data.registros.length - 1;
    return Row(
      children: [
        IconButton.filledTonal(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text(
            'Mostrando $de–$ate de ${fmtNum(data.total)}\nPágina ${data.pagina} de ${data.paginas}',
            textAlign: TextAlign.center,
            style: AppText.muted(context, size: 12.5),
          ),
        ),
        IconButton.filledTonal(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
      ],
    );
  }
}
