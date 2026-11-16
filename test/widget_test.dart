import 'dart:convert';

import 'package:fluxe_app/core/app_state.dart';
import 'package:fluxe_app/main.dart';
import 'package:fluxe_app/widgets/sicapda_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  testWidgets('sem conexão com o servidor, o login explica e mostra o detalhe técnico', (tester) async {
    final semRede = MockClient((_) async => throw http.ClientException(
        "Failed host lookup: 'fluxeteam.com.br'", Uri.parse('https://fluxeteam.com.br/api/login')));
    final c = await newController(client: semRede);
    await pumpApp(tester, c);

    await tester.enterText(find.byType(TextFormField).at(0), 'rian@fluxe.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha1234');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível conectar ao servidor'), findsOneWidget);
    expect(find.byKey(const Key('erro-detalhe')), findsOneWidget);
    expect(find.textContaining("Failed host lookup: 'fluxeteam.com.br'"), findsOneWidget);
    expect(c.isLoggedIn, isFalse);
  });

  testWidgets('servidor com http:// mostra o aviso de conexão sem criptografia', (tester) async {
    final c = await newController();
    await pumpApp(tester, c);

    await tester.tap(find.text('Servidor'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aviso-http')), findsNothing); // padrão: https

    await tester.enterText(find.byType(TextFormField).at(2), 'http://192.168.0.10:8000');
    await tester.pump();
    expect(find.byKey(const Key('aviso-http')), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), 'https://fluxeteam.com.br');
    await tester.pump();
    expect(find.byKey(const Key('aviso-http')), findsNothing);
  });

  testWidgets('esqueci minha senha: envia o e-mail digitado e mostra a resposta do servidor', (tester) async {
    final log = <http.Request>[];
    final c = await newController(client: fakeApi(log: log, overrides: {
      'POST /api/senha/esqueci': (_) => jsonResposta({
            'sucesso': true,
            'mensagem': 'Se este e-mail estiver cadastrado, você vai receber em instantes um link para criar uma senha nova.',
          }),
    }));
    await pumpApp(tester, c);

    await tester.enterText(find.byType(TextFormField).at(0), 'rian@fluxe.com');
    await tester.tap(find.byKey(const Key('esqueci-senha')));
    await tester.pumpAndSettle();

    // O e-mail do login já vem preenchido
    expect(find.text('Esqueci minha senha'), findsNWidgets(2)); // botão + título da janela
    expect(tester.widget<TextFormField>(find.byKey(const Key('esqueci-email'))).controller!.text, 'rian@fluxe.com');

    await tester.tap(find.byKey(const Key('esqueci-enviar')));
    await tester.pumpAndSettle();

    final pedido = log.lastWhere((r) => r.url.path == '/api/senha/esqueci');
    expect(pedido.method, 'POST');
    expect(pedido.body, '{"email":"rian@fluxe.com"}');
    expect(pedido.headers['Authorization'], isNull); // rota pública, sem token
    expect(find.byKey(const Key('esqueci-enviado')), findsOneWidget);
    expect(find.textContaining('Se este e-mail estiver cadastrado'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('esqueci-enviado')), findsNothing);
    expect(c.isLoggedIn, isFalse);
  });

  testWidgets('esqueci minha senha: valida o e-mail e mostra o erro do servidor', (tester) async {
    final log = <http.Request>[];
    final c = await newController(client: fakeApi(log: log, overrides: {
      'POST /api/senha/esqueci': (_) => jsonResposta(
          {'sucesso': false, 'mensagem': 'Muitos pedidos seguidos. Aguarde alguns minutos e tente de novo.'}, 429),
    }));
    await pumpApp(tester, c);

    await tester.tap(find.byKey(const Key('esqueci-senha')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('esqueci-enviar')));
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail'), findsOneWidget);
    expect(log.where((r) => r.url.path == '/api/senha/esqueci'), isEmpty);

    await tester.enterText(find.byKey(const Key('esqueci-email')), 'rian@fluxe.com');
    await tester.tap(find.byKey(const Key('esqueci-enviar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('esqueci-erro')), findsOneWidget);
    expect(find.textContaining('Muitos pedidos seguidos'), findsOneWidget);
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

  group('verificação em duas etapas no login', () {
    /// Login com a senha certa numa conta com a verificação ativa: o servidor devolve o desafio, não o token.
    Future<(AppController, List<http.Request>)> entrarComSenha(WidgetTester tester, {String metodo = 'app'}) async {
      final log = <http.Request>[];
      final c = await newController(client: fakeApi(log: log, overrides: {
        'POST /api/login': (req) => jsonResposta({
              ...fixtureJson('login_duas_etapas'),
              'metodo': metodo,
              if (metodo == 'email') 'mensagem': 'Enviamos um código de 6 dígitos para ri•••@fluxe.com.',
            }),
      }));
      await pumpApp(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'rian@fluxe.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'senha1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      return (c, log);
    }

    Map<String, dynamic> corpo(List<http.Request> log, String caminho) =>
        jsonDecode(log.lastWhere((r) => r.url.path == caminho).body) as Map<String, dynamic>;

    testWidgets('senha certa pede o código do aplicativo; com os 6 dígitos entra sozinho', (tester) async {
      final (c, log) = await entrarComSenha(tester);

      // O app avisa ao servidor que sabe pedir o código (um app antigo recebe a explicação para atualizar)
      expect(corpo(log, '/api/login'), {'email': 'rian@fluxe.com', 'senha': 'senha1234', 'duas_etapas': true});
      expect(c.isLoggedIn, isFalse);
      expect(find.byKey(const Key('titulo-2fa')), findsOneWidget);
      expect(find.textContaining('aplicativo autenticador'), findsOneWidget);
      expect(find.byKey(const Key('btn-reenviar')), findsNothing); // no aplicativo não há o que reenviar

      await tester.enterText(find.byKey(const Key('codigo-2fa')), '12345a6'); // só dígitos entram
      await tester.pumpAndSettle();
      final pedido = corpo(log, '/api/login/verificar');
      expect(pedido['codigo'], '123456');
      expect(pedido['desafio'], fixtureJson('login_duas_etapas')['desafio']);
      expect(log.lastWhere((r) => r.url.path == '/api/login/verificar').headers['Authorization'], isNull);
      expect(c.isLoggedIn, isTrue);
      expect(find.text('Painel Geral'), findsOneWidget);
    });

    testWidgets('código errado mostra o erro e deixa tentar de novo', (tester) async {
      final (c, _) = await entrarComSenha(tester);

      await tester.enterText(find.byKey(const Key('codigo-2fa')), '000000');
      await tester.pumpAndSettle();
      expect(find.text('Código incorreto. Restam 4 tentativas.'), findsOneWidget);
      expect(find.byKey(const Key('titulo-2fa')), findsOneWidget);
      expect(c.isLoggedIn, isFalse);

      // Validação local: menos de 6 dígitos não chama o servidor
      await tester.enterText(find.byKey(const Key('codigo-2fa')), '12');
      await tester.tap(find.byKey(const Key('btn-verificar')));
      await tester.pumpAndSettle();
      expect(find.text('Digite o código de 6 dígitos'), findsOneWidget);
    });

    testWidgets('410 (errou 5 vezes ou venceu) volta ao formulário de login com a explicação', (tester) async {
      final log = <http.Request>[];
      final c = await newController(client: fakeApi(log: log, overrides: {
        'POST /api/login': (_) => jsonResposta(fixtureJson('login_duas_etapas')),
        'POST /api/login/verificar': (_) => jsonResposta(
            {'sucesso': false, 'mensagem': 'Você errou o código 5 vezes. Por segurança, entre de novo com e-mail e senha.'}, 410),
      }));
      await pumpApp(tester, c);
      await tester.enterText(find.byType(TextFormField).at(0), 'rian@fluxe.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'senha1234');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('codigo-2fa')), '999999');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('titulo-2fa')), findsNothing);
      expect(find.text('Bem-vindo de volta!'), findsOneWidget);
      expect(find.textContaining('errou o código 5 vezes'), findsOneWidget);
      // O e-mail continua preenchido; a senha precisa ser digitada de novo
      expect(tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller!.text, 'rian@fluxe.com');
      expect(tester.widget<TextFormField>(find.byType(TextFormField).at(1)).controller!.text, isEmpty);
      expect(c.isLoggedIn, isFalse);
    });

    testWidgets('código por e-mail: reenviar e entrar com um código de recuperação', (tester) async {
      final (c, log) = await entrarComSenha(tester, metodo: 'email');
      expect(find.textContaining('ri•••@fluxe.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-reenviar')));
      await tester.pumpAndSettle();
      expect(corpo(log, '/api/login/reenviar'), {'desafio': fixtureJson('login_duas_etapas')['desafio']});
      expect(find.byKey(const Key('aviso-2fa')), findsOneWidget);
      expect(find.textContaining('O anterior não vale mais'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-recuperacao')));
      await tester.pumpAndSettle();
      expect(find.textContaining('10 códigos de recuperação'), findsOneWidget);
      expect(find.byKey(const Key('btn-reenviar')), findsNothing);
      await tester.enterText(find.byKey(const Key('codigo-2fa')), 'ABCDE-FGHIJ');
      await tester.tap(find.byKey(const Key('btn-verificar')));
      await tester.pumpAndSettle();
      expect(corpo(log, '/api/login/verificar')['codigo'], 'ABCDE-FGHIJ');
      expect(c.isLoggedIn, isTrue);
    });

    testWidgets('"Voltar ao login" desiste da segunda etapa', (tester) async {
      final (c, _) = await entrarComSenha(tester);
      await tester.tap(find.byKey(const Key('btn-voltar-login')));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo de volta!'), findsOneWidget);
      expect(c.isLoggedIn, isFalse);
    });
  });
}
