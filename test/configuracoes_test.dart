import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluxe_app/core/ao_vivo.dart';
import 'package:fluxe_app/core/api_client.dart';
import 'package:fluxe_app/core/app_state.dart';
import 'package:fluxe_app/core/arquivos.dart';
import 'package:fluxe_app/core/config_service.dart';
import 'package:fluxe_app/core/versao.dart';
import 'package:fluxe_app/main.dart';
import 'package:fluxe_app/models/models.dart';
import 'package:fluxe_app/widgets/navegacao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

// Funções que o app ganhou na versão 1.2 para ficar igual ao site: Configurações completas (perfil, foto, senha,
// notificações, sistema, dispositivos IoT, sessões), sino com os alertas do servidor, atalho de IoT, tempo real,
// importação de planilha e o campo do chat acima da barra de navegação do Android.
// Os JSONs de test/fixtures/ (preferencias, dispositivos, sessoes, notificacoes, aovivo, simular, importar, perfil)
// são respostas reais do SystemFluxe.

Map<String, dynamic> corpoDe(List<http.Request> log, String metodo, String caminho) =>
    jsonDecode(log.lastWhere((r) => r.method == metodo && r.url.path == caminho).body) as Map<String, dynamic>;

int pedidos(List<http.Request> log, String metodo, String caminho) =>
    log.where((r) => r.method == metodo && r.url.path == caminho).length;

Future<AppController> abrirApp(WidgetTester tester, MockClient client, {Size tela = const Size(1080, 2340), double dpr = 3}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final c = await newController(client: client, loggedIn: true);
  await tester.pumpWidget(SicapdaApp(controller: c));
  await tester.pumpAndSettle();
  return c;
}

/// Abre Configurações pelo menu e vai até a aba pedida.
Future<void> abrirConfig(WidgetTester tester, String aba) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Configurações'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(Key('aba-$aba'))); // no celular a barra de abas rola para o lado
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('aba-$aba')));
  await tester.pumpAndSettle();
}

