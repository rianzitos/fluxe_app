import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/layout.dart';
import '../core/producao_service.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

/// Produção (igual à tela /producao do site): quantos quilos foram produzidos e desperdiçados em cada refeição do
/// dia. O que é salvo vai para a mesma tabela do painel, da análise mensal e da previsão, que se atualizam sozinhos.
class ProducaoScreen extends StatefulWidget {
  /// Dia que abre primeiro (yyyy-MM-dd); sem ele, hoje.
  final String? dataInicial;
  const ProducaoScreen({super.key, this.dataInicial});

  @override
  State<ProducaoScreen> createState() => _ProducaoScreenState();
}

/// Lê os quilos digitados ("12,5" ou "12.5"). null = em branco; [double.nan] = não é número.
double? lerKg(String texto) {
  final t = texto.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (t.isEmpty) return null;
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return double.nan;
  return double.parse(t);
}

String _kg(double? v) => v == null ? '—' : '${fmtNum(v, decimals: v == v.roundToDouble() ? 0 : 1)} kg';
String _pct(double? v) => v == null ? '—' : '${fmtNum(v, decimals: 1)}%';
String _campo(double? v) => v == null ? '' : fmtNum(v, decimals: v == v.roundToDouble() ? 0 : (v * 10 == (v * 10).roundToDouble() ? 1 : 2)).replaceAll('.', '');

const _semana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// "Sex, 13/11".
String diaCurto(String iso) {
  final d = parseIso(iso);
  return d == null ? iso : '${_semana[d.weekday - 1]}, ${two(d.day)}/${two(d.month)}';
}

class _ProducaoScreenState extends State<ProducaoScreen> {
  late final AppController _app = AppScope.read(context);
  late final ProducaoService _servico = ProducaoService(_app.api);

