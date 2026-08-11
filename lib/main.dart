import 'package:flutter/material.dart';

// =======================================================
// Paleta de cores da SICAPDA / Fluxe
// =======================================================
class AppColors {
  static const Color background = Color(0xFF0D0D0D);
  static const Color backgroundSecondary = Color(0xFF161616);
  static const Color accent = Color(0xFFFFC107);
  static const Color accentSoft = Color(0x33FFC107);
  static const Color fieldBackground = Color(0xFF1A1A1A);
  static const Color fieldBorder = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color hintText = Color(0xFF6E6E6E);
}

void main() {
  runApp(const SicapdaApp());
}

class SicapdaApp extends StatelessWidget {
  const SicapdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SICAPDA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Poppins', // troque pela fonte do seu projeto, se houver
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: substituir pela chamada real à sua API PHP MVC de autenticação
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fundo com gradiente escuro + brilhos tecnológicos nos cantos
          _buildBackgroundDecoration(size),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height * 0.92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),
                      _buildLogo(),
                      const SizedBox(height: 20),
                      _buildAppTitle(),
                      const SizedBox(height: 28),
                      _buildWelcomeText(),
                      const SizedBox(height: 36),
                      _buildEmailField(),
                      const SizedBox(height: 18),
                      _buildPasswordField(),
                      const SizedBox(height: 10),
                      _buildForgotPassword(),
                      const SizedBox(height: 28),
                      _buildLoginButton(),
                      const SizedBox(height: 24),
                      // _buildDivider(),
                      const SizedBox(height: 24),
                      // _buildCreateAccountButton(),
                      const SizedBox(height: 60),
                      _buildFooter(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // Fundo: gradiente escuro + brilhos amarelos nos cantos
  // -----------------------------------------------------
  Widget _buildBackgroundDecoration(Size size) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.4,
            colors: [
              Color(0xFF1A1A1A),
              AppColors.background,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Brilho amarelo sutil - canto superior direito
            Positioned(
              top: -80,
              right: -80,
              child: _glowCircle(220, AppColors.accent.withOpacity(0.30)),
            ),
            // Brilho amarelo sutil - canto inferior esquerdo
            Positioned(
              bottom: -100,
              left: -100,
              child: _glowCircle(260, AppColors.accent.withOpacity(0.30)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double diameter, Color color) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // Logo
  // -----------------------------------------------------
  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        padding: const EdgeInsets.all(0),
        child: Image.asset(
          'images/logo_sicapda.png',
          fit: BoxFit.contain,
          width: 100,
          height: 100,
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // Título "SICAPDA"
  // -----------------------------------------------------
  Widget _buildAppTitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          fontSize: 35,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
        children: [
          TextSpan(text: 'SICA', style: TextStyle(color: AppColors.textPrimary)),
          TextSpan(text: 'PDA', style: TextStyle(color: AppColors.accent)),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // Textos de boas-vindas
  // -----------------------------------------------------
  Widget _buildWelcomeText() {
    return const Column(
      children: [
        Text(
          'Bem-vindo de volta!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Faça login para continuar',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------
  // Campo de e-mail
  // -----------------------------------------------------
  Widget _buildEmailField() {
    return _buildInputField(
      label: 'Email',
      controller: _emailController,
      hint: 'Digite seu email',
      icon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      obscureText: false,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe seu e-mail';
        }
        final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Informe um e-mail válido';
        }
        return null;
      },
    );
  }

  // -----------------------------------------------------
  // Campo de senha
  // -----------------------------------------------------
  Widget _buildPasswordField() {
    return _buildInputField(
      label: 'Senha',
      controller: _passwordController,
      hint: 'Digite sua senha',
      icon: Icons.lock_outline_rounded,
      keyboardType: TextInputType.visiblePassword,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: AppColors.hintText,
          size: 20,
        ),
        onPressed: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe sua senha';
        }
        if (value.length < 6) {
          return 'A senha deve ter ao menos 6 caracteres';
        }
        return null;
      },
    );
  }

  // -----------------------------------------------------
  // Campo genérico de input (reutilizado por email e senha)
  // -----------------------------------------------------
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required bool obscureText,
    required String? Function(String?) validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.accent, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.fieldBackground,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------
  // "Esqueceu sua senha?"
  // -----------------------------------------------------
  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () {
          // TODO: navegar para tela de recuperação de senha
        },
        child: const Text(
          'Esqueceu sua senha?',
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // Botão "Entrar"
  // -----------------------------------------------------
  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.black,
          elevation: 6,
          shadowColor: AppColors.accent.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.black,
                ),
              )
            : const Text(
                'Entrar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // -----------------------------------------------------
  // Divisor "ou"
  // -----------------------------------------------------
  // Widget _buildDivider() {
  //   return Row(
  //     children: [
  //       Expanded(child: Divider(color: AppColors.fieldBorder, thickness: 1)),
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 12),
  //         child: Text(
  //           'ou',
  //           style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 13),
  //         ),
  //       ),
  //       Expanded(child: Divider(color: AppColors.fieldBorder, thickness: 1)),
  //     ],
  //   );
  // }

  // -----------------------------------------------------
  // Botão "Criar conta"
  // -----------------------------------------------------
  // Widget _buildCreateAccountButton() {
  //   return SizedBox(
  //     height: 54,
  //     child: OutlinedButton(
  //       onPressed: () {
  //         // TODO: navegar para tela de cadastro
  //       },
  //       style: OutlinedButton.styleFrom(
  //         foregroundColor: AppColors.accent,
  //         side: const BorderSide(color: AppColors.accent, width: 1.2),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(16),
  //         ),
  //       ),
  //       child: const Text(
  //         'Criar conta',
  //         style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  //       ),
  //     ),
  //   );
  // }

  // -----------------------------------------------------
  // Rodapé "Feito pela Fluxe"
  // -----------------------------------------------------
  Widget _buildFooter() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 25),
          const SizedBox(width: 4),
          Text.rich(
            TextSpan(
              text: 'Feito pela ',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 18),
              children: const [
                TextSpan(
                  text: 'Fluxe',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}