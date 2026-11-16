import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/sicapda_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _servidor = TextEditingController();
  final _codigo = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _showServer = false;
  String? _error;
  String? _errorDetail;

  /// Verificação em duas etapas: a senha estava certa e o servidor espera o código (null = formulário de login).
  DesafioDuasEtapas? _desafio;

  /// Digitando um código de recuperação (ABCDE-FGHIJ) no lugar do código de 6 dígitos.
  bool _recuperacao = false;

  /// Aviso informativo na segunda etapa (ex.: "Enviamos um código novo").
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _servidor.text = AppScope.read(context).baseUrl;
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _servidor.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _errorDetail = null;
    });
    try {
      final desafio = await AppScope.read(context).login(_email.text, _senha.text, serverUrl: _servidor.text);
      // Sem verificação em duas etapas o MaterialApp já troca para o app autenticado (ouve o AppController).
      if (desafio != null && mounted) {
        setState(() {
          _desafio = desafio;
          _recuperacao = false;
          _aviso = null;
          _codigo.clear();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _errorDetail = e.detail;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível entrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Segunda etapa: confere o código. 410 (venceu, já usado ou errou 5 vezes) e 429 (bloqueio) voltam ao login.
  Future<void> _verificar() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _errorDetail = null;
      _aviso = null;
    });
    try {
      await AppScope.read(context).verificarCodigo(_desafio!, _codigo.text);
      // Código certo: o MaterialApp troca para o app autenticado.
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if (e.status == 410 || e.status == 429) _voltarAoLogin();
          _error = e.message;
          _errorDetail = e.detail;
          _codigo.clear();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível conferir o código. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "Reenviar código" (método por e-mail). O servidor limita a um pedido por minuto e responde quanto falta.
  Future<void> _reenviar() async {
    setState(() {
      _error = null;
      _aviso = null;
    });
    try {
      final mensagem = await AppScope.read(context).reenviarCodigo(_desafio!);
      if (mounted) setState(() => _aviso = mensagem);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if (e.status == 410) _voltarAoLogin();
          _error = e.message;
        });
      }
    }
  }

  /// Sai da segunda etapa: o e-mail continua preenchido e a senha precisa ser digitada de novo.
  void _voltarAoLogin() {
    _desafio = null;
    _recuperacao = false;
    _aviso = null;
    _codigo.clear();
    _senha.clear();
  }

  /// Pede o e-mail (já preenchido com o do login) e o servidor envia o link para criar uma senha nova.
  Future<void> _esqueciSenha() async {
    FocusScope.of(context).unfocus();
    final controller = AppScope.read(context);
    await showDialog<void>(
      context: context,
      builder: (_) => _EsqueciSenhaDialog(
        emailInicial: _email.text.trim(),
        enviar: (email) => controller.esqueciSenha(email, serverUrl: _servidor.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          _background(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 440, minHeight: size.height * 0.85),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: SicapdaLogo(width: 300)),
                        const SizedBox(height: 34),
                        if (_desafio != null) ..._segundaEtapa(_desafio!) else ..._formularioLogin(),
                        const SizedBox(height: 36),
                        _footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// E-mail, senha, "Esqueci minha senha", Entrar e o endereço do servidor.
  List<Widget> _formularioLogin() => [
        const Text('Bem-vindo de volta!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Faça login para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.loginMuted, fontSize: 15)),
        const SizedBox(height: 30),
        if (_error != null) _errorBanner(_error!, _errorDetail),
        _field(
          label: 'E-mail',
          controller: _email,
          hint: 'Digite seu e-mail',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Informe seu e-mail';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
              return 'Informe um e-mail válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        _field(
          label: 'Senha',
          controller: _senha,
          hint: 'Digite sua senha',
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          autofill: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.loginHint,
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          validator: (v) => (v == null || v.isEmpty) ? 'Informe sua senha' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('esqueci-senha'),
            onPressed: _loading ? null : _esqueciSenha,
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Esqueci minha senha', style: TextStyle(fontSize: 13.5)),
          ),
        ),
        const SizedBox(height: 10),
        _loginButton(),
        const SizedBox(height: 14),
        _serverSection(),
      ];

  /// Verificação em duas etapas: o código do aplicativo autenticador, do e-mail ou um de recuperação.
  List<Widget> _segundaEtapa(DesafioDuasEtapas d) {
    const muted = TextStyle(color: AppColors.loginMuted, fontSize: 14.5, height: 1.45);
    final instrucao = _recuperacao
        ? 'Digite um dos 10 códigos de recuperação que você guardou ao ativar a verificação (ABCDE-FGHIJ). Cada um vale uma vez.'
        : d.porEmail
            ? 'Enviamos um código de 6 dígitos para ${d.destino}. Ele vale por 10 minutos (confira também o spam).'
            : 'Abra o aplicativo autenticador do celular (Google Authenticator, Microsoft Authenticator...) e digite o código de 6 dígitos do SICAPDA.';

    return [
      Center(
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent.withValues(alpha: 0.16)),
          child: Icon(
            _recuperacao ? Icons.key_rounded : (d.porEmail ? Icons.mark_email_read_outlined : Icons.phonelink_lock_rounded),
            color: AppColors.accent,
            size: 28,
          ),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Verificação em duas etapas',
          key: Key('titulo-2fa'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(instrucao, key: const Key('instrucao-2fa'), textAlign: TextAlign.center, style: muted),
      const SizedBox(height: 24),
      if (_error != null) _errorBanner(_error!, _errorDetail),
      if (_aviso != null) _avisoBanner(_aviso!),
      _campoCodigo(),
      const SizedBox(height: 18),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          key: const Key('btn-verificar'),
          onPressed: _loading ? null : _verificar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
            elevation: 6,
            shadowColor: AppColors.accent.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
              : const Text('Verificar e entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          if (d.porEmail && !_recuperacao)
            TextButton(
              key: const Key('btn-reenviar'),
              onPressed: _loading ? null : _reenviar,
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: const Text('Reenviar código'),
            ),
          TextButton(
            key: const Key('btn-recuperacao'),
            onPressed: _loading
                ? null
                : () => setState(() {
                      _recuperacao = !_recuperacao;
                      _codigo.clear();
                      _error = null;
                    }),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(_recuperacao ? 'Usar o código de 6 dígitos' : 'Usar um código de recuperação'),
          ),
        ],
      ),
      Center(
        child: TextButton.icon(
          key: const Key('btn-voltar-login'),
          onPressed: _loading ? null : () => setState(_voltarAoLogin),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Voltar ao login'),
          style: TextButton.styleFrom(foregroundColor: AppColors.loginMuted),
        ),
      ),
    ];
  }

  Widget _campoCodigo() {
    OutlineInputBorder borda(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

    return TextFormField(
      key: const Key('codigo-2fa'),
      controller: _codigo,
      enabled: !_loading,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: _recuperacao ? TextInputType.visiblePassword : TextInputType.number,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: _recuperacao ? null : const [AutofillHints.oneTimeCode],
      maxLength: _recuperacao ? 11 : 6,
      inputFormatters: [
        if (_recuperacao)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\- ]'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (v) {
        // Com os 6 dígitos (digitados, colados ou preenchidos pelo teclado), confere sozinho.
        if (!_recuperacao && v.length == 6) _verificar();
      },
      onFieldSubmitted: (_) => _verificar(),
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: Colors.white,
        fontSize: _recuperacao ? 22 : 30,
        fontWeight: FontWeight.w700,
        letterSpacing: _recuperacao ? 3 : 10,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      validator: (v) {
        final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
        if (_recuperacao) return t.length == 10 ? null : 'Digite o código de recuperação (10 letras e números)';
        return RegExp(r'^\d{6}$').hasMatch(t) ? null : 'Digite o código de 6 dígitos';
      },
      decoration: InputDecoration(
        counterText: '',
        hintText: _recuperacao ? 'ABCDE-FGHIJ' : '000000',
        hintStyle: TextStyle(color: AppColors.loginHint.withValues(alpha: 0.6), letterSpacing: _recuperacao ? 3 : 10),
        filled: true,
        fillColor: AppColors.loginField,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: borda(AppColors.loginBorder),
        enabledBorder: borda(AppColors.loginBorder),
        disabledBorder: borda(AppColors.loginBorder),
        focusedBorder: borda(AppColors.accent, 1.4),
        errorBorder: borda(Colors.redAccent),
        focusedErrorBorder: borda(Colors.redAccent, 1.4),
      ),
    );
  }

  Widget _avisoBanner(String msg) => Container(
        key: const Key('aviso-2fa'),
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13.5))),
          ],
        ),
      );

  Widget _background() => Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 1.4,
              colors: [Color(0xFF1A1A1A), AppColors.black],
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -80, right: -80, child: _glow(220)),
              Positioned(bottom: -100, left: -100, child: _glow(260)),
            ],
          ),
        ),
      );

  Widget _glow(double d) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [AppColors.accent.withValues(alpha: 0.30), Colors.transparent]),
        ),
      );

  Widget _errorBanner(String msg, [String? detail]) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A8A), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg, style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 13.5)),
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Text('Detalhe técnico: $detail',
                        key: const Key('erro-detalhe'),
                        style: TextStyle(color: const Color(0xFFFFB4B4).withValues(alpha: 0.7), fontSize: 11.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    Iterable<String>? autofill,
    ValueChanged<String>? onSubmitted,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.loginMuted, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          autofillHints: autofill,
          enabled: !_loading,
          onFieldSubmitted: onSubmitted,
          textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.loginHint, fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.loginField,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: border(AppColors.loginBorder),
            enabledBorder: border(AppColors.loginBorder),
            disabledBorder: border(AppColors.loginBorder),
            focusedBorder: border(AppColors.accent, 1.4),
            errorBorder: border(Colors.redAccent),
            focusedErrorBorder: border(Colors.redAccent, 1.4),
          ),
        ),
      ],
    );
  }

  Widget _loginButton() => SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
            elevation: 6,
            shadowColor: AppColors.accent.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                )
              : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _serverSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => setState(() => _showServer = !_showServer),
              icon: const Icon(Icons.dns_outlined, size: 16, color: AppColors.loginMuted),
              label: Text(_showServer ? 'Ocultar servidor' : 'Servidor',
                  style: const TextStyle(color: AppColors.loginMuted, fontSize: 13)),
            ),
          ),
          if (_showServer) ...[
            _field(
              label: 'Endereço do servidor (SystemFluxe)',
              controller: _servidor,
              hint: 'https://fluxeteam.com.br',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o endereço do servidor' : null,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _servidor,
              builder: (_, v, _) => v.text.trim().toLowerCase().startsWith('http://')
                  ? const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.accent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Endereço sem HTTPS: os dados trafegam sem criptografia. Use só em rede local de teste.',
                              key: Key('aviso-http'),
                              style: TextStyle(color: AppColors.loginMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      );

  Widget _footer() => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.accent, size: 24),
          SizedBox(width: 4),
          Text.rich(TextSpan(
            text: 'Feito pela ',
            style: TextStyle(color: AppColors.loginMuted, fontSize: 17),
            children: [
              TextSpan(text: 'Fluxe', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ],
          )),
        ],
      );
}

