import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/theme.dart';

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

  bool _obscure = true;
  bool _loading = false;
  bool _showServer = false;
  String? _error;

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
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.read(context).login(_email.text, _senha.text, serverUrl: _servidor.text);
      // O MaterialApp troca para o app autenticado ao ouvir o AppController.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Não foi possível entrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                        _logo(),
                        const SizedBox(height: 18),
                        _title(),
                        const SizedBox(height: 26),
                        const Text('Bem-vindo de volta!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Faça login para continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.loginMuted, fontSize: 15)),
                        const SizedBox(height: 30),
                        if (_error != null) _errorBanner(_error!),
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
                        const SizedBox(height: 26),
                        _loginButton(),
                        const SizedBox(height: 14),
                        _serverSection(),
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

  Widget _logo() => Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Image.asset('images/logo_sicapda.png', fit: BoxFit.contain),
        ),
      );

  Widget _title() => const Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: AppText.heading, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          children: [
            TextSpan(text: 'SICA', style: TextStyle(color: Colors.white)),
            TextSpan(text: 'PDA', style: TextStyle(color: AppColors.accent)),
          ],
        ),
        textAlign: TextAlign.center,
      );

  Widget _errorBanner(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A8A), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 13.5))),
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
          if (_showServer)
            _field(
              label: 'Endereço do servidor (SystemFluxe)',
              controller: _servidor,
              hint: 'https://fluxeteam.com.br',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o endereço do servidor' : null,
            ),
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
