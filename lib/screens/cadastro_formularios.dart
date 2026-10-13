import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/cadastro_service.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Formulários do Cadastro de pessoas: adicionar/editar pessoa e vincular cartão.
///
/// Cada folha manda o pedido sozinha e, se der certo, chama [onSalvo] com a mensagem do servidor e se fecha. Quem abriu
/// recarrega a lista dentro de [onSalvo]: assim o resultado não se perde nem se a folha for fechada no meio do envio.
/// Erros do servidor (cartão já em uso, campo inválido...) aparecem dentro da própria folha, que continua aberta.

/// Adicionar (pessoa == null) ou editar uma pessoa. Ao adicionar, dá para já vincular um cartão.
Future<void> abrirFormularioPessoa(
  BuildContext context, {
  required CadastroService servico,
  required List<CategoriaOpcao> categorias,
  required void Function(String mensagem) onSalvo,
  PessoaCadastro? pessoa,
  Duration intervaloLeituras = const Duration(seconds: 3),
}) =>
    mostrarFolha<void>(
      context,
      (_) => _FormularioPessoa(
        servico: servico,
        categorias: categorias,
        pessoa: pessoa,
        onSalvo: onSalvo,
        intervaloLeituras: intervaloLeituras,
      ),
    );

/// Vincular um cartão a uma pessoa que já existe.
Future<void> abrirVincularCartao(
  BuildContext context, {
  required CadastroService servico,
  required PessoaCadastro pessoa,
  required void Function(String mensagem) onSalvo,
  Duration intervaloLeituras = const Duration(seconds: 3),
}) =>
    mostrarFolha<void>(
      context,
      (_) => _VincularCartao(servico: servico, pessoa: pessoa, onSalvo: onSalvo, intervaloLeituras: intervaloLeituras),
    );

// ─── Peças comuns ──────────────────────────────────────────────────────────

/// Deixa o UID como o servidor guarda: maiúsculas, sem espaços nem ":" (o cursor continua no mesmo lugar).
class UidFormatter extends TextInputFormatter {
  const UidFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final texto = normalizarUid(novo.text);
    final cursor = novo.selection.isValid ? novo.selection.end.clamp(0, novo.text.length) : novo.text.length;
    final novoCursor = math.min(normalizarUid(novo.text.substring(0, cursor)).length, texto.length);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: novoCursor));
  }
}

InputDecoration _decoracao(BuildContext context, String rotulo, {String? dica, IconData? icone}) {
  final pal = context.pal;
  OutlineInputBorder borda(Color cor, [double largura = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cor, width: largura));

  return InputDecoration(
    labelText: rotulo,
    hintText: dica,
    hintStyle: TextStyle(color: pal.textMuted, fontSize: 14),
    labelStyle: TextStyle(color: pal.textMuted),
    floatingLabelStyle: TextStyle(color: pal.text, fontWeight: FontWeight.w600),
    prefixIcon: icone == null ? null : Icon(icone, color: pal.textMuted),
    filled: true,
    fillColor: pal.card,
    border: borda(pal.border),
    enabledBorder: borda(pal.border),
    focusedBorder: borda(AppColors.accent, 1.6),
    errorBorder: borda(AppColors.red),
    focusedErrorBorder: borda(AppColors.red, 1.6),
  );
}

/// Casca das folhas: título, campos, erro do servidor e os botões Cancelar / enviar.
class _Folha extends StatelessWidget {
  final String titulo;
  final Widget? subtitulo;
  final List<Widget> campos;
  final String? erro;
  final bool enviando;
  final String rotuloEnviar;
  final Key chaveEnviar;
  final VoidCallback onEnviar;

