import 'dart:convert';

import 'package:fluxe_app/core/api_client.dart';
import 'package:fluxe_app/core/cadastro_service.dart';
import 'package:fluxe_app/main.dart';
import 'package:fluxe_app/models/models.dart';
import 'package:fluxe_app/screens/cadastro_formularios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

// Cadastro de pessoas e cartões pelo app. Os JSONs de test/fixtures/pessoas_cadastro.json e pessoas_leituras.json
// são respostas reais do SystemFluxe: Ana (presente), Bruno (2 cartões, um desativado), Camila (sem cartão),
// Eduardo, Fernanda, Gustavo e Diego (desativado); cartões lidos nas catracas: F00DBA5E e 0DDC0FFE.

/// Corpo JSON (decodificado) do último pedido que bateu com método e caminho.
Map<String, dynamic> corpoDe(List<http.Request> log, String metodo, String caminho) =>
    jsonDecode(log.lastWhere((r) => r.method == metodo && r.url.path == caminho).body) as Map<String, dynamic>;

int pedidos(List<http.Request> log, String metodo, String caminho) =>
    log.where((r) => r.method == metodo && r.url.path == caminho).length;

/// Abre o app logado, vai em Pessoas → Cadastro (celular).
Future<void> abrirCadastro(WidgetTester tester, MockClient client, {Size tela = const Size(1080, 2340)}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = await newController(client: client, loggedIn: true);
  await tester.pumpWidget(SicapdaApp(controller: c));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pessoas').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('aba-pessoas-1')));
  await tester.pumpAndSettle();
}

/// Mesma resposta do servidor, mas com o usuário sem permissão de alterar (não é o administrador).
http.Response cadastroSomenteLeitura(http.Request _) {
  final j = fixtureJson('pessoas_cadastro')..['podeEditar'] = false;
  return jsonResposta(j);
}

