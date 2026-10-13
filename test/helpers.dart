import 'dart:convert';
import 'dart:io';

import 'package:fluxe_app/core/app_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) => jsonDecode(fixture(name)) as Map<String, dynamic>;

http.Response jsonResposta(Object corpo, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(corpo)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// Servidor falso: responde com os JSONs reais capturados da API do SystemFluxe.
///
/// [overrides] troca a resposta de uma rota específica, pela chave "MÉTODO /caminho"
/// (ex.: `'POST /api/pessoas/criar': (req) => jsonResposta({...}, 409)`).
MockClient fakeApi({
  List<http.Request>? log,
  Map<String, http.Response Function(http.Request req)> overrides = const {},
}) =>
    MockClient((req) async {
      log?.add(req);
      http.Response ok(String name) => http.Response.bytes(utf8.encode(fixture(name)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});

      final trocada = overrides['${req.method} ${req.url.path}'];
      if (trocada != null) return trocada(req);

      // Corpo JSON das escritas do cadastro (as mensagens abaixo são as que o servidor responde).
      Map<String, dynamic> corpo() => jsonDecode(req.body) as Map<String, dynamic>;

      switch (req.url.path) {
        case '/api/pessoas/cadastro':
          return ok('pessoas_cadastro');
        case '/api/pessoas/leituras':
          return ok('pessoas_leituras');
        case '/api/pessoas/criar':
          return jsonResposta({'sucesso': true, 'mensagem': 'Pessoa cadastrada.', 'id': 99});
        case '/api/pessoas/editar':
          return jsonResposta({'sucesso': true, 'mensagem': 'Dados atualizados.'});
        case '/api/pessoas/ativo':
          return jsonResposta({'sucesso': true, 'mensagem': corpo()['ativo'] == true ? 'Pessoa reativada.' : 'Pessoa desativada.'});
        case '/api/pessoas/cartao':
          return jsonResposta({'sucesso': true, 'mensagem': 'Cartão vinculado.'});
        case '/api/pessoas/cartao/ativo':
          return jsonResposta({'sucesso': true, 'mensagem': corpo()['ativo'] == true ? 'Cartão ativado.' : 'Cartão desativado.'});
        case '/api/pessoas/cartao/remover':
          return jsonResposta({'sucesso': true, 'mensagem': 'Cartão removido.'});
        case '/api/login':
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['senha'] != 'senha1234') {
            return http.Response(
                jsonEncode({'sucesso': false, 'mensagem': 'E-mail ou senha inválidos.'}), 401,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return ok('login');
        case '/api/me':
          return ok('me');
        case '/api/painel':
          return ok('painel');
        case '/api/analise-mensal':
          return ok('analise');
        case '/api/pessoas':
          return ok('pessoas');
        case '/api/relatorios':
          return ok('relatorios');
        case '/api/relatorios/exportar':
          return http.Response('Nome;Função\n', 200);
        case '/api/assistente':
          return ok(req.method == 'POST' ? 'assistente_post' : 'assistente');
      }
      return http.Response(jsonEncode({'sucesso': false, 'mensagem': 'Rota não encontrada.'}), 404);
    });

Future<AppController> newController({MockClient? client, bool loggedIn = false}) async {
  SharedPreferences.setMockInitialValues({});
  final tokens = MemoryTokenStore();
  if (loggedIn) {
    await tokens.write('fake-token-for-tests');
    SharedPreferences.setMockInitialValues({
      'usuario': jsonEncode(fixtureJson('me')['usuario']),
    });
  }
  final c = AppController(
    prefs: await SharedPreferences.getInstance(),
    tokenStore: tokens,
    httpClient: client ?? fakeApi(),
  );
  await c.init();
  return c;
}
