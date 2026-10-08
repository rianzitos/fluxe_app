import 'package:fluxe_app/core/app_state.dart';
import 'package:fluxe_app/main.dart';
import 'package:fluxe_app/widgets/sicapda_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester, AppController c) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SicapdaApp(controller: c));
  await tester.pumpAndSettle();
}

/// Janela de PC (1280x720, sem escala): o app mostra o menu lateral fixo.
Future<void> pumpAppPc(WidgetTester tester, AppController c) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SicapdaApp(controller: c));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login mostra a logo oficial do SICAPDA', (tester) async {
    final c = await newController();
    await pumpApp(tester, c);

    expect(find.byType(SicapdaLogo), findsOneWidget);
    expect(find.bySemanticsLabel('SICAPDA by Fluxe'), findsOneWidget);
  });

  testWidgets('celular: menu deslizante com a logo e barra de abas embaixo', (tester) async {
    final c = await newController(loggedIn: true);
    await pumpApp(tester, c);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SicapdaLogo), findsNothing); // menu fechado
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(SicapdaLogo), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
  });

  testWidgets('PC: menu lateral fixo com a logo, sem barra de abas nem botão de menu', (tester) async {
    final c = await newController(loggedIn: true);
    await pumpAppPc(tester, c);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Menu'), findsNothing);
    expect(find.byType(SicapdaLogo), findsOneWidget);
    expect(find.text('Painel Geral'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);

    // navega pelo menu lateral
    await tester.tap(find.text('Pessoas'));
    await tester.pumpAndSettle();
    expect(find.text('Total Presente'), findsOneWidget);
    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();
    expect(find.text('Total de Registros'), findsOneWidget);

    // Configurações abre por cima, com seta de voltar (não há menu para abrir)
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Voltar'), findsOneWidget);
  });

  testWidgets('PC: sair pelo menu lateral volta ao login', (tester) async {
    final c = await newController(loggedIn: true);
    await pumpAppPc(tester, c);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sair')); // confirma no diálogo
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('login com senha errada mostra o erro do servidor', (tester) async {
    final c = await newController();
    await pumpApp(tester, c);

    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'rian@fluxe.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'errada');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
    expect(c.isLoggedIn, isFalse);
  });

  testWidgets('campos vazios são validados antes de chamar a API', (tester) async {
    final c = await newController();
    await pumpApp(tester, c);

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
  });

  testWidgets('login válido abre o Painel e navega por todas as telas', (tester) async {
    final c = await newController();
    await pumpApp(tester, c);

    await tester.enterText(find.byType(TextFormField).at(0), 'rian@fluxe.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(c.isLoggedIn, isTrue);
    // Painel
    expect(find.text('Painel Geral'), findsOneWidget);
    expect(find.text('Usuários Ativos'), findsOneWidget);
    expect(find.text('Acessos Realizados'), findsOneWidget);
    expect(find.text('Previsão de Demanda'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // badge do sino: 3 alertas

    // Análise mensal
    await tester.tap(find.text('Análise'));
    await tester.pumpAndSettle();
    expect(find.text('Análise Mensal'), findsOneWidget);
    expect(find.text('Total Produzido'), findsOneWidget);

    // Pessoas
    await tester.tap(find.text('Pessoas').last);
    await tester.pumpAndSettle();
    expect(find.text('Total Presente'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'zzzz-inexistente');
    await tester.pumpAndSettle();
    expect(find.textContaining('Entrada:'), findsNothing);

    // Assistente
    await tester.tap(find.text('IA'));
    await tester.pumpAndSettle();
    expect(find.text('Precisão da IA'), findsOneWidget);
    await tester.tap(find.text('Previsão para amanhã'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Produção recomendada'), findsOneWidget);

    // Relatórios
    await tester.tap(find.text('Relatórios').last);
    await tester.pumpAndSettle();
    expect(find.text('Total de Registros'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Mostrando'), 600, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Mostrando 1–20'), findsOneWidget);
  });

  testWidgets('sessão salva reabre direto no app e logout volta ao login', (tester) async {
    final c = await newController(loggedIn: true);
    await pumpApp(tester, c);
    expect(find.text('Painel Geral'), findsOneWidget);

    await c.logout();
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });

  testWidgets('tema escuro pode ser ativado e fica salvo', (tester) async {
    final c = await newController(loggedIn: true);
    await pumpApp(tester, c);

    await c.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(find.text('Painel Geral'), findsOneWidget);
  });
}
