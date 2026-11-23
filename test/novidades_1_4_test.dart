import 'package:fluxe_app/main.dart';
import 'package:fluxe_app/models/models.dart';
import 'package:fluxe_app/screens/diagnostico_ia_screen.dart';
import 'package:fluxe_app/screens/producao_screen.dart';
import 'package:fluxe_app/widgets/sicapda_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// Versão 1.4: o que o site ganhou depois da 1.3 e agora também está no app.
//  • Produção no menu (no PC é uma seção do menu lateral, como no site; no celular abre por cima das abas) e o
//    atalho "Registrar produção" no gráfico Previsão de Demanda do Painel.
//  • Menu lateral recolhível no PC (botão « / » e Ctrl + B), com a escolha salva no aparelho.
//  • Assistente com IA: o campo de pergunta convida a perguntar também sobre o uso do sistema, e o administrador
//    tem o Diagnóstico da IA (o mesmo de /assistente/diagnostico do site).
//  • Relatórios: exportar em Excel ou em CSV, como os dois botões do site (testes em configuracoes_test.dart).

const _pc = Size(1280, 900);
const _celular = Size(1080, 2340);

Future<void> abrir(WidgetTester tester, MockClient client, {Size tela = _pc, double dpr = 1}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final c = await newController(client: client, loggedIn: true);
  await tester.pumpWidget(SicapdaApp(controller: c));
  await tester.pumpAndSettle();
}

int gets(List<http.Request> log, String caminho) => log.where((r) => r.method == 'GET' && r.url.path == caminho).length;

/// Largura do menu lateral fixo (o AnimatedContainer em volta do menu).
double larguraMenu(WidgetTester tester) => tester.getSize(find.ancestor(
      of: find.byKey(const Key('btn-recolher-menu')),
      matching: find.byType(AnimatedContainer),
    ).first).width;

