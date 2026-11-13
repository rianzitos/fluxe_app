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
          // formato=xlsx: a planilha do Excel (um zip, começa com "PK"); sem formato: o CSV de sempre.
          return req.url.queryParameters['formato'] == 'xlsx'
              ? http.Response.bytes([0x50, 0x4B, 3, 4, 20, 0], 200,
                  headers: {'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'})
              : http.Response.bytes(utf8.encode('\uFEFFNome;Função\n'), 200, headers: {'content-type': 'text/csv; charset=utf-8'});
        case '/api/assistente':
          return ok(req.method == 'POST' ? 'assistente_post' : 'assistente');

        // ─── Configurações, sino, tempo real e planilha (fluxe_app 1.2) ───
        case '/api/perfil':
          final u = Map<String, dynamic>.of(fixtureJson('perfil')['usuario'] as Map<String, dynamic>);
          final c = corpo();
          u.addAll({'nome': c['nome'], 'email': c['email'], 'cargo': c['cargo']});
          return jsonResposta({'sucesso': true, 'mensagem': 'Perfil atualizado com sucesso!', 'usuario': u});
        case '/api/perfil/senha':
          return jsonResposta({'sucesso': true, 'mensagem': 'Senha atualizada com sucesso!'});
        case '/api/perfil/foto':
          final u = Map<String, dynamic>.of(fixtureJson('perfil')['usuario'] as Map<String, dynamic>)
            ..['foto'] = 'http://servidor.test/uploads/perfil/perfil_nova.png';
          return jsonResposta({'sucesso': true, 'mensagem': 'Foto atualizada com sucesso!', 'usuario': u});
        case '/api/preferencias':
          return ok('preferencias');
        case '/api/preferencias/notificacao':
          return jsonResposta({'sucesso': true, 'mensagem': 'Preferência salva.', 'ativo': corpo()['ativo'], 'sino': 2});
        case '/api/preferencias/sistema':
          return jsonResposta({'sucesso': true, 'mensagem': 'Preferências salvas.'});
        case '/api/sessoes':
          return ok('sessoes');
        case '/api/sessoes/encerrar':
          return jsonResposta({'sucesso': true, 'mensagem': corpo()['todas'] == true ? '2 sessões encerradas.' : 'Sessão encerrada.'});
        case '/api/notificacoes':
          return ok('notificacoes');
        case '/api/aovivo':
          // Sem mudança nenhuma: a mesma assinatura e nenhum acesso novo (os testes do tempo real trocam esta rota).
          final estado = fixtureJson('aovivo')
            ..['eventos'] = []
            ..['novosAcessos'] = 0;
          return jsonResposta(estado);
        case '/api/dispositivos':
          return ok('dispositivos');
        case '/api/dispositivos/criar':
          final c = corpo();
          return jsonResposta({
            'sucesso': true,
            'mensagem': 'Dispositivo criado.',
            'token': 'a1' * 32,
            'dispositivo': {
              'id': 50, 'nome': c['nome'], 'tipo': c['tipo'], 'tipo_rotulo': 'Cartão RFID', 'localizacao': c['localizacao'],
              'token': 'a1a1a1…a1a1', 'status': 'offline', 'ultimo_ping': null, 'ultimo_sinal': 'Nunca conectou',
            },
          });
        case '/api/dispositivos/token':
          final disp = (fixtureJson('dispositivos')['dispositivos'] as List).first as Map<String, dynamic>;
          return jsonResposta({'sucesso': true, 'mensagem': 'Novo token gerado.', 'token': 'b2' * 32, 'dispositivo': disp});
        case '/api/dispositivos/simular':
          return ok('simular');
        case '/api/dispositivos/pesagem':
          final c = corpo();
          return jsonResposta({'sucesso': true, 'mensagem': 'Total de desperdício registrado.', 'desperdicio_kg': c['desperdicio_kg'], 'tipo': c['tipo']});
        case '/api/pessoas/importar':
          return ok('importar');
        case '/api/pessoas/modelo':
          return http.Response.bytes(utf8.encode('\uFEFFnome;cargo;categoria;matricula;cartao\r\n'), 200,
              headers: {'content-type': 'text/csv; charset=utf-8'});
      }
      return jsonResposta({'sucesso': false, 'mensagem': 'Rota não encontrada.'}, 404); // como o servidor: JSON em UTF-8
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
