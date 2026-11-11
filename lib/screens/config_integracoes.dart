import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/cadastro_service.dart';
import '../core/config_service.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/formularios.dart';
import 'cadastro_formularios.dart' show UidFormatter;

/// Aba Integrações de Configurações: os dispositivos IoT da empresa (catracas, leitores RFID e balanças de
/// desperdício), como no site. Todos veem a lista e o desperdício de hoje; só o administrador cadastra
/// dispositivos, gera tokens e testa leituras e pesagens (o servidor confere o perfil em toda ação).
/// A lista se atualiza sozinha (tempo real): um dispositivo que liga ou cai muda de Offline para Online e vice-versa.
class IntegracoesTab extends StatefulWidget {
  const IntegracoesTab({super.key});

  @override
  State<IntegracoesTab> createState() => _IntegracoesTabState();
}

class _IntegracoesTabState extends State<IntegracoesTab> {
  late final AppController _app = AppScope.read(context);
  late Future<DispositivosData> _future = _carregar();

  ConfigService get _servico => ConfigService(_app.api);

  @override
  void initState() {
    super.initState();
    _app.aoVivo.mudancas.addListener(_recarregar);
  }

  @override
  void dispose() {
    _app.aoVivo.mudancas.removeListener(_recarregar);
    super.dispose();
  }

  Future<DispositivosData> _carregar() => comAvisoDeServidorAntigo(() => _servico.dispositivos());

  void _recarregar() {
    if (!mounted) return;
    setState(() {
      _future = _carregar();
    });
  }

  Future<void> _puxar() async {
    final f = _carregar();
    setState(() {
      _future = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  // ─── Ações ─────────────────────────────────────────────────────────────

  Future<void> _adicionar(DispositivosData d) async {
    final criado = await mostrarFolha<({String token, DispositivoIot dispositivo})>(
      context,
      (_) => _FormularioDispositivo(servico: _servico, tipos: d.tipos),
    );
    if (criado == null || !mounted) return;
    _recarregar();
    await mostrarToken(context, titulo: '${criado.dispositivo.nome} criado', token: criado.token);
  }

  Future<void> _novoToken(DispositivoIot disp) async {
    final ok = await confirmar(
      context,
      titulo: 'Gerar outro token para ${disp.nome}?',
      texto: 'O aparelho que usa o token atual deixa de ser aceito até você colar o novo token no firmware dele.',
      acao: 'Gerar token',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await _servico.novoToken(disp.id);
      _recarregar();
      if (mounted) await mostrarToken(context, titulo: 'Novo token de ${disp.nome}', token: r.token);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemDoErro(e))));
    }
  }

  // ─── Tela ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AsyncBody<DispositivosData>(
      future: _future,
      onRefresh: _puxar,
      onRetry: _recarregar,
      builder: (context, d) => PageList(children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardTitle('Dispositivos IoT'),
              const SizedBox(height: 4),
              Text('Catracas, leitores RFID e balanças vinculados à empresa. Cada dispositivo usa seu próprio token para '
                  'enviar acessos ou pesagens.', style: AppText.muted(context)),
              const SizedBox(height: 8),
              if (d.dispositivos.isEmpty)
                const EmptyNote('Nenhum dispositivo cadastrado ainda.')
              else
                for (final disp in d.dispositivos)
                  _ItemDispositivo(
                    key: ValueKey('dispositivo-${disp.id}'),
                    disp,
                    onNovoToken: d.podeEditar ? () => _novoToken(disp) : null,
                  ),
              const SizedBox(height: 12),
              if (d.podeEditar)
                BotaoEnviar(
                  key: const Key('btn-adicionar-dispositivo'),
                  rotulo: 'Adicionar dispositivo',
                  icone: Icons.add_rounded,
                  enviando: false,
                  onPressed: () => _adicionar(d),
                )
              else
                const NotaConfig('Somente o administrador da empresa pode adicionar dispositivos e gerar tokens.',
                    icone: Icons.lock_outline_rounded),
            ],
          ),
        ),
        _DesperdicioHoje(d),
        if (d.podeEditar && d.catracas.isNotEmpty) _SimularLeitura(servico: _servico, catracas: d.catracas),
        if (d.podeEditar && d.balancas.isNotEmpty)
          _TestarPesagem(servico: _servico, balancas: d.balancas, refeicoes: d.refeicoes, onSalvo: _recarregar),
        const NotaConfig('Passo a passo do firmware (ESP32), do circuito e do Wokwi: pasta iot/ do SystemFluxe.',
            icone: Icons.memory_rounded),
      ]),
    );
  }
}