/// Janela do "Esqueci minha senha": e-mail → o servidor envia o link de redefinição (o mesmo do site).
class _EsqueciSenhaDialog extends StatefulWidget {
  final String emailInicial;
  final Future<String> Function(String email) enviar;

  const _EsqueciSenhaDialog({required this.emailInicial, required this.enviar});

  @override
  State<_EsqueciSenhaDialog> createState() => _EsqueciSenhaDialogState();
}

class _EsqueciSenhaDialogState extends State<_EsqueciSenhaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInicial);
  bool _enviando = false;
  String? _erro;
  String? _enviado;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final mensagem = await widget.enviar(_email.text.trim());
      if (mounted) setState(() => _enviado = mensagem);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível enviar agora. Tente novamente.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const texto = TextStyle(color: AppColors.loginMuted, fontSize: 14, height: 1.4);

    return AlertDialog(
      backgroundColor: AppColors.blackSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Esqueci minha senha', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 380,
        child: _enviado != null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: AppColors.accent, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('$_enviado\n\nAbra o link do e-mail para criar a senha nova e depois entre aqui com ela.',
                        key: const Key('esqueci-enviado'), style: texto),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Informe o e-mail da sua conta. Enviaremos um link para você criar uma senha nova.', style: texto),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('esqueci-email'),
                      controller: _email,
                      enabled: !_enviando,
                      autofocus: widget.emailInicial.isEmpty,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _enviar(),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Informe seu e-mail';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Informe um e-mail válido';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'seuemail@empresa.com',
                        hintStyle: const TextStyle(color: AppColors.loginHint, fontSize: 14),
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: AppColors.accent, size: 20),
                        filled: true,
                        fillColor: AppColors.loginField,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.loginBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.loginBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
                        ),
                      ),
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 12),
                      Text(_erro!, key: const Key('esqueci-erro'), style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 13)),
                    ],
                  ],
                ),
              ),
      ),
      actions: _enviado != null
          ? [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                child: const Text('Entendi'),
              ),
            ]
          : [
              TextButton(
                onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: AppColors.loginMuted),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('esqueci-enviar'),
                onPressed: _enviando ? null : _enviar,
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
                child: _enviando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                    : const Text('Enviar link'),
              ),
            ],
    );
  }
}