/// A lista da tela só monta o que está perto da área visível: rola (na vertical) até o item existir.
Future<void> rolarAte(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical);
    await tester.scrollUntilVisible(f, 250, scrollable: vertical.first);
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await rolarAte(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> digitar(WidgetTester tester, String chave, String texto) async {
  await rolarAte(tester, find.byKey(Key(chave)));
  await tester.enterText(find.byKey(Key(chave)), texto);
  await tester.pump();
}

/// PNG de verdade (largura × altura) feito com o motor gráfico, para testar a foto do perfil.
Future<Uint8List> pngDeTeste(int largura, int altura) async {
  final gravador = ui.PictureRecorder();
  Canvas(gravador).drawRect(Rect.fromLTWH(0, 0, largura.toDouble(), altura.toDouble()), Paint()..color = const Color(0xFFFFC107));
  final imagem = await gravador.endRecording().toImage(largura, altura);
  final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  tearDown(() => escolherArquivo = ({required bool imagem}) async => null);

  group('modelos (JSON real da API)', () {
    test('preferências: catálogo de notificações, sistema e opções', () {
      final p = PreferenciasData.fromJson(fixtureJson('preferencias'));
      expect(p.notificacoes.map((n) => n.chave),
          ['previsao_demanda', 'acesso_negado', 'dispositivo_offline', 'email_desperdicio', 'resumo_diario']);
      expect(p.notificacoes.every((n) => n.disponivel), isTrue);
      expect(p.notificacoes.last.ativo, isFalse); // o resumo por e-mail vem desligado: a pessoa escolhe receber
      expect(p.periodoPadrao, 'mes');
      expect(p.itensPagina, 20);
      expect(p.periodos.map((o) => o.valor), ['mes', '7', '30', '90']);
      expect(p.opcoesItens, [10, 20, 50]);
      expect(p.fuso, contains('Brasília'));
    });

    test('dispositivos: token mascarado, online/offline, balanças e desperdício de hoje', () {
      final d = DispositivosData.fromJson(fixtureJson('dispositivos'));
      expect(d.podeEditar, isTrue);
      expect(d.dispositivos, hasLength(3));
      final balanca = d.balancas.single;
      expect(balanca.nome, 'Balança da Cozinha');
      expect(balanca.online, isTrue);
      expect(balanca.tokenMascarado, contains('…'));
      expect(d.catracas.map((c) => c.nome), containsAll(['Catraca Principal', 'Leitor do Refeitório']));
      expect(d.catracas.every((c) => !c.online), isTrue);
      expect(d.tipos.map((t) => t.valor), ['rfid', 'biometria', 'hibrido', 'balanca']);
      expect({for (final r in d.desperdicioHoje) r.tipo: r.kg}, {'cafe': null, 'almoco': 3.4, 'jantar': null, 'ceia': null});
    });

    test('sessões, sino, tempo real, simulação e importação', () {
      final sessoes = (fixtureJson('sessoes')['sessoes'] as List).cast<Map<String, dynamic>>().map(SessaoWeb.fromJson).toList();
      expect(sessoes.map((s) => s.dispositivo), ['Chrome · Android', 'Chrome · Windows']);
      expect(sessoes.first.celular, isTrue);

      final alertas = (fixtureJson('notificacoes')['alertas'] as List).cast<Map<String, dynamic>>().map(Alerta.fromJson).toList();
      expect(alertas.first.titulo, 'Acessos negados hoje');
      expect(alertas.first.link, '/relatorios');
      expect(alertas.any((a) => a.link == '/configuracoes#integracoes'), isTrue);

      final vivo = EstadoAoVivo.fromJson(fixtureJson('aovivo'));
      expect(vivo.novosAcessos, 1);
      expect(vivo.eventos.single.texto, 'Entrada · Maria Santos · 22:12');
      expect(const EventoAcesso(id: 1, direcao: 'entrada', resultado: 'negado', hora: '10:33').texto,
          'Acesso negado · cartão não cadastrado · 10:33');

      final sim = ResultadoLeitura.fromJson(fixtureJson('simular'));
      expect(sim.autorizado, isFalse);
      expect(sim.mensagem, 'Cartão não cadastrado.');

      final imp = ResultadoImportacao.fromJson(fixtureJson('importar'));
      expect((imp.pessoas, imp.cartoes, imp.ignoradas), (2, 1, 1));
      expect(imp.erros.single.linha, 4);
    });

    test('destino dos alertas: aba de Configurações pela âncora do site', () {
      expect(abaDoLink('/configuracoes#integracoes'), AbaConfig.integracoes);
      expect(abaDoLink('/configuracoes#iot'), AbaConfig.integracoes);
      expect(abaDoLink('/configuracoes#notificacoes'), AbaConfig.notificacoes);
      expect(abaDoLink('/configuracoes'), AbaConfig.perfil);
    });

    test('a versão mostrada no app é a do pubspec.yaml (a que o CI publica)', () {
      final linha = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
      expect(linha.split(':').last.trim().split('+').first, kVersaoApp);
    });

    test('servidor antigo (rota que não existe) é reconhecido; 404 de regra não', () {
      expect(servidorDesatualizado(const ApiException('Rota não encontrada.', status: 404)), isTrue);
      expect(servidorDesatualizado(const ApiException('Dispositivo não encontrado.', status: 404)), isFalse);
      expect(mensagemDoErro(const ApiException('Rota não encontrada.', status: 404)), mensagemServidorDesatualizado);
      expect(mensagemDoErro(const ApiException('Senha atual incorreta.', status: 403)), 'Senha atual incorreta.');
    });

    test('CSV do Excel em Windows-1252 não perde os acentos', () {
      expect(textoDoCsv(Uint8List.fromList(utf8.encode('nome;cargo\nJosé;Operário'))), 'nome;cargo\nJosé;Operário');
      expect(textoDoCsv(Uint8List.fromList(latin1.encode('nome;cargo\nJosé;Operário'))), 'nome;cargo\nJosé;Operário');
      // aspas curvas e travessão do Windows-1252 (0x93, 0x94, 0x96)
      expect(textoDoCsv(Uint8List.fromList([0x93, 0x41, 0x94, 0x20, 0x96, 0x20, 0xC9])), '“A” – É');
    });
  });

  group('foto do perfil', () {
    testWidgets('recorta o centro em quadrado e reduz para no máximo 512 px', (tester) async {
      await tester.runAsync(() async {
        final grande = await prepararFotoDePerfil(await pngDeTeste(1200, 800));
        final codec = await ui.instantiateImageCodec(grande);
        final quadro = (await codec.getNextFrame()).image;
        expect((quadro.width, quadro.height), (512, 512));

        final pequena = await prepararFotoDePerfil(await pngDeTeste(90, 300));
        final q2 = (await (await ui.instantiateImageCodec(pequena)).getNextFrame()).image;
        expect((q2.width, q2.height), (90, 90)); // não aumenta foto pequena
      });
    });
  });

  group('tempo real (AoVivo)', () {
    test('aprende o estado na 1ª consulta; depois avisa mudanças e acessos novos; para em servidor antigo', () async {
      var assinatura = 'a';
      var ultimo = 10;
      var eventos = <Map<String, dynamic>>[];
      var status = 200;
      final consultas = <Uri>[];
      final client = MockClient((req) async {
        consultas.add(req.url);
        if (status == 404) return jsonResposta({'sucesso': false, 'mensagem': 'Rota não encontrada.'}, 404);
        return jsonResposta({'sucesso': true, 'assinatura': assinatura, 'ultimoLog': ultimo, 'eventos': eventos, 'novosAcessos': eventos.length});
      });
      final vivo = AoVivo(() => ApiClient(baseUrl: 'http://s', token: 't', client: client));
      var mudancas = 0;
      vivo.mudancas.addListener(() => mudancas++);
      final avisos = <int>[];
      final sub = vivo.eventos.listen((e) => avisos.add(e.total));

      await vivo.consultarAgora();
      expect(consultas.single.queryParameters.containsKey('ultimo'), isFalse);
      expect(mudancas, 0); // a 1ª consulta só aprende o estado

      await vivo.consultarAgora();
      expect(consultas.last.queryParameters['ultimo'], '10');
      expect(mudancas, 0); // nada mudou

      assinatura = 'b';
      ultimo = 12;
      eventos = [
        {'id': 11, 'direcao': 'entrada', 'resultado': 'autorizado', 'nome': 'Ana', 'hora': '10:00'},
        {'id': 12, 'direcao': 'saida', 'resultado': 'autorizado', 'nome': 'Bia', 'hora': '10:01'},
      ];
      await vivo.consultarAgora();
      await Future<void>.delayed(Duration.zero);
      expect(mudancas, 1);
      expect(avisos, [2]);

      status = 404;
      await vivo.consultarAgora();
      expect(vivo.disponivel, isFalse);
      final antes = consultas.length;
      vivo.retomar();
      await vivo.consultarAgora();
      expect(consultas.length, antes); // não insiste num servidor sem a rota

      await sub.cancel();
      vivo.dispose();
    });
  });

  group('Configurações → Perfil', () {
    testWidgets('edita nome e cargo: manda ao servidor e o novo nome aparece no app todo', (tester) async {
      final log = <http.Request>[];
      final c = await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'perfil');

      expect(find.text('Informações Pessoais'), findsOneWidget);
      expect(find.byKey(const Key('perfil-senha-atual')), findsNothing);
      await digitar(tester, 'perfil-nome', 'Rian R. Silva');
      await digitar(tester, 'perfil-cargo', 'Coordenador');
      await tocar(tester, find.byKey(const Key('btn-salvar-perfil')));

      expect(corpoDe(log, 'POST', '/api/perfil'), {'nome': 'Rian R. Silva', 'email': 'rian@fluxe.com', 'cargo': 'Coordenador'});
      expect(find.text('Perfil atualizado com sucesso!'), findsOneWidget);
      expect(c.user!.nome, 'Rian R. Silva');
      expect(c.user!.cargo, 'Coordenador');
    });

    testWidgets('trocar o e-mail pede a senha atual (e não chama o servidor sem ela)', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'perfil');

      await digitar(tester, 'perfil-email', 'novo@fluxe.com');
      expect(find.byKey(const Key('perfil-senha-atual')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('btn-salvar-perfil')));
      expect(find.text('Para alterar o e-mail, informe sua senha atual.'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/perfil'), 0);

      await digitar(tester, 'perfil-senha-atual', 'senha1234');
      await tocar(tester, find.byKey(const Key('btn-salvar-perfil')));
      expect(corpoDe(log, 'POST', '/api/perfil')['senha_atual'], 'senha1234');
      expect(corpoDe(log, 'POST', '/api/perfil')['email'], 'novo@fluxe.com');
    });

    testWidgets('erro do servidor (senha atual errada) aparece no formulário', (tester) async {
      await abrirApp(tester, fakeApi(overrides: {
        'POST /api/perfil': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Senha atual incorreta.'}, 403),
      }));
      await abrirConfig(tester, 'perfil');
      await digitar(tester, 'perfil-email', 'novo@fluxe.com');
      await digitar(tester, 'perfil-senha-atual', 'errada');
      await tocar(tester, find.byKey(const Key('btn-salvar-perfil')));
      expect(find.text('Senha atual incorreta.'), findsOneWidget);
    });

    testWidgets('alterar foto: escolhe a imagem, reduz e envia em base64', (tester) async {
      final log = <http.Request>[];
      final c = await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'perfil');
      final png = (await tester.runAsync(() => pngDeTeste(800, 600)))!;
      escolherArquivo = ({required bool imagem}) async {
        expect(imagem, isTrue);
        return (nome: 'foto.png', bytes: png);
      };

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('btn-alterar-foto')));
        for (var i = 0; i < 50 && pedidos(log, 'POST', '/api/perfil/foto') == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();

      final enviada = base64Decode(corpoDe(log, 'POST', '/api/perfil/foto')['imagem'] as String);
      final dimensoes = await tester.runAsync(() async {
        final img = (await (await ui.instantiateImageCodec(enviada)).getNextFrame()).image;
        return (img.width, img.height);
      });
      expect(dimensoes, (512, 512));
      expect(c.user!.foto, endsWith('perfil_nova.png'));
      expect(find.text('Foto atualizada com sucesso!'), findsOneWidget);
    });
  });

  group('Configurações → Notificações e Sistema', () {
    testWidgets('liga/desliga um alerta, inclusive os e-mails automáticos, e o sino é atualizado', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'notificacoes');

      expect(find.text('Tentativas de acesso não autorizado'), findsOneWidget);
      expect(find.text('Desperdício alto por e-mail'), findsOneWidget);
      expect(find.text('Em breve'), findsNothing);
      final resumo = tester.widget<Switch>(find.byKey(const Key('notificacao-resumo_diario')));
      expect(resumo.onChanged, isNotNull);
      expect(resumo.value, isFalse);

      await tocar(tester, find.byKey(const Key('notificacao-resumo_diario')));
      expect(corpoDe(log, 'POST', '/api/preferencias/notificacao'), {'chave': 'resumo_diario', 'ativo': true});
      expect(tester.widget<Switch>(find.byKey(const Key('notificacao-resumo_diario'))).value, isTrue);

      await tocar(tester, find.byKey(const Key('notificacao-acesso_negado')));
      expect(corpoDe(log, 'POST', '/api/preferencias/notificacao'), {'chave': 'acesso_negado', 'ativo': false});
      expect(tester.widget<Switch>(find.byKey(const Key('notificacao-acesso_negado'))).value, isFalse);
      expect(pedidos(log, 'GET', '/api/notificacoes'), greaterThan(0));
    });

    testWidgets('recusa do servidor volta o interruptor e avisa', (tester) async {
      await abrirApp(tester, fakeApi(overrides: {
        'POST /api/preferencias/notificacao': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Notificação desconhecida.'}, 422),
      }));
      await abrirConfig(tester, 'notificacoes');
      await tocar(tester, find.byKey(const Key('notificacao-previsao_demanda')));
      expect(tester.widget<Switch>(find.byKey(const Key('notificacao-previsao_demanda'))).value, isTrue);
      expect(find.text('Notificação desconhecida.'), findsOneWidget);
    });

    testWidgets('sistema: período padrão e itens por página dos relatórios; tempo real deste aparelho', (tester) async {
      final log = <http.Request>[];
      final c = await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'sistema');

      expect(find.text('Horário de Brasília (GMT-3)'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('periodo-padrao')));
      await tocar(tester, find.text('Últimos 7 dias').last);
      await tocar(tester, find.byKey(const Key('itens-pagina')));
      await tocar(tester, find.text('50').last);
      await tocar(tester, find.byKey(const Key('btn-salvar-sistema')));
      expect(corpoDe(log, 'POST', '/api/preferencias/sistema'), {'periodo_padrao': '7', 'itens_pagina': 50});
      expect(find.text('Preferências salvas.'), findsOneWidget);

      expect(c.aoVivoAtivo, isTrue);
      await tocar(tester, find.byKey(const Key('switch-tempo-real')));
      expect(c.aoVivoAtivo, isFalse);
      expect(c.aoVivo.rodando, isFalse); // desligado: o app para de consultar
    });

    testWidgets('servidor antigo: explica que é preciso atualizar o SystemFluxe', (tester) async {
      await abrirApp(tester, fakeApi(overrides: {
        'GET /api/preferencias': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Rota não encontrada.'}, 404),
      }));
      await abrirConfig(tester, 'notificacoes');
      expect(find.text(mensagemServidorDesatualizado), findsOneWidget);
    });
  });

  group('Configurações → Integrações (dispositivos IoT)', () {
    testWidgets('lista os dispositivos com status e o desperdício de hoje', (tester) async {
      await abrirApp(tester, fakeApi());
      await abrirConfig(tester, 'integracoes');

      expect(find.text('Balança da Cozinha'), findsOneWidget);
      expect(find.text('Catraca Principal'), findsWidgets);
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Offline'), findsNWidgets(2));
      await rolarAte(tester, find.byKey(const Key('desperdicio-almoco')));
      expect(tester.widget<Text>(find.byKey(const Key('desperdicio-almoco'))).data, '3,40 kg');
      expect(tester.widget<Text>(find.byKey(const Key('desperdicio-cafe'))).data, 'Sem registro');
    });

    testWidgets('adicionar dispositivo mostra o token inteiro uma única vez', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'integracoes');

      await tocar(tester, find.byKey(const Key('btn-adicionar-dispositivo')));
      await tocar(tester, find.byKey(const Key('btn-criar-dispositivo')));
      expect(find.text('Informe o nome do dispositivo (até 150 caracteres).'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/dispositivos/criar'), 0);

      await digitar(tester, 'dispositivo-nome', 'Catraca dos Fundos');
      await tocar(tester, find.byKey(const Key('dispositivo-tipo')));
      await tocar(tester, find.text('Balança de desperdício').last);
      await digitar(tester, 'dispositivo-local', 'Doca');
      await tocar(tester, find.byKey(const Key('btn-criar-dispositivo')));

      expect(corpoDe(log, 'POST', '/api/dispositivos/criar'), {'nome': 'Catraca dos Fundos', 'tipo': 'balanca', 'localizacao': 'Doca'});
      expect(find.text('Catraca dos Fundos criado'), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const Key('token-revelado'))).data, 'a1' * 32);
      await tocar(tester, find.text('Já copiei'));
      expect(find.byKey(const Key('token-revelado')), findsNothing);
      expect(pedidos(log, 'GET', '/api/dispositivos'), greaterThanOrEqualTo(2)); // a lista foi atualizada
    });

    testWidgets('novo token pede confirmação', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'integracoes');

      await tocar(tester, find.byKey(const Key('btn-novo-token-1')));
      expect(find.textContaining('deixa de ser aceito'), findsOneWidget);
      await tocar(tester, find.text('Cancelar'));
      expect(pedidos(log, 'POST', '/api/dispositivos/token'), 0);

      await tocar(tester, find.byKey(const Key('btn-novo-token-1')));
      await tocar(tester, find.text('Gerar token'));
      expect(corpoDe(log, 'POST', '/api/dispositivos/token'), {'id': 1});
      expect(tester.widget<SelectableText>(find.byKey(const Key('token-revelado'))).data, 'b2' * 32);
    });

    testWidgets('simular leitura e testar pesagem', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'integracoes');

      await digitar(tester, 'simular-uid', 'ca:fe 00 02');
      await tocar(tester, find.byKey(const Key('btn-simular')));
      expect(corpoDe(log, 'POST', '/api/dispositivos/simular')['uid'], 'CAFE0002');
      expect(find.text('Cartão não cadastrado.'), findsOneWidget);

      await digitar(tester, 'pesagem-kg', '2,75');
      await tocar(tester, find.byKey(const Key('btn-registrar-pesagem')));
      expect(corpoDe(log, 'POST', '/api/dispositivos/pesagem'), {'id': 22, 'tipo': 'cafe', 'desperdicio_kg': 2.75});
      expect(find.text('Total de desperdício registrado.'), findsOneWidget);

      await digitar(tester, 'pesagem-kg', '1.5');
      await tocar(tester, find.byKey(const Key('btn-registrar-pesagem')));
      expect(corpoDe(log, 'POST', '/api/dispositivos/pesagem')['desperdicio_kg'], 1.5);
    });

    testWidgets('quem não é administrador só consulta', (tester) async {
      await abrirApp(tester, fakeApi(overrides: {
        'GET /api/dispositivos': (_) => jsonResposta(fixtureJson('dispositivos')..['podeEditar'] = false),
      }));
      await abrirConfig(tester, 'integracoes');
      expect(find.text('Balança da Cozinha'), findsOneWidget);
      expect(find.byKey(const Key('btn-adicionar-dispositivo')), findsNothing);
      expect(find.byKey(const Key('btn-novo-token-1')), findsNothing);
      expect(find.byKey(const Key('btn-simular')), findsNothing);
      expect(find.text('Somente o administrador da empresa pode adicionar dispositivos e gerar tokens.'), findsOneWidget);
    });

    testWidgets('o atalho IoT do cabeçalho abre direto nas Integrações', (tester) async {
      await abrirApp(tester, fakeApi());
      await tester.tap(find.byTooltip('Dispositivos IoT (catracas e balanças)').first);
      await tester.pumpAndSettle();
      expect(find.text('Dispositivos IoT'), findsOneWidget);
      expect(find.text('Balança da Cozinha'), findsOneWidget);
    });
  });

  group('Configurações → Segurança', () {
    testWidgets('alterar senha confere na tela e manda ao servidor', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'seguranca');

      await digitar(tester, 'senha-atual', 'senha1234');
      await digitar(tester, 'senha-nova', 'novaSenha99');
      await digitar(tester, 'senha-confirmar', 'outraSenha99');
      await tocar(tester, find.byKey(const Key('btn-trocar-senha')));
      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/perfil/senha'), 0);

      await digitar(tester, 'senha-confirmar', 'novaSenha99');
      await tocar(tester, find.byKey(const Key('btn-trocar-senha')));
      expect(corpoDe(log, 'POST', '/api/perfil/senha'),
          {'senha_atual': 'senha1234', 'senha_nova': 'novaSenha99', 'senha_confirmar': 'novaSenha99'});
      expect(find.text('Senha atualizada com sucesso!'), findsOneWidget);
    });

    testWidgets('sessões do site: lista e encerra (uma ou todas)', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await abrirConfig(tester, 'seguranca');

      await rolarAte(tester, find.text('Chrome · Windows'));
      expect(find.text('Chrome · Android'), findsOneWidget);
      await tocar(tester, find.text('Encerrar').first);
      await tocar(tester, find.widgetWithText(FilledButton, 'Encerrar'));
      expect(corpoDe(log, 'POST', '/api/sessoes/encerrar'), {'id': 8});
      expect(find.text('Sessão encerrada.'), findsOneWidget);

      await tocar(tester, find.text('Encerrar todas as sessões do site'));
      await tocar(tester, find.widgetWithText(FilledButton, 'Encerrar'));
      expect(corpoDe(log, 'POST', '/api/sessoes/encerrar'), {'todas': true});
    });

    testWidgets('a versão do app aparece na aba Aplicativo', (tester) async {
      await abrirApp(tester, fakeApi());
      await abrirConfig(tester, 'aplicativo');
      expect(tester.widget<Text>(find.byKey(const Key('versao-app'))).data, contains('versão $kVersaoApp'));
      expect(find.text('Sair da conta'), findsOneWidget);
    });
  });

  group('sino de notificações', () {
    testWidgets('mostra os alertas do servidor e leva para a tela do assunto', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));

      await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
      await tester.pumpAndSettle();
      expect(pedidos(log, 'GET', '/api/notificacoes'), 1);
      expect(find.text('Acessos negados hoje'), findsOneWidget);

      await tester.tap(find.text('Acessos negados hoje'));
      await tester.pumpAndSettle();
      expect(find.text('Total de Registros'), findsOneWidget); // foi para Relatórios
    });

    testWidgets('"Preferências" abre Configurações → Notificações; alerta de dispositivo abre as Integrações', (tester) async {
      await abrirApp(tester, fakeApi());
      await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preferências'));
      await tester.pumpAndSettle();
      expect(find.text('Tentativas de acesso não autorizado'), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.notifications_none_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dispositivo sem sinal').first);
      await tester.pumpAndSettle();
      expect(find.text('Dispositivos IoT'), findsOneWidget);
    });
  });

  group('tempo real na tela', () {
    testWidgets('quando algo muda, a aba aberta se atualiza sozinha e o acesso novo vira um aviso', (tester) async {
      final log = <http.Request>[];
      var mudou = false;
      await abrirApp(tester, fakeApi(log: log, overrides: {
        'GET /api/aovivo': (req) {
          final base = fixtureJson('aovivo');
          if (!mudou || !req.url.queryParameters.containsKey('ultimo')) {
            return jsonResposta(base
              ..['assinatura'] = 'antes'
              ..['ultimoLog'] = 9355
              ..['eventos'] = []
              ..['novosAcessos'] = 0);
          }
          return jsonResposta(base); // assinatura nova + "Entrada · Maria Santos · 22:12"
        },
      }));
      final antes = pedidos(log, 'GET', '/api/painel');

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(pedidos(log, 'GET', '/api/painel'), antes); // nada mudou: nada recarrega

      mudou = true;
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Entrada · Maria Santos · 22:12'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(pedidos(log, 'GET', '/api/painel'), antes + 1);
      expect(pedidos(log, 'GET', '/api/notificacoes'), greaterThan(0));
    });

    testWidgets('no chat do Assistente o aviso de acesso não aparece (ficaria em cima do campo de escrever)', (tester) async {
      var mudou = false;
      await abrirApp(tester, fakeApi(overrides: {
        'GET /api/aovivo': (req) {
          final base = fixtureJson('aovivo');
          if (!mudou || !req.url.queryParameters.containsKey('ultimo')) {
            return jsonResposta(base
              ..['assinatura'] = 'antes'
              ..['eventos'] = []
              ..['novosAcessos'] = 0);
          }
          return jsonResposta(base);
        },
      }));
      await tester.tap(find.text('IA'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      mudou = true;
      await tester.pump(const Duration(seconds: 9));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Entrada · Maria Santos · 22:12'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('com o app em segundo plano não consulta; ao voltar, consulta na hora', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final antes = pedidos(log, 'GET', '/api/aovivo');
      await tester.pump(const Duration(seconds: 30));
      expect(pedidos(log, 'GET', '/api/aovivo'), antes);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(pedidos(log, 'GET', '/api/aovivo'), antes + 1);

      // janela sem foco no PC ("inactive"): o app continua à vista, então segue atualizando
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(pedidos(log, 'GET', '/api/aovivo'), antes + 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    });
  });

  group('importar planilha (Pessoas → Cadastro)', () {
    testWidgets('escolhe o CSV, importa e mostra o resultado com as linhas ignoradas', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await tester.tap(find.text('Pessoas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aba-pessoas-1')));
      await tester.pumpAndSettle();
      final listasAntes = pedidos(log, 'GET', '/api/pessoas/cadastro');

      escolherArquivo = ({required bool imagem}) async =>
          (nome: 'pessoas.csv', bytes: Uint8List.fromList(latin1.encode('nome;cargo\nJosé Araújo;Operário\n')));
      await tocar(tester, find.byKey(const Key('btn-importar-planilha')));
      expect(find.text('Importar planilha'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('btn-importar')), matching: find.byType(FilledButton))).onPressed,
          isNull); // sem arquivo ainda

      await tocar(tester, find.byKey(const Key('btn-escolher-planilha')));
      expect(find.textContaining('pessoas.csv'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('btn-importar')));

      expect(corpoDe(log, 'POST', '/api/pessoas/importar')['csv'], 'nome;cargo\nJosé Araújo;Operário\n');
      expect(find.text('2 pessoas cadastradas e 1 cartão vinculado. 1 linha ignorada.'), findsOneWidget);
      expect(find.text('Linha 4: nome em branco'), findsOneWidget);
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), listasAntes + 1); // a lista se atualiza

      await tocar(tester, find.byKey(const Key('btn-concluir-importacao')));
      expect(find.text('Importar planilha'), findsNothing);
    });

    testWidgets('planilha do Excel (.xlsx) é recusada com a explicação de como salvar em CSV', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await tester.tap(find.text('Pessoas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aba-pessoas-1')));
      await tester.pumpAndSettle();

      escolherArquivo = ({required bool imagem}) async => (nome: 'Pessoas.XLSX', bytes: Uint8List(10));
      await tocar(tester, find.byKey(const Key('btn-importar-planilha')));
      await tocar(tester, find.byKey(const Key('btn-escolher-planilha')));
      expect(find.textContaining('Escolha um arquivo .csv'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/pessoas/importar'), 0);
      expect(extensaoDePlanilha('lista.CSV'), isTrue);
      expect(extensaoDePlanilha('lista.txt'), isTrue);
    });

    testWidgets('arquivo grande demais é barrado antes de enviar', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await tester.tap(find.text('Pessoas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aba-pessoas-1')));
      await tester.pumpAndSettle();

      escolherArquivo = ({required bool imagem}) async => (nome: 'enorme.csv', bytes: Uint8List(1024 * 1024 + 1));
      await tocar(tester, find.byKey(const Key('btn-importar-planilha')));
      await tocar(tester, find.byKey(const Key('btn-escolher-planilha')));
      expect(find.text('O arquivo passa de 1 MB. Divida a planilha em partes menores.'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/pessoas/importar'), 0);
    });
  });

  group('chat do assistente e a barra de navegação do Android', () {
    // Celular com a tela inteira (Android 15+): barra de status de 24 dp e barra de navegação de 3 botões de 48 dp.
    const dpr = 2.625;
    const barraSistema = 48.0;

    Future<void> abrirChat(WidgetTester tester, Size tela) async {
      tester.view.viewPadding = const FakeViewPadding(top: 24 * dpr, bottom: barraSistema * dpr);
      tester.view.padding = const FakeViewPadding(top: 24 * dpr, bottom: barraSistema * dpr);
      await abrirApp(tester, fakeApi(), tela: tela, dpr: dpr);
      if (tela.width > tela.height) {
        // deitado, o menu lateral (fixo) é mais alto que a tela: rola até o item
        await tester.scrollUntilVisible(find.text('Assistente IA'), 60, scrollable: find.byType(Scrollable).first);
      }
      await tester.tap(find.text(tela.width > tela.height ? 'Assistente IA' : 'IA').last);
      await tester.pumpAndSettle();
    }

    testWidgets('celular em pé, sem teclado: o campo fica acima da barra de abas e da barra do sistema', (tester) async {
      await abrirChat(tester, const Size(1080, 2400));
      final altura = 2400 / dpr;
      final campo = tester.getRect(find.byKey(const Key('campo-pergunta')));
      final abas = tester.getRect(find.byType(NavigationBar));
      expect(campo.bottom, lessThanOrEqualTo(abas.top));
      expect(campo.bottom, lessThan(altura - barraSistema));
    });

    testWidgets('com o teclado aberto: a barra de abas sai e o campo fica logo acima do teclado', (tester) async {
      await abrirChat(tester, const Size(1080, 2400));
      const teclado = 320.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: (teclado + barraSistema) * dpr);
      tester.view.padding = const FakeViewPadding(top: 24 * dpr);
      await tester.pumpAndSettle();

      final altura = 2400 / dpr;
      final topoTeclado = altura - teclado - barraSistema;
      final campo = tester.getRect(find.byKey(const Key('campo-pergunta')));
      expect(find.byType(NavigationBar), findsNothing);
      expect(campo.bottom, lessThanOrEqualTo(topoTeclado));
      expect(campo.bottom, greaterThan(topoTeclado - 40)); // logo acima, sem buraco
    });

    testWidgets('celular deitado (layout largo, sem barra de abas): o campo não fica embaixo da barra do sistema', (tester) async {
      await abrirChat(tester, const Size(2400, 1080));
      final altura = 1080 / dpr;
      final campo = tester.getRect(find.byKey(const Key('campo-pergunta')));
      expect(find.byType(NavigationBar), findsNothing);
      expect(campo.bottom, lessThanOrEqualTo(altura - barraSistema));
    });
  });

  group('relatórios', () {
    testWidgets('exportar usa o mesmo período que está na tela (que pode vir do período padrão da conta)', (tester) async {
      final log = <http.Request>[];
      await abrirApp(tester, fakeApi(log: log));
      await tester.tap(find.text('Relatórios').last);
      await tester.pumpAndSettle();
      final f = fixtureJson('relatorios')['filtros'] as Map<String, dynamic>;

      await tester.tap(find.byTooltip('Exportar CSV'));
      await tester.pumpAndSettle();
      final q = log.lastWhere((r) => r.url.path == '/api/relatorios/exportar').url.queryParameters;
      expect(q['de'], f['de']);
      expect(q['ate'], f['ate']);
    });
  });
}