/// Mostra o token inteiro uma única vez, com botão de copiar (o servidor nunca mais o mostra).
Future<void> mostrarToken(BuildContext context, {required String titulo, required String token}) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copie agora e cole no firmware da ESP32 (TOKEN_DISPOSITIVO). Por segurança ele não será mostrado de novo.',
                style: AppText.muted(ctx, size: 13.5)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ctx.pal.chip, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                token,
                key: const Key('token-revelado'),
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: ctx.pal.text, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Token copiado.')));
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
            child: const Text('Já copiei'),
          ),
        ],
      ),
    );

class _ItemDispositivo extends StatelessWidget {
  final DispositivoIot disp;
  final VoidCallback? onNovoToken;
  const _ItemDispositivo(this.disp, {super.key, required this.onNovoToken});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final cor = disp.online ? AppColors.success : pal.textMuted;
    final icone = switch (disp.tipo) {
      'balanca' => Icons.scale_rounded,
      'biometria' => Icons.fingerprint_rounded,
      _ => Icons.contactless_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(14), border: Border.all(color: pal.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icone, color: pal.text, size: 21),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(color: cor, shape: BoxShape.circle, border: Border.all(color: pal.chip, width: 2)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(disp.nome, style: AppText.strong(context, size: 14.5)),
                    Text([disp.tipoRotulo, ?disp.localizacao].join(' · '), style: AppText.muted(context, size: 12.5)),
                    const SizedBox(height: 4),
                    Text(disp.tokenMascarado, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: pal.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Pill(
                    disp.online ? 'Online' : 'Offline',
                    background: disp.online ? pal.successBg : pal.card,
                    foreground: disp.online ? AppColors.success : pal.textMuted,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 110,
                    child: Text(disp.ultimoSinal, textAlign: TextAlign.end, style: AppText.muted(context, size: 11.5)),
                  ),
                ],
              ),
            ],
          ),
          if (onNovoToken != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('btn-novo-token-${disp.id}'),
                onPressed: onNovoToken,
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: const Text('Novo token'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesperdicioHoje extends StatelessWidget {
  final DispositivosData d;
  const _DesperdicioHoje(this.d);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Desperdício de hoje'),
          const SizedBox(height: 4),
          Text('Totais em kg por refeição${d.data.isEmpty ? '' : ', em ${isoParaBr(d.data)}'}. Os valores enviados pelas '
              'balanças alimentam a análise de desperdício.', style: AppText.muted(context)),
          const SizedBox(height: 10),
          for (final r in d.desperdicioHoje)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.restaurant_rounded, size: 18, color: pal.textMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.rotulo, style: AppText.strong(context, size: 14))),
                  Text(
                    r.kg == null ? 'Sem registro' : '${fmtNum(r.kg!, decimals: 2)} kg',
                    key: Key('desperdicio-${r.tipo}'),
                    style: r.kg == null ? AppText.muted(context, size: 13.5) : AppText.strong(context, size: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Formulários ───────────────────────────────────────────────────────────

/// Adicionar dispositivo: devolve (pelo Navigator) o token inteiro e o dispositivo criado.
class _FormularioDispositivo extends StatefulWidget {
  final ConfigService servico;
  final List<OpcaoValor> tipos;
  const _FormularioDispositivo({required this.servico, required this.tipos});

  @override
  State<_FormularioDispositivo> createState() => _FormularioDispositivoState();
}

class _FormularioDispositivoState extends State<_FormularioDispositivo> {
  final _nome = TextEditingController();
  final _local = TextEditingController();
  late String _tipo = widget.tipos.isEmpty ? 'rfid' : widget.tipos.first.valor;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _local.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _erro = 'Informe o nome do dispositivo (até 150 caracteres).');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final r = await widget.servico.criarDispositivo(nome: nome, tipo: _tipo, localizacao: _local.text.trim());
      if (mounted) Navigator.pop(context, (token: r.token, dispositivo: r.dispositivo));
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = mensagemDoErro(e);
          _enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipos = widget.tipos.isEmpty
        ? const [
            OpcaoValor('rfid', 'Cartão RFID'),
            OpcaoValor('biometria', 'Biometria'),
            OpcaoValor('hibrido', 'RFID + biometria'),
            OpcaoValor('balanca', 'Balança de desperdício'),
          ]
        : widget.tipos;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Adicionar dispositivo', style: AppText.title(context, size: 18)),
            const SizedBox(height: 4),
            Text('Depois de criar, o token aparece uma única vez para você colar no firmware.', style: AppText.muted(context)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('dispositivo-nome'),
              controller: _nome,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: decoracaoCampo(context, 'Nome', dica: 'Ex.: Catraca · Entrada Principal', icone: Icons.label_outline_rounded)
                  .copyWith(counterText: ''),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('dispositivo-tipo'),
              initialValue: _tipo,
              decoration: decoracaoCampo(context, 'Tipo', icone: Icons.category_outlined),
              items: [for (final t in tipos) DropdownMenuItem(value: t.valor, child: Text(t.rotulo))],
              onChanged: (v) => setState(() => _tipo = v ?? _tipo),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('dispositivo-local'),
              controller: _local,
              maxLength: 150,
              decoration: decoracaoCampo(context, 'Localização (opcional)', dica: 'Ex.: Portaria principal', icone: Icons.place_outlined)
                  .copyWith(counterText: ''),
            ),
            if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotaoEnviar(
                    key: const Key('btn-criar-dispositivo'),
                    rotulo: 'Criar',
                    icone: Icons.add_rounded,
                    enviando: _enviando,
                    onPressed: _criar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Simular leitura": passa um cartão por uma catraca sem precisar do aparelho (registra um acesso de verdade).
class _SimularLeitura extends StatefulWidget {
  final ConfigService servico;
  final List<DispositivoIot> catracas;
  const _SimularLeitura({required this.servico, required this.catracas});

  @override
  State<_SimularLeitura> createState() => _SimularLeituraState();
}

class _SimularLeituraState extends State<_SimularLeitura> {
  final _uid = TextEditingController();
  int? _catraca;
  bool _enviando = false;
  String? _erro;
  ResultadoLeitura? _resultado;

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  int get _catracaId =>
      widget.catracas.any((c) => c.id == _catraca) ? _catraca! : widget.catracas.first.id;

  Future<void> _simular() async {
    FocusScope.of(context).unfocus();
    final uid = normalizarUid(_uid.text);
    if (uid.isEmpty) {
      setState(() => _erro = 'Informe o UID do cartão.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
      _resultado = null;
    });
    try {
      final r = await widget.servico.simularLeitura(_catracaId, uid);
      if (mounted) setState(() => _resultado = r);
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('Simular leitura'),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(style: AppText.muted(context), children: [
              const TextSpan(text: 'Passa um cartão por uma catraca sem precisar do aparelho, pela mesma regra de um acesso de verdade. '),
              TextSpan(text: 'Registra um acesso real', style: AppText.strong(context, size: 13)),
              const TextSpan(text: ': ele aparece no painel e nos relatórios.'),
            ]),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('simular-catraca'),
            initialValue: _catracaId,
            decoration: decoracaoCampo(context, 'Catraca', icone: Icons.contactless_rounded),
            items: [for (final c in widget.catracas) DropdownMenuItem(value: c.id, child: Text(c.nome, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _catraca = v),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('simular-uid'),
            controller: _uid,
            maxLength: 100,
            inputFormatters: const [UidFormatter()],
            decoration: decoracaoCampo(context, 'UID do cartão', dica: 'Ex.: 01020304', icone: Icons.credit_card_rounded)
                .copyWith(counterText: ''),
            onSubmitted: (_) => _simular(),
          ),
          if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
          if (r != null) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('resultado-simulacao'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: r.autorizado ? context.pal.successBg : AppColors.red.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(r.autorizado ? Icons.check_circle_rounded : Icons.block_rounded,
                      color: r.autorizado ? AppColors.success : AppColors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.mensagem, style: AppText.strong(context, size: 14)),
                        Text(
                          [
                            'Cartão ${r.uid}',
                            if (r.nome != null && r.nome!.isNotEmpty) r.nome!,
                            if (r.autorizado && r.direcao != null) r.direcao == 'saida' ? 'saída' : 'entrada',
                          ].join(' · '),
                          style: AppText.muted(context, size: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: BotaoEnviar(
              key: const Key('btn-simular'),
              rotulo: 'Simular passagem',
              icone: Icons.credit_card_rounded,
              enviando: _enviando,
              secundario: true,
              onPressed: _simular,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Testar pesagem": registra o total de desperdício de uma refeição hoje, como o botão "Encerrar turno" da balança.
class _TestarPesagem extends StatefulWidget {
  final ConfigService servico;
  final List<DispositivoIot> balancas;
  final List<OpcaoValor> refeicoes;
  final VoidCallback onSalvo;
  const _TestarPesagem({required this.servico, required this.balancas, required this.refeicoes, required this.onSalvo});

  @override
  State<_TestarPesagem> createState() => _TestarPesagemState();
}

class _TestarPesagemState extends State<_TestarPesagem> {
  final _kg = TextEditingController();
  int? _balanca;
  String? _refeicao;
  bool _enviando = false;
  String? _erro;
  String? _sucesso;

  List<OpcaoValor> get _refeicoes => widget.refeicoes.isEmpty
      ? const [OpcaoValor('cafe', 'Café da manhã'), OpcaoValor('almoco', 'Almoço'), OpcaoValor('jantar', 'Jantar'), OpcaoValor('ceia', 'Ceia')]
      : widget.refeicoes;

  int get _balancaId => widget.balancas.any((b) => b.id == _balanca) ? _balanca! : widget.balancas.first.id;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    // "2,50" (vírgula decimal, com ou sem ponto de milhar: "1.250,5") ou "2.5"
    final texto = _kg.text.trim();
    final kg = double.tryParse(texto.contains(',') ? texto.replaceAll('.', '').replaceAll(',', '.') : texto);
    if (kg == null || kg < 0 || kg > 100000) {
      setState(() {
        _erro = 'Informe um peso entre 0 e 100.000 kg.';
        _sucesso = null;
      });
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      final mensagem = await widget.servico.registrarPesagem(
        balancaId: _balancaId,
        refeicao: _refeicao ?? _refeicoes.first.valor,
        kg: kg,
      );
      if (!mounted) return;
      _kg.clear();
      setState(() => _sucesso = mensagem);
      widget.onSalvo();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('Testar pesagem'),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(style: AppText.muted(context), children: [
              const TextSpan(text: 'Registra o total de desperdício de hoje, como o botão Encerrar turno da balança. '),
              TextSpan(text: 'Substitui o total da refeição para toda a empresa', style: AppText.strong(context, size: 13)),
              const TextSpan(text: ', inclusive se houver mais de uma balança.'),
            ]),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const Key('pesagem-balanca'),
            initialValue: _balancaId,
            decoration: decoracaoCampo(context, 'Balança', icone: Icons.scale_rounded),
            items: [for (final b in widget.balancas) DropdownMenuItem(value: b.id, child: Text(b.nome, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _balanca = v),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('pesagem-refeicao'),
            initialValue: _refeicao ?? _refeicoes.first.valor,
            decoration: decoracaoCampo(context, 'Refeição', icone: Icons.restaurant_rounded),
            items: [for (final r in _refeicoes) DropdownMenuItem(value: r.valor, child: Text(r.rotulo))],
            onChanged: (v) => setState(() => _refeicao = v),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('pesagem-kg'),
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: decoracaoCampo(context, 'Total de desperdício (kg)', dica: 'Ex.: 2,50', icone: Icons.monitor_weight_outlined),
            onSubmitted: (_) => _registrar(),
          ),
          if (_erro != null) ...[const SizedBox(height: 14), AvisoFormulario(_erro!)],
          if (_sucesso != null) ...[const SizedBox(height: 14), AvisoFormulario(_sucesso!, sucesso: true)],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: BotaoEnviar(
              key: const Key('btn-registrar-pesagem'),
              rotulo: 'Registrar total',
              icone: Icons.check_rounded,
              enviando: _enviando,
              secundario: true,
              onPressed: _registrar,
            ),
          ),
        ],
      ),
    );
  }
}