void main() {
  group('Produção no menu e no Painel', () {
    testWidgets('PC: Produção é uma seção do menu lateral (o menu continua à vista, como no site)', (tester) async {
      final log = <http.Request>[];
      await abrir(tester, fakeApi(log: log));

      await tester.tap(find.byKey(const Key('menu-producao')));
      await tester.pumpAndSettle();

      expect(find.byType(ProducaoScreen), findsOneWidget);
      expect(find.text('Produção de Qui, 12/11'), findsOneWidget);
      expect(find.byType(SicapdaLogo), findsOneWidget); // não abriu por cima: o menu lateral está ali
      expect(find.byTooltip('Voltar'), findsNothing);
      expect(gets(log, '/api/producao'), 1);

      // trocar de seção e voltar não perde o que foi digitado
      await tester.enterText(find.byKey(const Key('prod-ceia')), '9');
      await tester.tap(find.text('Relatórios'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menu-producao')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('prod-ceia'))).controller!.text, '9');
    });

    testWidgets('PC: "Registrar produção" do gráfico Previsão de Demanda leva à Produção', (tester) async {
      await abrir(tester, fakeApi());

      final atalho = find.byKey(const Key('painel-registrar-producao'));
      await tester.ensureVisible(atalho);
      await tester.pumpAndSettle();
      await tester.tap(atalho);
      await tester.pumpAndSettle();

      expect(find.byType(ProducaoScreen), findsOneWidget);
      expect(find.byType(SicapdaLogo), findsOneWidget);
    });

    testWidgets('celular: o atalho do Painel abre a Produção por cima e, ao voltar, o Painel recarrega', (tester) async {
      final log = <http.Request>[];
      await abrir(tester, fakeApi(log: log), tela: _celular, dpr: 3);
      final antes = gets(log, '/api/painel');

      final atalho = find.byKey(const Key('painel-registrar-producao'));
      await tester.scrollUntilVisible(atalho, 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(atalho);
      await tester.pumpAndSettle();

      expect(find.byType(ProducaoScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing); // tela por cima das abas
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(ProducaoScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(gets(log, '/api/painel'), greaterThan(antes)); // voltou com os números novos
    });

    testWidgets('PC: o atalho da Análise mensal também leva à seção Produção', (tester) async {
      await abrir(tester, fakeApi());
      await tester.tap(find.text('Análise mensal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registrar-producao')));
      await tester.pumpAndSettle();
      expect(find.byType(ProducaoScreen), findsOneWidget);
      expect(find.byType(SicapdaLogo), findsOneWidget);
    });
  });

  group('menu lateral recolhível (PC)', () {
    testWidgets('« recolhe para os ícones, » abre de novo, e a escolha fica salva', (tester) async {
      await abrir(tester, fakeApi());
      expect(larguraMenu(tester), 272);
      expect(find.byType(SicapdaLogo), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-recolher-menu')));
      await tester.pumpAndSettle();
      expect(larguraMenu(tester), 80);
      expect(find.byType(SicapdaLogo), findsNothing); // como no site: só a faixa com os ícones
      expect(find.text('Pessoas'), findsNothing);
      expect(find.byTooltip('Pessoas'), findsOneWidget); // o nome aparece ao passar o mouse
      // e o leitor de tela continua lendo cada ícone como um botão com o nome da tela
      final semantica = tester.ensureSemantics();
      expect(tester.getSemantics(find.bySemanticsLabel('Pessoas')),
          matchesSemantics(label: 'Pessoas', isButton: true, hasTapAction: true, hasSelectedState: true));
      semantica.dispose();
      expect((await SharedPreferences.getInstance()).getBool('menu_recolhido'), isTrue);
      expect(tester.takeException(), isNull);

      // recolhido, os ícones continuam levando às telas
      await tester.tap(find.byTooltip('Relatórios'));
      await tester.pumpAndSettle();
      expect(find.text('Registros de acesso do sistema'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-recolher-menu')));
      await tester.pumpAndSettle();
      expect(larguraMenu(tester), 272);
      expect(find.text('Pessoas'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getBool('menu_recolhido'), isFalse);
    });

    testWidgets('Ctrl + B recolhe e abre o menu (o mesmo atalho do site)', (tester) async {
      await abrir(tester, fakeApi());

      Future<void> ctrlB() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await ctrlB();
      expect(larguraMenu(tester), 80);
      await ctrlB();
      expect(larguraMenu(tester), 272);
    });

    testWidgets('abre recolhido se foi assim que a pessoa deixou, sem nada cortado no meio da animação', (tester) async {
      tester.view.physicalSize = _pc;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(), loggedIn: true);
      await c.setMenuRecolhido(true);
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      expect(larguraMenu(tester), 80);

      // abrindo: em cada quadro da animação o menu se desenha sem estourar a largura
      await tester.tap(find.byKey(const Key('btn-recolher-menu')));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(larguraMenu(tester), 272);
    });

    testWidgets('tocar no nome de quem está logado abre Configurações (Perfil), como no site', (tester) async {
      await abrir(tester, fakeApi());
      await tester.tap(find.byKey(const Key('menu-perfil')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aba-perfil')), findsOneWidget);
    });

    testWidgets('celular: o menu deslizante não tem o botão de recolher', (tester) async {
      await abrir(tester, fakeApi(), tela: _celular, dpr: 3);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn-recolher-menu')), findsNothing);
      expect(find.byKey(const Key('menu-producao')), findsOneWidget);
    });
  });

  group('assistente', () {
    testWidgets('com a IA ligada no servidor, o campo convida a perguntar também sobre o uso do sistema', (tester) async {
      await abrir(
        tester,
        fakeApi(overrides: {'GET /api/assistente': (_) => jsonResposta({...fixtureJson('assistente'), 'ia': true})}),
        tela: _celular,
        dpr: 3,
      );
      await tester.tap(find.text('IA').last);
      await tester.pumpAndSettle();
      expect(find.text('Pergunte sobre os dados ou como usar o sistema...'), findsOneWidget);
    });

    testWidgets('sem a IA, o campo continua como antes', (tester) async {
      await abrir(tester, fakeApi(), tela: _celular, dpr: 3);
      await tester.tap(find.text('IA').last);
      await tester.pumpAndSettle();
      expect(find.text('Digite sua pergunta...'), findsOneWidget);
    });
  });

  group('diagnóstico da IA (administrador)', () {
    Future<void> abrirDiagnostico(WidgetTester tester) async {
      await tester.tap(find.text('IA').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('diagnostico-ia')));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra a configuração do servidor e o teste para na etapa que falhou, com o motivo', (tester) async {
      final log = <http.Request>[];
      await abrir(tester, fakeApi(log: log), tela: _celular, dpr: 3);
      await abrirDiagnostico(tester);

      expect(find.byType(DiagnosticoIAScreen), findsOneWidget);
      expect(find.text('IA_API_KEY'), findsOneWidget);
      expect(find.text('vazia ou não encontrada no config/.env'), findsOneWidget);
      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/assistente/diagnostico'), isEmpty);

      await tester.ensureVisible(find.byKey(const Key('testar-ia')));
      await tester.tap(find.byKey(const Key('testar-ia')));
      await tester.pumpAndSettle();

      expect(log.where((r) => r.method == 'POST' && r.url.path == '/api/assistente/diagnostico'), hasLength(1));
      expect(find.byKey(const Key('etapa-1-falhou')), findsOneWidget);
      expect(find.textContaining('a chave não foi lida'), findsOneWidget);
      expect(find.textContaining('O teste parou na primeira etapa que falhou'), findsOneWidget);
      expect(find.text('Testar de novo'), findsOneWidget);
    });

    testWidgets('IA funcionando: todas as etapas passam', (tester) async {
      final ok = {
        ...fixtureJson('diagnostico_ia_teste'),
        'ia': true,
        'tudoCerto': true,
        'etapas': [
          for (var i = 1; i <= 4; i++) {'titulo': '$i. Etapa', 'ok': true, 'detalhe': 'Resposta $i', 'ms': 900}
        ],
      };
      await abrir(tester, fakeApi(overrides: {'POST /api/assistente/diagnostico': (_) => jsonResposta(ok)}),
          tela: _celular, dpr: 3);
      await abrirDiagnostico(tester);
      await tester.ensureVisible(find.byKey(const Key('testar-ia')));
      await tester.tap(find.byKey(const Key('testar-ia')));
      await tester.pumpAndSettle();
      for (var i = 1; i <= 4; i++) {
        expect(find.byKey(Key('etapa-$i-ok')), findsOneWidget);
      }
      expect(find.textContaining('Tudo certo: a IA está funcionando'), findsOneWidget);
    });

    testWidgets('servidor sem a rota (SystemFluxe antigo): explica o que fazer', (tester) async {
      await abrir(
        tester,
        fakeApi(overrides: {
          'GET /api/assistente/diagnostico': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Rota não encontrada.'}, 404),
        }),
        tela: _celular,
        dpr: 3,
      );
      await abrirDiagnostico(tester);
      expect(find.textContaining('Atualize o SystemFluxe'), findsOneWidget);
    });

    testWidgets('quem não é administrador não vê o diagnóstico', (tester) async {
      tester.view.physicalSize = _celular;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(), loggedIn: true);
      final me = fixtureJson('me')['usuario'] as Map<String, dynamic>;
      await c.atualizarUsuario(Usuario.fromJson({...me, 'perfil': 'usuario'}));
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('IA').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diagnostico-ia')), findsNothing);
    });
  });
}
