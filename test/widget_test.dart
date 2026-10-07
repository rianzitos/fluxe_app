import 'package:fluxe_app/core/app_state.dart';
import 'package:fluxe_app/main.dart';
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

void main() {
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