  ProducaoDia? _dia;
  Object? _erro;
  bool _carregando = false;
  bool _salvando = false;
  bool _alterado = false;
  ({bool ok, String texto})? _status;
  final _produzido = <String, TextEditingController>{};
  final _desperdicado = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _carregar(widget.dataInicial);
    _app.aoVivo.mudancas.addListener(_mudouNoServidor);
  }

  @override
  void dispose() {
    _app.aoVivo.mudancas.removeListener(_mudouNoServidor);
    for (final c in [..._produzido.values, ..._desperdicado.values]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tempo real: a balança (ou alguém no site) mudou algo. Recarrega se ninguém estiver digitando aqui.
  void _mudouNoServidor() {
    if (!_alterado && !_salvando && _dia != null) _carregar(_dia!.data, silencioso: true);
  }

  Future<void> _carregar(String? data, {bool silencioso = false}) async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      if (!silencioso) _status = null;
    });
    try {
      _aplicar(await _servico.carregar(data));
    } catch (e) {
      if (!mounted) return;
      if (_dia == null) {
        setState(() => _erro = e);
      } else if (!silencioso) {
        setState(() => _status = (ok: false, texto: e is ApiException ? e.message : 'Não foi possível carregar o dia.'));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _aplicar(ProducaoDia dia) {
    if (!mounted) return;
    setState(() {
      _dia = dia;
      _erro = null;
      _alterado = false;
      for (final r in dia.refeicoes) {
        (_produzido[r.tipo] ??= TextEditingController()).text = _campo(r.produzido);
        (_desperdicado[r.tipo] ??= TextEditingController()).text = _campo(r.desperdicado);
      }
    });
  }

  Future<void> _irPara(String data) async {
    final dia = _dia;
    if (dia == null || data == dia.data) return;
    if (data.compareTo(dia.hoje) > 0) data = dia.hoje;
    if (_alterado) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text('Você digitou valores que ainda não foram salvos neste dia.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar editando')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _carregar(data);
  }

  Future<void> _escolherData() async {
    final dia = _dia!;
    final hoje = parseIso(dia.hoje)!;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: parseIso(dia.data) ?? hoje,
      firstDate: DateTime(2000),
      lastDate: hoje,
      helpText: 'Dia da produção',
    );
    if (escolhida != null) await _irPara(isoData(escolhida));
  }

  void _somarDias(int n) {
    final d = parseIso(_dia!.data)!;
    _irPara(isoData(DateTime(d.year, d.month, d.day + n)));
  }

  Future<void> _salvar() async {
    final dia = _dia!;
    FocusScope.of(context).unfocus();
    final itens = <Map<String, Object?>>[];
    for (final r in dia.refeicoes) {
      final p = lerKg(_produzido[r.tipo]!.text);
      final d = lerKg(_desperdicado[r.tipo]!.text);
      if ((p?.isNaN ?? false) || (d?.isNaN ?? false)) {
        setState(() => _status = (ok: false, texto: '${r.rotulo}: digite só números, por exemplo 12,5.'));
        return;
      }
      if (p != null && d != null && p > 0 && d > p) {
        setState(() => _status = (ok: false, texto: '${r.rotulo}: o desperdício não pode ser maior que o produzido.'));
        return;
      }
      // Campo apagado numa refeição já registrada = zera; em branco numa refeição nova = não mexe.
      if (p == null && d == null && !r.registrado) continue;
      itens.add({
        'tipo': r.tipo,
        'produzido': p ?? (r.registrado ? 0 : null),
        'desperdicado': d ?? (r.registrado ? 0 : null),
      });
    }
    if (itens.isEmpty) {
      setState(() => _status = (ok: false, texto: 'Preencha os quilos produzidos de pelo menos uma refeição.'));
      return;
    }

    setState(() {
      _salvando = true;
      _status = null;
    });
    try {
      final r = await _servico.salvar(dia.data, itens);
      _aplicar(r.dia);
      if (mounted) {
        setState(() => _status = (
              ok: true,
              texto: 'Produção de ${diaCurto(r.dia.data)} salva. O painel e a análise mensal já usam os números novos.',
            ));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _status = (ok: false, texto: e.message));
    } catch (_) {
      if (mounted) setState(() => _status = (ok: false, texto: 'Não foi possível salvar. Tente novamente.'));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dia = _dia;
    Widget corpo;
    if (dia == null && _erro != null) {
      corpo = ErrorState(error: _erro!, onRetry: () => _carregar(widget.dataInicial));
    } else if (dia == null) {
      corpo = const LoadingState();
    } else {
      corpo = Stack(
        children: [
          RefreshIndicator(
            color: Colors.black,
            backgroundColor: AppColors.accent,
            onRefresh: () => _carregar(dia.data),
            child: PageList(children: [
              _barraData(dia),
              _resumo(dia),
              _formulario(dia),
              _historico(dia),
            ]),
          ),
          if (_carregando)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2, color: AppColors.accent, backgroundColor: Colors.transparent),
            ),
        ],
      );
    }

    return PopScope(
      canPop: !_alterado,
      onPopInvokedWithResult: (saiu, _) async {
        if (saiu) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sair sem salvar?'),
            content: const Text('Os valores digitados neste dia ainda não foram salvos.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar editando')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                child: const Text('Sair'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          // Libera a saída (canPop) e só então volta, no próximo quadro.
          setState(() => _alterado = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
              child: Column(
                children: [
                  const PageHeader(
                    title: 'Produção',
                    subtitle: 'Quilos produzidos e desperdiçados por refeição',
                    showBell: false,
                  ),
                  Expanded(child: corpo),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Partes da tela ──────────────────────────────────────────────────────

  Widget _barraData(ProducaoDia dia) {
    final pal = context.pal;
    final ehHoje = dia.data == dia.hoje;
    final d = parseIso(dia.data);
    return Row(
      children: [
        IconButton.outlined(
          key: const Key('dia-anterior'),
          tooltip: 'Dia anterior',
          onPressed: _carregando ? null : () => _somarDias(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('escolher-data'),
            onPressed: _carregando ? null : _escolherData,
            style: OutlinedButton.styleFrom(
              foregroundColor: pal.text,
              minimumSize: const Size.fromHeight(46),
              side: BorderSide(color: pal.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.accentText),
            label: Text(
              ehHoje ? 'Hoje, ${fmtData(d!)}' : '${diaCurto(dia.data)}/${d!.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          key: const Key('dia-seguinte'),
          tooltip: 'Dia seguinte',
          onPressed: ehHoje || _carregando ? null : () => _somarDias(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (!ehHoje) ...[
          const SizedBox(width: 4),
          TextButton(key: const Key('ir-hoje'), onPressed: () => _irPara(dia.hoje), child: const Text('Hoje')),
        ],
      ],
    );
  }

  Widget _resumo(ProducaoDia dia) {
    final acima = dia.percentual != null && dia.percentual! > dia.metaDesperdicio;
    return CardGrid(children: [
      StatCard(CardResumo(
        chave: 'produzido',
        label: 'Produzido no dia',
        valorTexto: dia.totalProduzido > 0 ? _kg(dia.totalProduzido) : '—',
        extra: dia.totalPrevisto > 0 ? 'Previsto: ${_kg(dia.totalPrevisto)}' : 'Sem previsão para o dia',
      )),
      StatCard(CardResumo(
        chave: 'desperdicado',
        label: 'Desperdiçado',
        valorTexto: dia.totalDesperdicado > 0 ? _kg(dia.totalDesperdicado) : '—',
        extra: dia.temBalanca ? 'Pela balança ou digitado aqui' : 'Digitado aqui',
      )),
      StatCard(CardResumo(
        chave: acima ? 'percentual_alto' : 'percentual',
        label: 'Desperdício',
        valorTexto: _pct(dia.percentual),
        extra: dia.percentual == null
            ? 'Meta: até ${fmtNum(dia.metaDesperdicio)}%'
            : '${acima ? 'Acima' : 'Dentro'} da meta (${fmtNum(dia.metaDesperdicio)}%)',
      )),
      StatCard(CardResumo(
        chave: 'pessoas',
        label: 'Previsão para o dia',
        valorTexto: dia.pessoasPrevistas > 0 ? '${fmtNum(dia.pessoasPrevistas)} pessoas' : '—',
        extra: dia.feriado != null
            ? 'Feriado: ${dia.feriado}'
            : (dia.kgSugerido != null ? 'Produzir cerca de ${_kg(dia.kgSugerido)}' : 'Sem histórico suficiente'),
      )),
    ]);
  }

  Widget _formulario(ProducaoDia dia) {
    final pal = context.pal;
    double totalP = 0, totalD = 0;
    for (final r in dia.refeicoes) {
      final p = lerKg(_produzido[r.tipo]!.text);
      final d = lerKg(_desperdicado[r.tipo]!.text);
      if (p != null && !p.isNaN) totalP += p;
      if (d != null && !d.isNaN) totalD += d;
    }
    final totalPct = totalP > 0 ? totalD / totalP * 100 : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(dia.data == dia.hoje ? 'Registrar produção de hoje' : 'Produção de ${diaCurto(dia.data)}'),
          if (dia.temBalanca) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('O desperdício chega sozinho pela balança. Se precisar, corrija aqui.',
                        style: TextStyle(color: AppColors.info, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ],
          for (final r in dia.refeicoes) _linha(dia, r),
          Divider(color: pal.border, height: 24),
          Row(
            children: [
              Expanded(child: Text('Total', style: AppText.strong(context, size: 15))),
              Text('${_kg(totalP > 0 ? totalP : null)} · ', style: AppText.strong(context)),
              Text(_kg(totalD > 0 ? totalD : null), style: AppText.strong(context)),
              const SizedBox(width: 10),
              _Percentual(totalPct, dia.metaDesperdicio, key: const Key('total-percentual')),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('status-producao'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_status!.ok ? AppColors.success : AppColors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_status!.texto,
                  style: TextStyle(color: _status!.ok ? AppColors.success : AppColors.red, fontSize: 13.5)),
            ),
          ],
          const SizedBox(height: 14),
          Text('Deixe em branco a refeição que não foi servida. Os números atualizam o painel, a análise mensal e a '
              'previsão de demanda.', style: AppText.muted(context, size: 12.5)),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('salvar-producao'),
            onPressed: _salvando ? null : _salvar,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            icon: _salvando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.check_rounded),
            label: const Text('Salvar produção'),
          ),
        ],
      ),
    );
  }

  Widget _linha(ProducaoDia dia, ProducaoRefeicao r) {
    final p = lerKg(_produzido[r.tipo]!.text);
    final d = lerKg(_desperdicado[r.tipo]!.text);
    final pct = (p != null && !p.isNaN && p > 0 && (d == null || !d.isNaN)) ? (d ?? 0) / p * 100 : null;

    Widget campo(String rotulo, TextEditingController c, String chave) => TextField(
          key: Key(chave),
          controller: c,
          enabled: !_salvando,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() => _alterado = true),
          decoration: InputDecoration(
            labelText: rotulo,
            // Rótulo sempre no alto (menor): no celular "Desperdiçado" não cabe dentro do campo vazio.
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: '0,0',
            suffixText: 'kg',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.rotulo, style: AppText.strong(context, size: 15))),
              Text('Previsto: ${_kg(r.previsto)}', style: AppText.muted(context, size: 12.5)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: campo('Produzido', _produzido[r.tipo]!, 'prod-${r.tipo}')),
              const SizedBox(width: 10),
              Expanded(child: campo('Desperdiçado', _desperdicado[r.tipo]!, 'desp-${r.tipo}')),
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                height: 44,
                child: Center(child: _Percentual(pct, dia.metaDesperdicio, key: Key('pct-${r.tipo}'))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historico(ProducaoDia dia) {
    final pal = context.pal;
    final maximo = dia.historico.fold<double>(1, (m, h) => h.produzido > m ? h.produzido : m);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('Últimos 14 dias'),
          const SizedBox(height: 4),
          Text('Toque em um dia para ver ou corrigir.', style: AppText.muted(context, size: 12.5)),
          const SizedBox(height: 8),
          if (dia.historico.isEmpty)
            const EmptyNote('Nenhuma produção registrada nos últimos dias. Comece pelo formulário acima.')
          else
            for (final h in dia.historico)
              Material(
                color: h.data == dia.data ? AppColors.accent.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  key: Key('historico-${h.data}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _irPara(h.data),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 84, child: Text(diaCurto(h.data), style: AppText.strong(context, size: 13))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: h.produzido / maximo,
                              minHeight: 8,
                              color: AppColors.accent,
                              backgroundColor: pal.border,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(_kg(h.produzido), textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: pal.text)),
                        ),
                        SizedBox(
                          width: 54,
                          child: Align(alignment: Alignment.centerRight, child: _Percentual(h.percentual, dia.metaDesperdicio)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// % de desperdício colorido: verde dentro da meta, vermelho acima.
class _Percentual extends StatelessWidget {
  final double? valor;
  final double meta;
  const _Percentual(this.valor, this.meta, {super.key});

  @override
  Widget build(BuildContext context) {
    if (valor == null) return Text('—', style: AppText.muted(context));
    final acima = valor! > meta;
    return Text(_pct(valor),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: acima ? AppColors.red : AppColors.success));
  }
}