Future<void> digitar(WidgetTester tester, String chave, String texto) async {
  await tester.ensureVisible(find.byKey(Key(chave)));
  await tester.enterText(find.byKey(Key(chave)), texto);
  await tester.pump();
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('UID do cartão', () {
    test('normaliza como o servidor: maiúsculas, sem espaços nem ":"', () {
      expect(normalizarUid('a1:b2 c3'), 'A1B2C3');
      expect(normalizarUid('  f0:0d\tba5e\n'), 'F00DBA5E');
      expect(normalizarUid(''), '');
    });

    test('valida o formato (4 a 100 letras, números, hífen ou sublinhado)', () {
      expect(uidValido('A1B2'), isTrue);
      expect(uidValido('CARTAO_TESTE-01'), isTrue);
      expect(uidValido('AB'), isFalse); // curto demais
      expect(uidValido('AB#\$%CD'), isFalse); // símbolos
      expect(uidValido('A' * 100), isTrue);
      expect(uidValido('A' * 101), isFalse);
      expect(uidValido('ÁÉÍÓ'), isFalse); // só ASCII, como no servidor
    });

    test('o campo do formulário aplica a normalização enquanto digita e mantém o cursor', () {
      const f = UidFormatter();
      final r = f.formatEditUpdate(
        const TextEditingValue(text: 'A1'),
        const TextEditingValue(text: 'a1:b2 c3', selection: TextSelection.collapsed(offset: 5)), // cursor depois de "a1:b2"
      );
      expect(r.text, 'A1B2C3');
      expect(r.selection.baseOffset, 4); // depois de "A1B2"
    });
  });

  group('modelos (JSON real da API)', () {
    test('cadastro: contagens, permissão, categorias e cartões', () {
      final d = CadastroData.fromJson(fixtureJson('pessoas_cadastro'));
      expect(d.podeEditar, isTrue);
      expect(d.total, 7);
      expect(d.ativas, 6);
      expect(d.semCartaoAtivo, 1);
      expect(d.categorias.map((c) => c.valor), ['operador', 'supervisor', 'prestador']);
      expect(d.categorias.last.rotulo, 'Prestador de Serviço');

      final bruno = d.pessoas.firstWhere((p) => p.nome == 'Bruno Henrique Lima');
      expect(bruno.cartoes.map((c) => (c.uid, c.ativo)), [('E5F6A7B8', true), ('9C0D1E2F', false)]);
      expect(bruno.temCartaoAtivo, isTrue);
      expect(bruno.matricula, '1002');

      final ana = d.pessoas.firstWhere((p) => p.nome == 'Ana Beatriz Santos');
      expect(ana.presente, isTrue);
      final camila = d.pessoas.firstWhere((p) => p.nome == 'Camila Ferreira');
      expect(camila.cartoes, isEmpty);
      expect(camila.temCartaoAtivo, isFalse);
      final fernanda = d.pessoas.firstWhere((p) => p.nome == 'Fernanda Costa');
      expect(fernanda.matricula, isNull);
      final diego = d.pessoas.firstWhere((p) => p.nome == 'Diego Martins');
      expect(diego.ativo, isFalse);
    });

    test('a busca enxerga nome, função, matrícula e UID do cartão', () {
      final d = CadastroData.fromJson(fixtureJson('pessoas_cadastro'));
      List<String> acha(String t) => d.pessoas.where((p) => p.textoBusca.contains(t)).map((p) => p.nome).toList();
      expect(acha('ana beatriz'), ['Ana Beatriz Santos']);
      expect(acha('qualidade'), ['Fernanda Costa']);
      expect(acha('2001'), ['Eduardo Pires']);
      expect(acha('e5f6'), ['Bruno Henrique Lima']);
    });

    test('tolera resposta incompleta (servidor antigo ou campos ausentes)', () {
      final d = CadastroData.fromJson({'sucesso': true});
      expect(d.podeEditar, isFalse);
      expect(d.pessoas, isEmpty);
      expect(d.categorias, hasLength(3)); // cai nas categorias padrão
      final p = PessoaCadastro.fromJson({'id': 1, 'nome': 'X', 'matricula': '  '});
      expect(p.matricula, isNull);
      expect(p.categoria, 'operador');
    });

    test('cartões lidos nas catracas', () {
      final l = (fixtureJson('pessoas_leituras')['leituras'] as List).cast<Map<String, dynamic>>().map(LeituraCartao.fromJson).toList();
      expect(l.map((e) => e.uid), ['F00DBA5E', '0DDC0FFE']);
      expect(l.first.leituras, 3);
      expect(l.first.dispositivo, 'Catraca Portaria');
    });
  });

  group('CadastroService (o que vai pela rede)', () {
    late List<http.Request> log;
    late CadastroService servico;

    setUp(() {
      log = [];
      servico = CadastroService(ApiClient(baseUrl: 'https://x.test', token: 'abc', client: fakeApi(log: log)));
    });

    test('criar pessoa com cartão manda tudo num pedido só, com o Bearer token', () async {
      final msg = await servico.criarPessoa(nome: 'Hélio Prado', cargo: 'Cozinheiro', categoria: 'prestador', matricula: '77', uid: 'F00DBA5E');
      expect(msg, 'Pessoa cadastrada.');
      final req = log.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'https://x.test/api/pessoas/criar');
      expect(req.headers['Authorization'], 'Bearer abc');
      expect(jsonDecode(req.body), {'nome': 'Hélio Prado', 'cargo': 'Cozinheiro', 'categoria': 'prestador', 'matricula': '77', 'uid': 'F00DBA5E'});
    });

    test('criar sem cartão não manda o campo uid', () async {
      await servico.criarPessoa(nome: 'Hélio', cargo: 'X', categoria: 'operador');
      expect(corpoDe(log, 'POST', '/api/pessoas/criar').containsKey('uid'), isFalse);
    });

    test('editar, ativar, vincular, ativar cartão e remover cartão usam as rotas e os campos do servidor', () async {
      await servico.editarPessoa(5, nome: 'N', cargo: 'C', categoria: 'supervisor', matricula: '');
      expect(corpoDe(log, 'POST', '/api/pessoas/editar'), {'id': 5, 'nome': 'N', 'cargo': 'C', 'categoria': 'supervisor', 'matricula': ''});

      expect(await servico.definirPessoaAtiva(5, false), 'Pessoa desativada.');
      expect(corpoDe(log, 'POST', '/api/pessoas/ativo'), {'id': 5, 'ativo': false}); // booleano de verdade, não "0"
      expect(await servico.definirPessoaAtiva(5, true), 'Pessoa reativada.');

      expect(await servico.vincularCartao(3, 'F00DBA5E'), 'Cartão vinculado.');
      expect(corpoDe(log, 'POST', '/api/pessoas/cartao'), {'funcionario_id': 3, 'uid': 'F00DBA5E'});

      expect(await servico.definirCartaoAtivo(9, false), 'Cartão desativado.');
      expect(corpoDe(log, 'POST', '/api/pessoas/cartao/ativo'), {'id': 9, 'ativo': false});

      expect(await servico.removerCartao(9), 'Cartão removido.');
      expect(corpoDe(log, 'POST', '/api/pessoas/cartao/remover'), {'id': 9});
    });

    test('erro de regra do servidor vira ApiException com a mensagem e o código', () async {
      final api = ApiClient(
        baseUrl: 'https://x.test',
        client: fakeApi(overrides: {
          'POST /api/pessoas/cartao': (_) => jsonResposta(
              {'sucesso': false, 'mensagem': 'Este cartão já está vinculado a Maria. Remova-o dessa pessoa antes de usar de novo.'}, 409),
        }),
      );
      await expectLater(
        CadastroService(api).vincularCartao(3, 'AAAA1111'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.message, 'message', startsWith('Este cartão já está vinculado a Maria'))),
      );
    });

    test('lista os cartões lidos nas catracas', () async {
      final l = await servico.leituras();
      expect(l, hasLength(2));
      expect(log.single.url.path, '/api/pessoas/leituras');
    });
  });

  group('aba Cadastro (tela)', () {
    testWidgets('mostra o resumo, as pessoas, os cartões e os avisos de cada uma', (tester) async {
      await abrirCadastro(tester, fakeApi());

      expect(find.text('Cadastro de pessoas e cartões'), findsOneWidget); // subtítulo da tela
      expect(find.textContaining('pessoas ativas', findRichText: true), findsOneWidget);
      expect(find.textContaining('6', findRichText: true), findsWidgets);
      expect(find.textContaining('sem cartão ativo', findRichText: true), findsOneWidget);

      expect(find.text('Ana Beatriz Santos'), findsOneWidget);
      expect(find.text('Presente agora'), findsOneWidget); // só a Ana
      expect(find.text('A1B2C3D4'), findsOneWidget);
      expect(find.text('Operadora de Produção · Operador · Matrícula 1001'), findsOneWidget);
      expect(find.byKey(const Key('btn-adicionar-pessoa')), findsOneWidget);
      expect(find.byKey(const Key('aviso-somente-leitura')), findsNothing);
      expect(find.text('Vincular cartão'), findsWidgets);

      // Bruno tem um cartão desativado (marcado) e Camila não tem cartão. A lista é preguiçosa: confere o topo
      // antes de rolar até o Diego, que está desativado (e é o último, pois desativados vêm por último).
      expect(find.text('desativado'), findsOneWidget);
      expect(find.text('Sem cartão'), findsOneWidget);
      expect(find.text('Desativada'), findsNothing);

      await tester.scrollUntilVisible(find.text('Diego Martins'), 500, scrollable: find.byType(Scrollable).last);
      expect(find.text('Desativada'), findsOneWidget);
    });

    testWidgets('a busca filtra por UID do cartão e mostra aviso quando não acha ninguém', (tester) async {
      await abrirCadastro(tester, fakeApi());

      await tester.enterText(find.byType(TextField).first, '7e8f');
      await tester.pumpAndSettle();
      expect(find.text('Eduardo Pires'), findsOneWidget);
      expect(find.text('Ana Beatriz Santos'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzzz-ninguem');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma pessoa encontrada'), findsOneWidget);
    });

    testWidgets('quem não é administrador só consulta: sem botões de alterar e com o aviso', (tester) async {
      await abrirCadastro(tester, fakeApi(overrides: {'GET /api/pessoas/cadastro': cadastroSomenteLeitura}));

      expect(find.text('Ana Beatriz Santos'), findsOneWidget);
      expect(find.text('A1B2C3D4'), findsOneWidget); // vê os cartões
      expect(find.byKey(const Key('btn-adicionar-pessoa')), findsNothing);
      expect(find.text('Vincular cartão'), findsNothing);
      expect(find.byTooltip('Mais ações'), findsNothing);
      expect(find.byKey(const Key('aviso-somente-leitura')), findsOneWidget);

      // tocar no cartão não abre nada
      await tester.tap(find.text('A1B2C3D4'));
      await tester.pumpAndSettle();
      expect(find.text('Remover cartão'), findsNothing);
    });

    testWidgets('servidor sem as rotas novas (404) explica o que fazer em vez de mostrar erro técnico', (tester) async {
      await abrirCadastro(tester, fakeApi(overrides: {
        'GET /api/pessoas/cadastro': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Rota não encontrada.'}, 404),
      }));
      expect(find.textContaining('Atualize o SystemFluxe'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('a aba "Presentes agora" continua sendo a primeira e o Cadastro só consulta o servidor quando aberto', (tester) async {
      final log = <http.Request>[];
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(log: log), loggedIn: true);
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pessoas').last);
      await tester.pumpAndSettle();

      expect(find.text('Total Presente'), findsOneWidget);
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 0);

      await tester.tap(find.byKey(const Key('aba-pessoas-1')));
      await tester.pumpAndSettle();
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 1);
      expect(find.text('Total Presente'), findsNothing); // aba escondida

      await tester.tap(find.byKey(const Key('aba-pessoas-0')));
      await tester.pumpAndSettle();
      expect(find.text('Total Presente'), findsOneWidget);
    });
  });

  group('adicionar pessoa', () {
    testWidgets('com cartão escolhido na lista das catracas: manda tudo num pedido, avisa e atualiza a lista', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 1);

      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      expect(find.text('Adicionar pessoa'), findsWidgets);

      await digitar(tester, 'campo-nome', '  Hélio   Prado ');
      await digitar(tester, 'campo-cargo', 'Técnico de Qualidade');
      await tocar(tester, find.byKey(const Key('categoria-supervisor')));
      await digitar(tester, 'campo-matricula', '3001');

      // o cartão que acabou de passar na catraca aparece na lista; tocar nele preenche o campo
      expect(find.byKey(const Key('leitura-F00DBA5E')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('leitura-F00DBA5E')));
      expect(tester.widget<TextFormField>(find.byKey(const Key('campo-uid'))).controller!.text, 'F00DBA5E');

      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));

      expect(corpoDe(log, 'POST', '/api/pessoas/criar'), {
        'nome': 'Hélio Prado', // espaços repetidos e das pontas saem
        'cargo': 'Técnico de Qualidade',
        'categoria': 'supervisor',
        'matricula': '3001',
        'uid': 'F00DBA5E',
      });
      expect(find.text('Pessoa cadastrada.'), findsOneWidget); // aviso com a mensagem do servidor
      expect(find.byKey(const Key('btn-salvar-pessoa')), findsNothing); // a folha fechou
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 2); // lista atualizada
    });

    testWidgets('sem cartão: o UID é opcional e o campo "uid" nem vai no pedido', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();

      await digitar(tester, 'campo-nome', 'Iara Mota');
      await digitar(tester, 'campo-cargo', 'Operadora');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));

      final corpo = corpoDe(log, 'POST', '/api/pessoas/criar');
      expect(corpo['categoria'], 'operador'); // a primeira categoria é a padrão
      expect(corpo.containsKey('uid'), isFalse);
      expect(find.byKey(const Key('btn-salvar-pessoa')), findsNothing); // a folha fechou
    });

    testWidgets('toque duplo em Salvar não cadastra a pessoa duas vezes', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      await digitar(tester, 'campo-nome', 'Iara Mota');
      await digitar(tester, 'campo-cargo', 'Operadora');

      final salvar = find.byKey(const Key('btn-salvar-pessoa'));
      await tester.tap(salvar);
      await tester.tap(salvar, warnIfMissed: false); // segundo toque antes de o servidor responder
      await tester.pumpAndSettle();

      expect(pedidos(log, 'POST', '/api/pessoas/criar'), 1);
    });

    testWidgets('digitar o UID em minúsculas e com ":" funciona: vai normalizado', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();

      await digitar(tester, 'campo-nome', 'Iara Mota');
      await digitar(tester, 'campo-cargo', 'Operadora');
      await digitar(tester, 'campo-uid', 'ab:cd 12:34');
      expect(tester.widget<TextFormField>(find.byKey(const Key('campo-uid'))).controller!.text, 'ABCD1234');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));

      expect(corpoDe(log, 'POST', '/api/pessoas/criar')['uid'], 'ABCD1234');
    });

    testWidgets('campos obrigatórios e UID inválido são barrados na tela, sem chamar o servidor', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();

      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));
      expect(find.text('Informe o nome.'), findsOneWidget);
      expect(find.text('Informe o cargo ou a função.'), findsOneWidget);

      await digitar(tester, 'campo-nome', 'Iara');
      await digitar(tester, 'campo-cargo', 'Operadora');
      await digitar(tester, 'campo-uid', 'ab');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));
      expect(find.textContaining('Cartão inválido'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/pessoas/criar'), 0);
    });

    testWidgets('erro do servidor (cartão já em uso) aparece na folha, que continua aberta, sem atualizar a lista', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log, overrides: {
        'POST /api/pessoas/criar': (_) => jsonResposta(
            {'sucesso': false, 'mensagem': 'Este cartão já está vinculado a Ana Beatriz Santos. Remova-o dessa pessoa antes de usar de novo.'}, 409),
      }));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();

      await digitar(tester, 'campo-nome', 'Iara');
      await digitar(tester, 'campo-cargo', 'Operadora');
      await digitar(tester, 'campo-uid', 'A1B2C3D4');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));

      expect(find.byKey(const Key('erro-formulario')), findsOneWidget);
      expect(find.textContaining('já está vinculado a Ana Beatriz Santos'), findsOneWidget);
      expect(find.byKey(const Key('btn-salvar-pessoa')), findsOneWidget); // ainda aberta, dá para corrigir
      expect(tester.widget<FilledButton>(find.byKey(const Key('btn-salvar-pessoa'))).onPressed, isNotNull); // botão voltou
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 1);
      // o que foi digitado continua lá
      expect(tester.widget<TextFormField>(find.byKey(const Key('campo-nome'))).controller!.text, 'Iara');
    });

    testWidgets('sem conexão: mostra o motivo na folha em vez de travar', (tester) async {
      await abrirCadastro(tester, fakeApi(overrides: {
        'POST /api/pessoas/criar': (_) => throw http.ClientException("Failed host lookup: 'x.test'"),
      }));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      await digitar(tester, 'campo-nome', 'Iara');
      await digitar(tester, 'campo-cargo', 'Operadora');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));

      expect(find.textContaining('Não foi possível conectar ao servidor'), findsOneWidget);
      expect(find.byKey(const Key('btn-salvar-pessoa')), findsOneWidget);
    });
  });

  group('cartões lidos nas catracas (atualizam sozinhos)', () {
    testWidgets('um cartão que passa na catraca com o formulário aberto aparece destacado como "novo"', (tester) async {
      var consultas = 0;
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log, overrides: {
        'GET /api/pessoas/leituras': (_) {
          consultas++;
          final leituras = (fixtureJson('pessoas_leituras')['leituras'] as List).cast<Map<String, dynamic>>();
          // A partir da 2ª consulta, mais um cartão passou na catraca.
          final lista = consultas < 2
              ? leituras
              : [
                  {'uid': 'BEEF0001', 'leituras': 1, 'dispositivo': 'Catraca Portaria', 'quando': 'agora', 'instante': '2026-10-13 12:40:00'},
                  ...leituras,
                ];
          return jsonResposta({'sucesso': true, 'mensagem': 'ok', 'leituras': lista});
        },
      }));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('leitura-F00DBA5E')), findsOneWidget);
      expect(find.byKey(const Key('leitura-BEEF0001')), findsNothing);
      expect(find.text('novo'), findsNothing); // o que já existia ao abrir não é "novo"
      expect(find.text('· atualiza sozinha'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3)); // próxima consulta
      await tester.pump();
      expect(find.byKey(const Key('leitura-BEEF0001')), findsOneWidget);
      expect(find.text('novo'), findsOneWidget);
    });

    testWidgets('lista vazia explica o que fazer; falha de rede avisa e não atrapalha digitar o UID', (tester) async {
      await abrirCadastro(tester, fakeApi(overrides: {
        'GET /api/pessoas/leituras': (_) => jsonResposta({'sucesso': true, 'mensagem': 'ok', 'leituras': []}),
      }));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('leituras-vazio')), findsOneWidget);
      expect(find.textContaining('Nenhum cartão novo lido ainda'), findsOneWidget);
    });

    testWidgets('sem conexão com o servidor: o status diz "sem conexão" e o campo do UID segue funcionando', (tester) async {
      await abrirCadastro(tester, fakeApi(overrides: {
        'GET /api/pessoas/leituras': (_) => throw http.ClientException('sem rede'),
      }));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      expect(find.text('· sem conexão'), findsOneWidget);
      await digitar(tester, 'campo-uid', 'abcd');
      expect(tester.widget<TextFormField>(find.byKey(const Key('campo-uid'))).controller!.text, 'ABCD');
    });

    testWidgets('com o app em segundo plano a consulta pausa; ao voltar retoma (janela sem foco no PC não pausa)', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      int consultas() => pedidos(log, 'GET', '/api/pessoas/leituras');

      var antes = consultas();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); // janela sem foco
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(consultas(), greaterThan(antes), reason: 'inactive não deve parar a lista');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      antes = consultas();
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(consultas(), antes, reason: 'em segundo plano não consulta');

      // Volta pela mesma escada que o sistema usa (paused → hidden → inactive → resumed).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(consultas(), greaterThan(antes), reason: 'ao voltar, consulta na hora (sem esperar o próximo ciclo de 3 s)');
    });

    testWidgets('a consulta para quando a folha fecha (não fica pedindo ao servidor em segundo plano)', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      final antes = pedidos(log, 'GET', '/api/pessoas/leituras');
      expect(antes, greaterThanOrEqualTo(1));

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(pedidos(log, 'GET', '/api/pessoas/leituras'), antes);
    });
  });

  group('vincular cartão a quem já existe', () {
    testWidgets('escolhe o cartão lido na catraca, vincula e atualiza a lista', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));

      await tocar(tester, find.byKey(const Key('btn-vincular-3'))); // Camila, que está sem cartão
      expect(find.text('Vincular cartão'), findsWidgets);
      expect(find.text('Camila Ferreira'), findsWidgets);

      await tocar(tester, find.byKey(const Key('leitura-0DDC0FFE')));
      await tocar(tester, find.byKey(const Key('btn-confirmar-vinculo')));

      expect(corpoDe(log, 'POST', '/api/pessoas/cartao'), {'funcionario_id': 3, 'uid': '0DDC0FFE'});
      expect(find.text('Cartão vinculado.'), findsOneWidget);
      expect(find.byKey(const Key('btn-confirmar-vinculo')), findsNothing); // a folha fechou
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 2);
    });

    testWidgets('sem escolher nem digitar o cartão, pede o UID antes de enviar', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tocar(tester, find.byKey(const Key('btn-vincular-3')));
      await tocar(tester, find.byKey(const Key('btn-confirmar-vinculo')));

      expect(find.text('Escolha um cartão acima ou digite o UID.'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/pessoas/cartao'), 0);
    });

    testWidgets('cartão que já tem dono: o servidor recusa e o motivo aparece na folha', (tester) async {
      await abrirCadastro(tester, fakeApi(overrides: {
        'POST /api/pessoas/cartao': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Este cartão já está em uso por outra empresa.'}, 409),
      }));
      await tocar(tester, find.byKey(const Key('btn-vincular-3')));
      await digitar(tester, 'campo-uid', 'OUTRA999');
      await tocar(tester, find.byKey(const Key('btn-confirmar-vinculo')));

      expect(find.text('Este cartão já está em uso por outra empresa.'), findsOneWidget);
      expect(find.byKey(const Key('btn-confirmar-vinculo')), findsOneWidget);
    });
  });

  group('editar, ativar e desativar', () {
    testWidgets('editar abre com os dados atuais (sem a parte do cartão) e salva', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));

      await tester.tap(find.byKey(const Key('menu-pessoa-2'))); // Bruno
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar pessoa'), findsOneWidget);
      expect(find.byKey(const Key('campo-uid')), findsNothing); // os cartões se mexem na lista
      expect(tester.widget<TextFormField>(find.byKey(const Key('campo-nome'))).controller!.text, 'Bruno Henrique Lima');
      expect(tester.widget<TextFormField>(find.byKey(const Key('campo-matricula'))).controller!.text, '1002');

      await digitar(tester, 'campo-cargo', 'Líder de Embalagem');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));

      expect(corpoDe(log, 'POST', '/api/pessoas/editar'), {
        'id': 2,
        'nome': 'Bruno Henrique Lima',
        'cargo': 'Líder de Embalagem',
        'categoria': 'operador',
        'matricula': '1002',
      });
      expect(find.text('Dados atualizados.'), findsOneWidget);
      expect(find.byKey(const Key('btn-salvar-pessoa')), findsNothing); // a folha fechou
    });

    testWidgets('desativar pede confirmação (e dá para desistir)', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));

      await tester.tap(find.byKey(const Key('menu-pessoa-1'))); // Ana
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desativar'));
      await tester.pumpAndSettle();
      expect(find.text('Desativar Ana Beatriz Santos?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(pedidos(log, 'POST', '/api/pessoas/ativo'), 0);

      await tester.tap(find.byKey(const Key('menu-pessoa-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desativar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desativar'));
      await tester.pumpAndSettle();

      expect(corpoDe(log, 'POST', '/api/pessoas/ativo'), {'id': 1, 'ativo': false});
      expect(find.text('Pessoa desativada.'), findsOneWidget);
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 2);
    });

    testWidgets('reativar não pergunta nada', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.scrollUntilVisible(find.byKey(const Key('menu-pessoa-4')), 500, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.byKey(const Key('menu-pessoa-4'))); // existir na lista não é estar à vista
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu-pessoa-4'))); // Diego, desativado
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reativar'));
      await tester.pumpAndSettle();

      expect(corpoDe(log, 'POST', '/api/pessoas/ativo'), {'id': 4, 'ativo': true});
      expect(find.text('Pessoa reativada.'), findsOneWidget);
    });

    testWidgets('recusa do servidor em ação rápida vira aviso, sem atualizar a lista', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log, overrides: {
        'POST /api/pessoas/ativo': (_) => jsonResposta({'sucesso': false, 'mensagem': 'Pessoa não encontrada.'}, 404),
      }));
      await tester.tap(find.byKey(const Key('menu-pessoa-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desativar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desativar'));
      await tester.pumpAndSettle();

      expect(find.text('Pessoa não encontrada.'), findsOneWidget);
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 1);
    });
  });

  group('ações de um cartão', () {
    testWidgets('desativar o cartão', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));

      await tester.tap(find.byKey(const Key('cartao-1'))); // A1B2C3D4, da Ana
      await tester.pumpAndSettle();
      expect(find.text('Cartão A1B2C3D4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('acao-cartao-alternar')));
      await tester.pumpAndSettle();

      expect(corpoDe(log, 'POST', '/api/pessoas/cartao/ativo'), {'id': 1, 'ativo': false});
      expect(find.text('Cartão desativado.'), findsOneWidget);
    });

    testWidgets('ativar um cartão desativado (oferece "Ativar" em vez de "Desativar")', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));

      await tester.tap(find.byKey(const Key('cartao-3'))); // 9C0D1E2F, do Bruno, desativado
      await tester.pumpAndSettle();
      expect(find.text('Ativar cartão'), findsOneWidget);
      await tester.tap(find.byKey(const Key('acao-cartao-alternar')));
      await tester.pumpAndSettle();

      expect(corpoDe(log, 'POST', '/api/pessoas/cartao/ativo'), {'id': 3, 'ativo': true});
    });

    testWidgets('remover pede confirmação e só depois remove', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));

      await tester.tap(find.byKey(const Key('cartao-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-cartao-remover')));
      await tester.pumpAndSettle();
      expect(find.text('Remover o cartão A1B2C3D4?'), findsOneWidget);
      expect(pedidos(log, 'POST', '/api/pessoas/cartao/remover'), 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();
      expect(corpoDe(log, 'POST', '/api/pessoas/cartao/remover'), {'id': 1});
      expect(find.text('Cartão removido.'), findsOneWidget);
      expect(pedidos(log, 'GET', '/api/pessoas/cadastro'), 2);
    });

    testWidgets('desistir na confirmação não remove nada', (tester) async {
      final log = <http.Request>[];
      await abrirCadastro(tester, fakeApi(log: log));
      await tester.tap(find.byKey(const Key('cartao-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('acao-cartao-remover')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(pedidos(log, 'POST', '/api/pessoas/cartao/remover'), 0);
    });
  });

  group('PC e tema escuro', () {
    testWidgets('janela larga (PC): o formulário abre centralizado e o fluxo funciona', (tester) async {
      final log = <http.Request>[];
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(log: log), loggedIn: true);
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pessoas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aba-pessoas-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const Key('btn-salvar-pessoa'))).width, lessThan(300)); // folha de largura limitada

      await digitar(tester, 'campo-nome', 'Iara Mota');
      await digitar(tester, 'campo-cargo', 'Operadora');
      await tocar(tester, find.byKey(const Key('btn-salvar-pessoa')));
      expect(pedidos(log, 'POST', '/api/pessoas/criar'), 1);
    });

    testWidgets('tema escuro: telas e formulário montam sem erros', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = await newController(client: fakeApi(), loggedIn: true);
      await c.setThemeMode(ThemeMode.dark);
      await tester.pumpWidget(SicapdaApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pessoas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aba-pessoas-1')));
      await tester.pumpAndSettle();
      expect(find.text('Ana Beatriz Santos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn-adicionar-pessoa')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campo-nome')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
