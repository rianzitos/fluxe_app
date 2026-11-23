import 'dart:convert';

import 'package:fluxe_app/main.dart';
import 'package:fluxe_app/screens/producao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

// Tela Produção: quilos produzidos e desperdiçados por refeição (GET/POST /api/producao). O JSON de
// test/fixtures/producao.json é a resposta real do SystemFluxe para 12/11 (com os dados de exemplo).

/// Abre o app logado no PC (menu lateral fixo) e entra em Produção pelo menu.
Future<void> abrirProducao(WidgetTester tester, MockClient client) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await newController(client: client, loggedIn: true);
  await tester.pumpWidget(SicapdaApp(controller: c));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Produção'));
  await tester.pumpAndSettle();
}

Future<void> rolar(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    // A lista da tela (os campos de texto também têm um Scrollable dentro, na horizontal).
    final lista = find.descendant(
      of: find.byType(ProducaoScreen),
      matching: find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical),
    );
    await tester.scrollUntilVisible(f, 250, scrollable: lista.first);
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
}

Future<void> digitar(WidgetTester tester, String chave, String texto) async {
  await rolar(tester, find.byKey(Key(chave)));
  await tester.enterText(find.byKey(Key(chave)), texto);
  await tester.pump();
}

Future<void> salvar(WidgetTester tester) async {
  await rolar(tester, find.byKey(const Key('salvar-producao')));
  await tester.tap(find.byKey(const Key('salvar-producao')));
  await tester.pumpAndSettle();
}

List<http.Request> posts(List<http.Request> log) =>
    log.where((r) => r.method == 'POST' && r.url.path == '/api/producao').toList();

void main() {
  group('números digitados', () {
    test('aceita vírgula ou ponto; em branco é null; texto não é número', () {
      expect(lerKg('12,5'), 12.5);
      expect(lerKg(' 12.5 '), 12.5);
      expect(lerKg('0'), 0);
      expect(lerKg(''), isNull);
      expect(lerKg('abc')!.isNaN, isTrue);
      expect(lerKg('-3')!.isNaN, isTrue);
      expect(diaCurto('2026-11-12'), 'Qui, 12/11');
    });
  });

  group('tela Produção', () {
    testWidgets('abre pelo menu com o dia, os cartões, as refeições e o histórico', (tester) async {
      final log = <http.Request>[];
      await abrirProducao(tester, fakeApi(log: log));

      expect(log.where((r) => r.url.path == '/api/producao'), isNotEmpty);
      expect(find.text('Produção de Qui, 12/11'), findsOneWidget);
      expect(find.text('Produzido no dia'), findsOneWidget);
      expect(find.text('Previsão para o dia'), findsOneWidget);
      for (final r in ['Café da manhã', 'Almoço', 'Jantar', 'Ceia']) {
        expect(find.text(r), findsOneWidget);
      }
      // valores gravados aparecem nos campos, no formato brasileiro
      final almoco = tester.widget<TextField>(find.byKey(const Key('prod-almoco')));
      expect(almoco.controller!.text, '18,63');
      await rolar(tester, find.byKey(const Key('historico-2026-11-12')));
      expect(find.byKey(const Key('historico-2026-11-12')), findsOneWidget);
    });

    testWidgets('salvar envia as refeições do dia e mostra a confirmação', (tester) async {
      final log = <http.Request>[];
      await abrirProducao(tester, fakeApi(log: log));

      await digitar(tester, 'prod-almoco', '20,5');
      await digitar(tester, 'desp-almoco', '1,5');
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('pct-almoco')), matching: find.byType(Text))).data,
          '7,3%'); // % calculado enquanto digita
      await salvar(tester);

      final enviados = posts(log);
      expect(enviados, hasLength(1));
      final corpo = jsonDecode(enviados.single.body) as Map<String, dynamic>;
      expect(corpo['data'], '2026-11-12');
      final itens = {for (final i in corpo['itens'] as List) i['tipo']: i};
      expect(itens['almoco'], {'tipo': 'almoco', 'produzido': 20.5, 'desperdicado': 1.5});
      expect(itens.keys, containsAll(['cafe', 'almoco', 'jantar', 'ceia'])); // o dia todo já estava registrado
      expect(find.byKey(const Key('status-producao')), findsOneWidget);
      expect(find.textContaining('salva. O painel e a análise mensal'), findsOneWidget);
    });

    testWidgets('desperdício maior que o produzido e texto no campo não vão para o servidor', (tester) async {
      final log = <http.Request>[];
      await abrirProducao(tester, fakeApi(log: log));

      await digitar(tester, 'prod-jantar', '5');
      await digitar(tester, 'desp-jantar', '6');
      await salvar(tester);
      expect(find.textContaining('Jantar: o desperdício não pode ser maior'), findsOneWidget);

      await digitar(tester, 'desp-jantar', 'abc');
      await salvar(tester);
      expect(find.textContaining('Jantar: digite só números'), findsOneWidget);
      expect(posts(log), isEmpty);
    });

    testWidgets('recusa do servidor aparece na tela', (tester) async {
      await abrirProducao(tester, fakeApi(overrides: {
        'POST /api/producao': (_) => jsonResposta(
            {'sucesso': false, 'mensagem': 'Não dá para registrar produção de um dia que ainda não chegou.'}, 422),
      }));
      await digitar(tester, 'prod-ceia', '3');
      await salvar(tester);
      expect(find.text('Não dá para registrar produção de um dia que ainda não chegou.'), findsOneWidget);
    });

    testWidgets('tocar num dia do histórico carrega aquele dia (e avisa antes de perder o que foi digitado)', (tester) async {
      final log = <http.Request>[];
      await abrirProducao(tester, fakeApi(log: log));

      await digitar(tester, 'prod-ceia', '9');
      await rolar(tester, find.byKey(const Key('historico-2026-11-10')));
      await tester.tap(find.byKey(const Key('historico-2026-11-10')));
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      final ultimo = log.lastWhere((r) => r.url.path == '/api/producao' && r.method == 'GET');
      expect(ultimo.url.queryParameters['data'], '2026-11-10');
    });

    testWidgets('Análise mensal tem o atalho "Registrar produção"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(), loggedIn: true);
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Análise'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registrar-producao')));
      await tester.pumpAndSettle();
      expect(find.byType(ProducaoScreen), findsOneWidget);
      expect(find.text('Produção de Qui, 12/11'), findsOneWidget);
    });

    testWidgets('tema escuro e celular: a tela monta sem erros', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(), loggedIn: true);
      await c.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menu').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produção'));
      await tester.pumpAndSettle();
      expect(find.byType(ProducaoScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
