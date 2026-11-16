import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/arquivos.dart';
import '../core/config_service.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/formularios.dart';
import '../widgets/qr_code.dart';

/// Verificação em duas etapas (Configurações → Segurança): as mesmas regras e mensagens do site (o servidor usa o
/// mesmo código, DoisFatores). Desativada → escolher o método → configurar (QR Code/chave do aplicativo autenticador
/// ou código por e-mail, sempre com a senha atual) → ativada, com os 10 códigos de recuperação mostrados uma única vez.
class DuasEtapasCard extends StatefulWidget {
  const DuasEtapasCard({super.key});

  @override
  State<DuasEtapasCard> createState() => _DuasEtapasCardState();
}

class _DuasEtapasCardState extends State<DuasEtapasCard> {
  late Future<EstadoDuasEtapas> _carga = _carregar();
  EstadoDuasEtapas? _estado;

  /// Configurando: 'app' ou 'email' (null = mostrando o estado).
  String? _configurando;
  ChaveAutenticador? _chave;
  String? _mensagemEmail;

  final _codigo = TextEditingController();
  final _senha = TextEditingController();
  bool _enviando = false;
  String? _erro;
  String? _sucesso;

  /// Códigos de recuperação recém-gerados: aparecem só agora (o servidor não mostra de novo).
  List<String>? _codigosNovos;

  ConfigService get _servico => ConfigService(AppScope.read(context).api);

  Future<EstadoDuasEtapas> _carregar() async {
    final e = await comAvisoDeServidorAntigo(() => ConfigService(AppScope.read(context).api).duasEtapas());
    _estado = e;
    return e;
  }

  @override
  void dispose() {
    _codigo.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _limparFormulario() {
    _codigo.clear();
    _senha.clear();
    _erro = null;
  }

  /// Roda uma ação do servidor mostrando "enviando" e o erro dela no card.
  Future<void> _executar(Future<void> Function() acao) async {
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = null;
    });
    try {
      await acao();
    } catch (e) {
      // Corpo em bloco: com "=>" o callback devolveria o Future, e o Flutter (em debug e nos testes) recusa.
      if (mounted) {
        setState(() {
          _erro = mensagemDoErro(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
        });
      }
    }
  }

  Future<void> _iniciar(String metodo) => _executar(() async {
        if (metodo == 'app') {
          final chave = await _servico.iniciarAutenticador();
          if (!mounted) return;
          setState(() {
            _limparFormulario();
            _configurando = 'app';
            _chave = chave;
          });
        } else {
          final mensagem = await _servico.iniciarEmail();
          if (!mounted) return;
          setState(() {
            final reenvio = _configurando == 'email';
            _limparFormulario();
            _configurando = 'email';
            _mensagemEmail = mensagem;
            if (reenvio) _sucesso = 'Código novo enviado. O anterior não vale mais.';
          });
        }
      });

