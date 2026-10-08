import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'widgets/sicapda_logo.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SicapdaApp(controller: AppController()..init()));
}

class SicapdaApp extends StatelessWidget {
  final AppController controller;
  const SicapdaApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'SICAPDA',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _PcScrollBehavior(),
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: controller.themeMode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: !controller.ready
              ? const _Splash()
              : (controller.isLoggedIn ? const AppShell() : const LoginScreen()),
        ),
      ),
    );
  }
}

/// No PC dá para rolar e puxar para atualizar arrastando com o mouse, como no celular com o dedo.
class _PcScrollBehavior extends MaterialScrollBehavior {
  const _PcScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SicapdaLogo(width: 260),
              SizedBox(height: 28),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.accent),
              ),
            ],
          ),
        ),
      );
}