  const _Folha({
    required this.titulo,
    required this.campos,
    required this.erro,
    required this.enviando,
    required this.rotuloEnviar,
    required this.chaveEnviar,
    required this.onEnviar,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    // Só os campos rolam: o erro do servidor e os botões ficam fixos embaixo (sempre à vista, acima do teclado).
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titulo, style: AppText.title(context, size: 18)),
                  if (subtitulo != null) ...[const SizedBox(height: 4), subtitulo!],
                  const SizedBox(height: 16),
                  for (final c in campos) ...[c, const SizedBox(height: 14)],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (erro != null) ...[
                  Container(
                    key: const Key('erro-formulario'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 20, color: escuro ? const Color(0xFFFF8A8A) : AppColors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(erro!,
                              style: TextStyle(
                                  fontSize: 13.5, height: 1.35, color: escuro ? const Color(0xFFFFB4B4) : const Color(0xFFB91C1C))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: enviando ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: context.pal.text,
                          side: BorderSide(color: context.pal.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: chaveEnviar,
                        onPressed: enviando ? null : onEnviar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: enviando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(rotuloEnviar, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo do UID + lista de cartões lidos nas catracas (tocar num deles preenche o campo).
class _BlocoCartao extends StatelessWidget {
  final CadastroService servico;
  final TextEditingController controller;
  final String titulo;
  final String rotuloCampo;
  final bool obrigatorio;
  final bool enviando;
  final Duration intervalo;
  final VoidCallback onEnviar;

  const _BlocoCartao({
    required this.servico,
    required this.controller,
    required this.titulo,
    required this.rotuloCampo,
    required this.obrigatorio,
    required this.enviando,
    required this.intervalo,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => LeiturasRecentes(
            servico: servico,
            titulo: titulo,
            intervalo: intervalo,
            uidEscolhido: normalizarUid(controller.text),
            onEscolher: (uid) => controller.value = TextEditingValue(text: uid, selection: TextSelection.collapsed(offset: uid.length)),
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('campo-uid'),
          controller: controller,
          enabled: !enviando,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: const [UidFormatter()],
          onFieldSubmitted: (_) => onEnviar(),
          decoration: _decoracao(context, rotuloCampo, dica: 'Escolha acima ou digite, ex.: A1B2C3D4', icone: Icons.credit_card_rounded),
          validator: (v) {
            final uid = normalizarUid(v ?? '');
            if (uid.isEmpty) return obrigatorio ? 'Escolha um cartão acima ou digite o UID.' : null;
            return uidValido(uid) ? null : mensagemUidInvalido;
          },
        ),
      ],
    );
  }
}

// ─── Cartões lidos nas catracas ────────────────────────────────────────────

/// "Cartões lidos nas catracas e ainda sem dono": consulta o servidor de tempos em tempos enquanto está na tela.
/// Passou o cartão na catraca → aparece aqui, destacado como "novo" → tocar usa o UID dele.
/// Fica parada enquanto o app está em segundo plano (minimizado ou em outro app) e volta a consultar ao reabrir.
class LeiturasRecentes extends StatefulWidget {
  final CadastroService servico;
  final String titulo;
  final String uidEscolhido;
  final ValueChanged<String> onEscolher;
  final Duration intervalo;

  const LeiturasRecentes({
    super.key,
    required this.servico,
    required this.titulo,
    required this.uidEscolhido,
    required this.onEscolher,
    this.intervalo = const Duration(seconds: 3),
  });

  @override
  State<LeiturasRecentes> createState() => _LeiturasRecentesState();
}

class _LeiturasRecentesState extends State<LeiturasRecentes> with WidgetsBindingObserver {
  Timer? _timer;
  bool _buscando = false;
  bool _emSegundoPlano = false;
  bool _carregou = false;

  /// O que já existia quando a folha abriu; o que chegar ou for lido de novo depois disso é "novo".
  Map<String, int>? _base;
  List<LeituraCartao> _leituras = const [];
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buscar();
    _timer = Timer.periodic(widget.intervalo, (_) => _buscar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "inactive" não conta: no PC é só a janela sem foco (o administrador pode estar olhando a catraca), e no
    // celular é uma passagem rápida (ligação, troca de app). Parar de consultar só quando o app sai de cena de vez.
    _emSegundoPlano = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (!_emSegundoPlano) _buscar();
  }

  Future<void> _buscar() async {
    if (_buscando || _emSegundoPlano) return;
    _buscando = true;
    try {
      final leituras = await widget.servico.leituras();
      if (!mounted) return;
      setState(() {
        _base ??= {for (final l in leituras) l.uid: l.leituras};
        _leituras = leituras;
        _carregou = true;
        _status = 'atualiza sozinha';
      });
    } on ApiException catch (e) {
      // Sem status = nem chegou ao servidor (sem internet); com status = o servidor respondeu com erro.
      if (mounted) setState(() => _status = e.status == null ? 'sem conexão' : 'indisponível');
    } catch (_) {
      if (mounted) setState(() => _status = 'sem conexão');
    } finally {
      _buscando = false;
    }
  }

  bool _novo(LeituraCartao l) => _base != null && (_base![l.uid] ?? 0) < l.leituras;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(14), border: Border.all(color: pal.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(widget.titulo, style: AppText.strong(context, size: 13)),
              if (_status.isNotEmpty) Text('· $_status', key: const Key('leituras-status'), style: AppText.muted(context, size: 12)),
            ],
          ),
          const SizedBox(height: 10),
          if (!_carregou && _status.isEmpty)
            Text('Buscando…', style: AppText.muted(context, size: 13))
          else if (_leituras.isEmpty)
            Text(
              _carregou ? 'Nenhum cartão novo lido ainda. Passe o cartão na catraca.' : 'Não foi possível buscar os cartões lidos agora. Digite o UID abaixo.',
              key: const Key('leituras-vazio'),
              style: AppText.muted(context, size: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in _leituras)
                  _ChipLeitura(
                    leitura: l,
                    novo: _novo(l),
                    escolhido: widget.uidEscolhido == l.uid,
                    onTap: () => widget.onEscolher(l.uid),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChipLeitura extends StatelessWidget {
  final LeituraCartao leitura;
  final bool novo;
  final bool escolhido;
  final VoidCallback onTap;
  const _ChipLeitura({required this.leitura, required this.novo, required this.escolhido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final detalhe = '${leitura.dispositivo} · ${leitura.quando}${leitura.leituras > 1 ? ' · ${leitura.leituras}×' : ''}';
    return Semantics(
      button: true,
      selected: escolhido,
      label: 'Cartão ${leitura.uid}, lido em $detalhe${novo ? ', novo' : ''}',
      excludeSemantics: true,
      child: Material(
        color: escolhido ? pal.accentSoft : pal.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: escolhido || novo ? AppColors.accent : pal.border, width: escolhido || novo ? 1.6 : 1),
        ),
        child: InkWell(
          key: Key('leitura-${leitura.uid}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(leitura.uid, style: TextStyle(color: pal.text, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.6)),
                    if (novo) ...[
                      const SizedBox(width: 8),
                      const Pill('novo', background: AppColors.accent, foreground: Colors.black),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(detalhe, style: AppText.muted(context, size: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Adicionar / editar pessoa ─────────────────────────────────────────────

class _FormularioPessoa extends StatefulWidget {
  final CadastroService servico;
  final List<CategoriaOpcao> categorias;
  final PessoaCadastro? pessoa;
  final void Function(String mensagem) onSalvo;
  final Duration intervaloLeituras;

  const _FormularioPessoa({
    required this.servico,
    required this.categorias,
    required this.pessoa,
    required this.onSalvo,
    required this.intervaloLeituras,
  });

  @override
  State<_FormularioPessoa> createState() => _FormularioPessoaState();
}

class _FormularioPessoaState extends State<_FormularioPessoa> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.pessoa?.nome);
  late final _cargo = TextEditingController(text: widget.pessoa?.cargo);
  late final _matricula = TextEditingController(text: widget.pessoa?.matricula);
  final _uid = TextEditingController();
  late String _categoria = widget.pessoa?.categoria ?? widget.categorias.first.valor;
  bool _enviando = false;
  String? _erro;

  bool get _editando => widget.pessoa != null;

  @override
  void dispose() {
    _nome.dispose();
    _cargo.dispose();
    _matricula.dispose();
    _uid.dispose();
    super.dispose();
  }

  static String _limpo(String t) => t.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _enviar() async {
    if (_enviando || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final nome = _limpo(_nome.text);
      final cargo = _limpo(_cargo.text);
      final matricula = _limpo(_matricula.text);
      final mensagem = _editando
          ? await widget.servico.editarPessoa(widget.pessoa!.id, nome: nome, cargo: cargo, categoria: _categoria, matricula: matricula)
          : await widget.servico.criarPessoa(
              nome: nome,
              cargo: cargo,
              categoria: _categoria,
              matricula: matricula,
              uid: normalizarUid(_uid.text),
            );
      widget.onSalvo(mensagem);
      // Deu certo: o botão fica desabilitado até a folha sumir (sem enviar em duplicidade com um toque a mais).
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _falhou(e.message);
    } catch (_) {
      _falhou('Não foi possível salvar. Tente novamente.');
    }
  }

  void _falhou(String mensagem) {
    if (mounted) {
      setState(() {
        _erro = mensagem;
        _enviando = false;
      });
    }
  }

  String? _obrigatorio(String? v, String mensagem, int max) {
    final t = _limpo(v ?? '');
    if (t.isEmpty) return mensagem;
    return t.length > max ? 'No máximo $max caracteres.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Form(
      key: _form,
      child: _Folha(
        titulo: _editando ? 'Editar pessoa' : 'Adicionar pessoa',
        erro: _erro,
        enviando: _enviando,
        rotuloEnviar: 'Salvar',
        chaveEnviar: const Key('btn-salvar-pessoa'),
        onEnviar: _enviar,
        campos: [
          TextFormField(
            key: const Key('campo-nome'),
            controller: _nome,
            enabled: !_enviando,
            autofocus: !_editando,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(150)],
            decoration: _decoracao(context, 'Nome', icone: Icons.person_outline_rounded),
            validator: (v) => _obrigatorio(v, 'Informe o nome.', 150),
          ),
          TextFormField(
            key: const Key('campo-cargo'),
            controller: _cargo,
            enabled: !_enviando,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(100)],
            decoration: _decoracao(context, 'Cargo ou função', icone: Icons.badge_outlined),
            validator: (v) => _obrigatorio(v, 'Informe o cargo ou a função.', 100),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Categoria', style: AppText.muted(context, size: 12.5)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final c in widget.categorias)
                    ChoiceChip(
                      key: Key('categoria-${c.valor}'),
                      label: Text(c.rotulo),
                      selected: _categoria == c.valor,
                      onSelected: _enviando ? null : (_) => setState(() => _categoria = c.valor),
                      showCheckmark: false,
                      selectedColor: AppColors.accent,
                      backgroundColor: pal.card,
                      side: BorderSide(color: _categoria == c.valor ? AppColors.accent : pal.border),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _categoria == c.valor ? Colors.black : pal.text,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                ],
              ),
            ],
          ),
          TextFormField(
            key: const Key('campo-matricula'),
            controller: _matricula,
            enabled: !_enviando,
            textInputAction: _editando ? TextInputAction.done : TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(30)],
            onFieldSubmitted: _editando ? (_) => _enviar() : null,
            decoration: _decoracao(context, 'Matrícula (opcional)', icone: Icons.numbers_rounded),
          ),
          // Os cartões de quem já existe se mexem na própria linha da lista (vincular, ativar, remover).
          if (!_editando)
            _BlocoCartao(
              servico: widget.servico,
              controller: _uid,
              titulo: 'Cartões lidos nas catracas e ainda sem dono',
              rotuloCampo: 'UID do cartão (opcional)',
              obrigatorio: false,
              enviando: _enviando,
              intervalo: widget.intervaloLeituras,
              onEnviar: _enviar,
            ),
        ],
      ),
    );
  }
}

// ─── Vincular cartão ───────────────────────────────────────────────────────

class _VincularCartao extends StatefulWidget {
  final CadastroService servico;
  final PessoaCadastro pessoa;
  final void Function(String mensagem) onSalvo;
  final Duration intervaloLeituras;

  const _VincularCartao({
    required this.servico,
    required this.pessoa,
    required this.onSalvo,
    required this.intervaloLeituras,
  });

  @override
  State<_VincularCartao> createState() => _VincularCartaoState();
}

class _VincularCartaoState extends State<_VincularCartao> {
  final _form = GlobalKey<FormState>();
  final _uid = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final mensagem = await widget.servico.vincularCartao(widget.pessoa.id, normalizarUid(_uid.text));
      widget.onSalvo(mensagem);
      // Deu certo: o botão fica desabilitado até a folha sumir (sem enviar em duplicidade com um toque a mais).
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _falhou(e.message);
    } catch (_) {
      _falhou('Não foi possível vincular o cartão. Tente novamente.');
    }
  }

  void _falhou(String mensagem) {
    if (mounted) {
      setState(() {
        _erro = mensagem;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: _Folha(
        titulo: 'Vincular cartão',
        subtitulo: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Para '),
            TextSpan(text: widget.pessoa.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          style: AppText.muted(context, size: 14),
        ),
        erro: _erro,
        enviando: _enviando,
        rotuloEnviar: 'Vincular',
        chaveEnviar: const Key('btn-confirmar-vinculo'),
        onEnviar: _enviar,
        campos: [
          _BlocoCartao(
            servico: widget.servico,
            controller: _uid,
            titulo: 'Passe o cartão numa catraca e ele aparece aqui',
            rotuloCampo: 'UID do cartão',
            obrigatorio: true,
            enviando: _enviando,
            intervalo: widget.intervaloLeituras,
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}