  Future<void> _ativar() async {
    FocusScope.of(context).unfocus();
    final codigo = _codigo.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(codigo)) {
      setState(() => _erro = 'Digite o código de 6 dígitos.');
      return;
    }
    if (_senha.text.isEmpty) {
      setState(() => _erro = 'Confirme com a sua senha atual.');
      return;
    }
    await _executar(() async {
      final r = await _servico.ativarDuasEtapas(metodo: _configurando!, codigo: codigo, senhaAtual: _senha.text);
      if (!mounted) return;
      setState(() {
        _limparFormulario();
        _configurando = null;
        _chave = null;
        _estado = r.estado;
        _carga = Future.value(r.estado);
        _codigosNovos = r.codigos;
        _sucesso = r.mensagem;
      });
    });
  }

  void _cancelar() => setState(() {
        _limparFormulario();
        _configurando = null;
        _chave = null;
        _sucesso = null;
      });

  Future<void> _dispensar() => _executar(() async {
        final e = await _servico.dispensarConvite();
        if (!mounted) return;
        setState(() {
          _estado = e;
          _carga = Future.value(e);
        });
      });

  /// Gerar novos códigos e desativar pedem a senha atual (como no site).
  Future<void> _comSenha(String acao) async {
    final desativar = acao == 'desativar';
    final senha = await _pedirSenha(
      titulo: desativar ? 'Desativar a verificação?' : 'Gerar novos códigos?',
      texto: desativar
          ? 'O login volta a pedir só e-mail e senha. Para confirmar, digite a sua senha atual.'
          : 'Os códigos de recuperação atuais deixam de valer. Para confirmar, digite a sua senha atual.',
      acao: desativar ? 'Desativar' : 'Gerar códigos',
    );
    if (senha == null || !mounted) return;
    await _executar(() async {
      if (desativar) {
        final r = await _servico.desativarDuasEtapas(senha);
        if (!mounted) return;
        setState(() {
          _estado = r.estado;
          _carga = Future.value(r.estado);
          _codigosNovos = null;
          _sucesso = r.mensagem;
        });
      } else {
        final r = await _servico.novosCodigos(senha);
        if (!mounted) return;
        setState(() {
          _estado = r.estado;
          _carga = Future.value(r.estado);
          _codigosNovos = r.codigos;
          _sucesso = r.mensagem;
        });
      }
    });
  }

  Future<String?> _pedirSenha({required String titulo, required String texto, required String acao}) {
    final campo = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(texto, style: AppText.muted(ctx, size: 13.5)),
            const SizedBox(height: 14),
            TextField(
              key: const Key('2fa-senha-dialogo'),
              controller: campo,
              autofocus: true,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (v) => Navigator.pop(ctx, v),
              decoration: decoracaoCampo(ctx, 'Senha atual', icone: Icons.lock_outline_rounded),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('2fa-senha-confirmar'),
            onPressed: () => Navigator.pop(ctx, campo.text),
            style: FilledButton.styleFrom(
              backgroundColor: acao == 'Desativar' ? AppColors.red : AppColors.accent,
              foregroundColor: acao == 'Desativar' ? Colors.white : Colors.black,
            ),
            child: Text(acao),
          ),
        ],
      ),
    ).whenComplete(() => WidgetsBinding.instance.addPostFrameCallback((_) => campo.dispose()));
  }

  // ─── Códigos de recuperação ─────────────────────────────────────────────

  String _textoCodigos() => [
        'SICAPDA — códigos de recuperação da verificação em duas etapas',
        'Conta: ${AppScope.read(context).user?.email ?? ''}',
        '',
        'Cada código vale uma vez. Use no lugar do código de 6 dígitos se perder o celular ou o acesso ao e-mail.',
        '',
        for (var i = 0; i < _codigosNovos!.length; i++) '${(i + 1).toString().padLeft(2)}. ${_codigosNovos![i]}',
        '',
      ].join('\n');

  Future<void> _copiarCodigos() async {
    await Clipboard.setData(ClipboardData(text: _textoCodigos()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Códigos copiados.')));
  }

  Future<void> _salvarCodigos() async {
    try {
      await entregarArquivo(context,
          nome: 'sicapda-codigos-de-recuperacao.txt',
          bytes: Uint8List.fromList(utf8.encode(_textoCodigos())),
          mimeType: 'text/plain',
          assunto: 'Códigos de recuperação do SICAPDA');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível salvar o arquivo. Use "Copiar".')));
      }
    }
  }

  // ─── Tela ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => AppCard(
        child: FutureBuilder<EstadoDuasEtapas>(
          future: _carga,
          builder: (context, snap) {
            final estado = snap.connectionState == ConnectionState.done ? (snap.hasError ? null : snap.data) : _estado;
            final filhos = <Widget>[_cabecalho(estado)];

            if (estado == null && snap.connectionState != ConnectionState.done) {
              filhos.add(const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ));
            } else if (snap.hasError) {
              filhos.add(EmptyNote(mensagemDoErro(snap.error!)));
            } else if (!estado!.disponivel) {
              filhos.add(const EmptyNote('A verificação em duas etapas ainda não está disponível neste servidor.'));
            } else {
              if (_configurando == 'app' && _chave != null) {
                filhos.addAll(_configurarApp(_chave!));
              } else if (_configurando == 'email') {
                filhos.addAll(_configurarEmail());
              } else if (estado.ativa) {
                filhos.addAll(_ativa(estado));
              } else {
                filhos.addAll(_inativa(estado));
              }
              if (_erro != null && _configurando == null) {
                filhos.add(const SizedBox(height: 12));
                filhos.add(AvisoFormulario(_erro!));
              }
              if (_sucesso != null && _configurando == null) {
                filhos.add(const SizedBox(height: 12));
                filhos.add(AvisoFormulario(_sucesso!, sucesso: true));
              }
              if (_codigosNovos != null && _codigosNovos!.isNotEmpty) filhos.add(_codigosRecuperacao());
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos);
          },
        ),
      );

  Widget _cabecalho(EstadoDuasEtapas? estado) {
    final ativa = estado?.ativa ?? false;
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: ativa ? pal.successBg : pal.chip, borderRadius: BorderRadius.circular(12)),
            child: Icon(ativa ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: ativa ? AppColors.success : pal.textMuted, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Verificação em duas etapas', style: AppText.strong(context, size: 15)),
                    if (estado != null && estado.disponivel)
                      Pill(ativa ? 'Ativada' : 'Desativada',
                          key: const Key('2fa-status'),
                          background: ativa ? pal.successBg : pal.chip,
                          foreground: ativa ? AppColors.success : pal.textMuted),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    'Além da senha, o login no site e no aplicativo pede um código de 6 dígitos. Mesmo que alguém descubra a sua senha, sem o código não entra.',
                    style: AppText.muted(context, size: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _inativa(EstadoDuasEtapas e) {
    final pal = context.pal;
    return [
      if (e.pendente != null)
        Container(
          key: const Key('2fa-convite'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.accentSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Falta só um passo', style: AppText.strong(context, size: 14)),
                    const SizedBox(height: 2),
                    Text(
                        'No cadastro você pediu a verificação em duas etapas ${e.pendente == 'email' ? 'por e-mail' : 'pelo aplicativo autenticador'}. Conclua abaixo: leva 1 minuto.',
                        style: AppText.muted(context, size: 12.5)),
                  ],
                ),
              ),
              TextButton(
                key: const Key('2fa-agora-nao'),
                onPressed: _enviando ? null : _dispensar,
                child: const Text('Agora não'),
              ),
            ],
          ),
        ),
      _metodo(
        chave: 'btn-2fa-app',
        icone: Icons.phonelink_lock_rounded,
        titulo: 'Aplicativo autenticador',
        recomendado: true,
        texto: 'Google Authenticator, Microsoft Authenticator, Authy ou outro. O código aparece no celular, mesmo sem internet.',
        onPressed: () => _iniciar('app'),
      ),
      const SizedBox(height: 10),
      _metodo(
        chave: 'btn-2fa-email',
        icone: Icons.mark_email_read_outlined,
        titulo: 'Código por e-mail',
        texto: e.emailDisponivel
            ? 'A cada login enviamos um código para ${e.email}.'
            : 'O envio de e-mails não está configurado neste servidor.',
        onPressed: e.emailDisponivel ? () => _iniciar('email') : null,
      ),
    ];
  }

  Widget _metodo({
    required String chave,
    required IconData icone,
    required String titulo,
    required String texto,
    required VoidCallback? onPressed,
    bool recomendado = false,
  }) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: pal.textMuted, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(titulo, style: AppText.strong(context, size: 14)),
                        if (recomendado) Pill('Recomendado', background: pal.successBg, foreground: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(texto, style: AppText.muted(context, size: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: BotaoEnviar(
              key: Key(chave),
              rotulo: 'Configurar',
              icone: recomendado ? Icons.qr_code_2_rounded : Icons.send_rounded,
              enviando: _enviando,
              secundario: !recomendado,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _configurarApp(ChaveAutenticador chave) {
    final pal = context.pal;
    Widget passo(String n, String texto) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Text(n, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(texto, style: TextStyle(color: pal.text, fontSize: 13.5, height: 1.4))),
            ],
          ),
        );

    return [
      passo('1', 'Abra o aplicativo autenticador (se não tiver, instale o Google Authenticator ou o Microsoft Authenticator) e toque em "+" ou "Adicionar conta".'),
      passo('2', 'No computador, escaneie o QR Code com o celular. Neste celular, copie a chave e cole no aplicativo em "Inserir uma chave de configuração".'),
      const SizedBox(height: 4),
      Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: QrCodeView(chave.qr, key: const Key('2fa-qr'), tamanho: 196, rotulo: 'QR Code para o aplicativo autenticador'),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                chave.chave,
                key: const Key('2fa-chave'),
                style: TextStyle(fontFamily: 'monospace', fontSize: 14.5, letterSpacing: 1, color: pal.text),
              ),
            ),
            TextButton.icon(
              key: const Key('2fa-copiar-chave'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: chave.chave.replaceAll(' ', '')));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave copiada.')));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text('A chave só tem letras de A a Z e números de 2 a 7 (não existe zero nem um: o "O" é letra).',
          style: AppText.muted(context, size: 11.5)),
      const SizedBox(height: 14),
      passo('3', 'Digite o código de 6 dígitos que aparecer no aplicativo e confirme com a sua senha.'),
      ..._formularioAtivacao(),
    ];
  }

  List<Widget> _configurarEmail() => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_mensagemEmail ?? '',
                  key: const Key('2fa-enviado'), style: TextStyle(color: context.pal.text, fontSize: 13.5, height: 1.4)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._formularioAtivacao(reenviar: true),
      ];

  List<Widget> _formularioAtivacao({bool reenviar = false}) => [
        TextField(
          key: const Key('2fa-codigo'),
          controller: _codigo,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 6),
          decoration: decoracaoCampo(context, 'Código de 6 dígitos', icone: Icons.pin_outlined).copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('2fa-senha'),
          controller: _senha,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _ativar(),
          decoration: decoracaoCampo(context, 'Senha atual', icone: Icons.lock_outline_rounded),
        ),
        if (_erro != null) ...[const SizedBox(height: 12), AvisoFormulario(_erro!)],
        if (_sucesso != null) ...[const SizedBox(height: 12), AvisoFormulario(_sucesso!, sucesso: true)],
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            if (reenviar)
              TextButton(
                key: const Key('2fa-reenviar'),
                onPressed: _enviando ? null : () => _iniciar('email'),
                child: const Text('Reenviar código'),
              ),
            BotaoEnviar(rotulo: 'Cancelar', icone: Icons.close_rounded, enviando: false, secundario: true, onPressed: _enviando ? null : _cancelar),
            BotaoEnviar(
              key: const Key('2fa-ativar'),
              rotulo: 'Ativar',
              icone: Icons.verified_user_outlined,
              enviando: _enviando,
              onPressed: _ativar,
            ),
          ],
        ),
      ];

  List<Widget> _ativa(EstadoDuasEtapas e) {
    final pal = context.pal;
    Widget linha(String rotulo, String valor, Key key) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: Text(rotulo, style: AppText.muted(context, size: 12.5))),
              Text(valor, key: key, style: AppText.strong(context, size: 13.5)),
            ],
          ),
        );

    return [
      linha('Método', e.metodoRotulo ?? '', const Key('2fa-metodo')),
      linha('Ativada em', e.ativadaEm ?? '', const Key('2fa-ativada-em')),
      linha('Códigos de recuperação', e.codigosRestantes == 1 ? '1 restante' : '${e.codigosRestantes} restantes',
          const Key('2fa-restantes')),
      if (e.codigosRestantes <= 3)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: pal.warningBg, borderRadius: BorderRadius.circular(12)),
          child: Text('Restam poucos códigos de recuperação. Gere novos para não ficar sem saída se perder o celular.',
              style: TextStyle(color: AppColors.warning, fontSize: 12.5, height: 1.35)),
        ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          BotaoEnviar(
            key: const Key('2fa-novos-codigos'),
            rotulo: 'Gerar novos códigos',
            icone: Icons.refresh_rounded,
            enviando: _enviando,
            secundario: true,
            onPressed: () => _comSenha('codigos'),
          ),
          TextButton(
            key: const Key('2fa-desativar'),
            onPressed: _enviando ? null : () => _comSenha('desativar'),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Desativar'),
          ),
        ],
      ),
    ];
  }

  Widget _codigosRecuperacao() {
    final pal = context.pal;
    return Container(
      key: const Key('2fa-codigos'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.key_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Guarde os seus códigos de recuperação', style: AppText.strong(context, size: 14))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              'Se perder o celular (ou o acesso ao e-mail), entre com um destes códigos no lugar do código de 6 dígitos. Cada um vale uma vez e eles não serão mostrados de novo: copie ou salve agora.',
              style: AppText.muted(context, size: 12.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: pal.border)),
            child: Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _codigosNovos!.length; i++)
                  SizedBox(
                    width: 150,
                    child: Text('${(i + 1).toString().padLeft(2)}. ${_codigosNovos![i]}',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: pal.text)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              TextButton.icon(
                  key: const Key('2fa-copiar-codigos'),
                  onPressed: _copiarCodigos,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar')),
              TextButton.icon(
                  key: const Key('2fa-salvar-codigos'),
                  onPressed: _salvarCodigos,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Salvar')),
              BotaoEnviar(
                key: const Key('2fa-guardei'),
                rotulo: 'Já guardei',
                icone: Icons.check_rounded,
                enviando: false,
                onPressed: () => setState(() {
                  _codigosNovos = null;
                  _sucesso = null;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
