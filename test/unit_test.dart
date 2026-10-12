import 'dart:convert';
import 'dart:io';

import 'package:fluxe_app/core/api_client.dart';
import 'package:fluxe_app/core/app_state.dart';
import 'package:fluxe_app/core/format.dart';
import 'package:fluxe_app/core/salvar_arquivo.dart';
import 'package:fluxe_app/models/models.dart';
import 'package:fluxe_app/widgets/charts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  group('exportação do relatório no PC', () {
    late Directory pasta;
    setUp(() => pasta = Directory.systemTemp.createTempSync('sicapda_csv_'));
    tearDown(() => pasta.deleteSync(recursive: true));

    test('salva em UTF-8 com BOM (Excel) e não sobrescreve arquivos existentes', () async {
      final a = await salvarCsvNosDownloads('rel.csv', 'Nome;Função\nJosé;Operador\n', pasta: pasta);
      final b = await salvarCsvNosDownloads('rel.csv', 'outro', pasta: pasta);

      expect(a.endsWith('rel.csv'), isTrue);
      expect(b.endsWith('rel (1).csv'), isTrue);
      final bytes = File(a).readAsBytesSync();
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.skip(3).toList()), 'Nome;Função\nJosé;Operador\n');
    });

    test('não duplica o BOM quando o texto já começa com ele', () async {
      final a = await salvarCsvNosDownloads('rel.csv', '\uFEFFa;b', pasta: pasta);
      final bytes = File(a).readAsBytesSync();
      expect(bytes.take(6), [0xEF, 0xBB, 0xBF, 0x61, 0x3B, 0x62]);
    });

    test('cria a pasta se ela não existir', () async {
      final sub = Directory('${pasta.path}${Platform.pathSeparator}Downloads');
      final a = await salvarCsvNosDownloads('x.csv', 'a', pasta: sub);
      expect(File(a).existsSync(), isTrue);
    });
  });

  group('formatação', () {
    test('números em pt-BR', () {
      expect(fmtNum(1234567), '1.234.567');
      expect(fmtNum(1234.5, decimals: 1), '1.234,5');
      expect(fmtNum(-80.8, decimals: 1), '-80,8');
      expect(fmtValor(106), '106');
      expect(fmtValor(84.2), '84,2');
    });

    test('variação com sinal', () {
      expect(fmtVariacao(0), '+0,0%');
      expect(fmtVariacao(3.5), '+3,5%');
      expect(fmtVariacao(-76.1), '-76,1%');
    });

    test('datas', () {
      expect(isoData(DateTime(2026, 10, 6)), '2026-10-06');
      expect(isoParaBr('2026-10-06'), '06/10/2026');
      expect(iniciais('Rian Rafael'), 'RR');
      expect(iniciais('Natália'), 'N');
    });

    test('escala do eixo Y', () {
      expect(niceScale([35]).max, 40);
      expect(niceScale([35]).interval, 10);
      expect(niceScale([37, 12]).max, 40);
      expect(niceScale([39]).max, 50);
      expect(niceScale([2.7]).max, 3);
      expect(niceScale([0, 0]).max, 1);
    });
  });

  group('ApiClient', () {
    test('normaliza o endereço do servidor', () {
      expect(ApiClient.normalizeBaseUrl('fluxeteam.com.br/'), 'https://fluxeteam.com.br');
      expect(ApiClient.normalizeBaseUrl(' http://10.0.2.2:8000// '), 'http://10.0.2.2:8000');
      expect(ApiClient.normalizeBaseUrl(''), '');
    });

    test('envia o Bearer token e descarta parâmetros vazios', () async {
      final log = <dynamic>[];
      final client = ApiClient(
        baseUrl: 'https://x.test',
        token: 'abc',
        client: fakeApi(log: log.cast()),
      );
      await client.get('/painel', query: {'mes': '', 'pagina': '2'});
      final req = log.single;
      expect(req.headers['Authorization'], 'Bearer abc');
      expect(req.url.toString(), 'https://x.test/api/painel?pagina=2');
    });

    test('erro da API vira ApiException com a mensagem do servidor', () async {
      final client = ApiClient(baseUrl: 'https://x.test', client: fakeApi());
      expect(
        () => client.post('/login', {'email': 'a@b.c', 'senha': 'errada'}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'E-mail ou senha inválidos.')
            .having((e) => e.status, 'status', 401)),
      );
    });

    test('falha de conexão vira ApiException com o motivo técnico', () async {
      final semRede = MockClient((_) async => throw http.ClientException(
          "Failed host lookup: 'x.test' (OS Error: No address associated with hostname, errno = 7)",
          Uri.parse('https://x.test/api/login')));
      final client = ApiClient(baseUrl: 'https://x.test', client: semRede);
      expect(
        () => client.post('/login', {'email': 'a@b.c', 'senha': '1'}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', startsWith('Não foi possível conectar ao servidor'))
            .having((e) => e.detail, 'detail', startsWith("Failed host lookup: 'x.test'"))
            .having((e) => e.detail, 'detail', endsWith('servidor: https://x.test'))),
      );
    });
    test('certificado HTTPS inválido (HandshakeException) também vira a mensagem clara, com o motivo', () async {
      final certificadoRuim = MockClient((_) async =>
          throw const HandshakeException('Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED: certificate has expired)'));
      final client = ApiClient(baseUrl: 'https://x.test', client: certificadoRuim);
      expect(
        () => client.post('/login', {'email': 'a@b.c', 'senha': '1'}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', startsWith('Não foi possível conectar ao servidor'))
            .having((e) => e.detail, 'detail', contains('certificate has expired'))),
      );
    });
  });

  group('servidor padrão', () {
    final pagina = Uri.parse('https://sicapda.exemplo.com.br/aplicativo/');

    test('celular e PC usam o servidor de produção', () {
      expect(resolveDefaultBaseUrl(page: pagina, web: false, release: true), kProductionBaseUrl);
    });

    test('versão web publicada usa o próprio site de onde a página foi aberta', () {
      expect(resolveDefaultBaseUrl(page: pagina, web: true, release: true), 'https://sicapda.exemplo.com.br');
      expect(resolveDefaultBaseUrl(page: Uri.parse('http://192.168.0.10:8000/aplicativo/'), web: true, release: true),
          'http://192.168.0.10:8000');
      expect(resolveDefaultBaseUrl(page: Uri.parse('https://x.com.br/aplicativo/index.html?a=1#/x'), web: true, release: true),
          'https://x.com.br');
    });

    test('site numa subpasta (XAMPP) mantém a subpasta', () {
      expect(
          resolveDefaultBaseUrl(
              page: Uri.parse('http://localhost/SystemFluxe/public/aplicativo/'), web: true, release: true),
          'http://localhost/SystemFluxe/public');
    });

    test('flutter run no navegador (debug) não usa a porta do servidor de desenvolvimento', () {
      expect(resolveDefaultBaseUrl(page: Uri.parse('http://localhost:5555/'), web: true, release: false),
          kProductionBaseUrl);
    });

    test('página que não é http(s) cai no servidor de produção', () {
      expect(resolveDefaultBaseUrl(page: Uri.parse('file:///C:/app/index.html'), web: true, release: true),
          kProductionBaseUrl);
    });
  });

  group('sessão', () {
    test('BrowserTokenStore guarda, lê e apaga o token no armazenamento do navegador', () async {
      SharedPreferences.setMockInitialValues({});
      final store = BrowserTokenStore();
      expect(await store.read(), isNull);
      await store.write('abc.def');
      expect(await store.read(), 'abc.def');
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('entrar e sair funcionam mesmo se o cofre do aparelho recusar gravar/apagar', () async {
      SharedPreferences.setMockInitialValues({});
      final c = AppController(
        prefs: await SharedPreferences.getInstance(),
        tokenStore: _CofreQuebrado(),
        httpClient: fakeApi(),
      );
      await c.init();
      await c.login('rian@fluxe.com', 'senha1234');
      expect(c.isLoggedIn, isTrue);
      await c.logout();
      expect(c.isLoggedIn, isFalse);
    });

    test('o servidor escolhido pela pessoa vale mais que o padrão', () async {
      SharedPreferences.setMockInitialValues({'base_url': 'http://10.0.2.2:8000'});
      final c = AppController(
        prefs: await SharedPreferences.getInstance(),
        tokenStore: MemoryTokenStore(),
        httpClient: fakeApi(),
        defaultServer: 'https://padrao.exemplo.com.br',
      );
      expect(c.baseUrl, 'https://padrao.exemplo.com.br');
      await c.init();
      expect(c.baseUrl, 'http://10.0.2.2:8000');
    });
  });

  group('modelos (JSON real da API)', () {
    test('painel', () {
      final d = PainelData.fromJson(fixtureJson('painel'));
      expect(d.cards, hasLength(4));
      expect(d.cards.first.label, 'Usuários Ativos');
      expect(d.cards.last.sufixo, '%');
      expect(d.demanda.labels.length, d.demanda.previsto.length);
      expect(d.demanda.labels.length, d.demanda.realizado.length);
      expect(d.distribuicao.map((f) => f.label), ['Café', 'Almoço', 'Jantar']);
      expect(d.alertas.map((a) => a.tipo), containsAll(['aviso', 'info']));
      expect(d.mesReferencia, 'Outubro 2026');
    });

    test('análise mensal', () {
      final d = AnaliseData.fromJson(fixtureJson('analise'));
      expect(d.cards, hasLength(3));
      expect(d.cards[1].positiva, isNotNull);
      expect(d.pessoasDia.labels.length, d.pessoasDia.valores.length);
      expect(d.meses, hasLength(12));
      expect(d.insights, hasLength(4));
    });

    test('pessoas', () {
      final d = PessoasData.fromJson(fixtureJson('pessoas'));
      expect(d.grupos.map((g) => g.chave), ['operadores', 'supervisores', 'prestadores']);
      expect(d.cards.first.valor, d.grupos.fold<int>(0, (s, g) => s + g.pessoas.length));
    });

    test('relatórios', () {
      final d = RelatorioData.fromJson(fixtureJson('relatorios'));
      expect(d.registros, isNotEmpty);
      expect(d.registros.length, lessThanOrEqualTo(d.porPagina));
      expect(d.paginas, greaterThanOrEqualTo(1));
      expect(d.de, '2026-10-01');
    });

    test('assistente e usuário', () {
      final a = AssistenteInfo.fromJson(fixtureJson('assistente'));
      expect(a.perguntasRapidas, hasLength(3));
      expect(a.precisao?.dias, greaterThan(0));
      final u = Usuario.fromJson(fixtureJson('me')['usuario'] as Map<String, dynamic>);
      expect(u.perfilRotulo, 'Admin');
      expect(Usuario.fromJson(u.toJson()).empresa.nome, u.empresa.nome);
    });

    test('tolera campos ausentes e nulos', () {
      final d = PainelData.fromJson({'sucesso': true});
      expect(d.cards, isEmpty);
      expect(d.distribuicao, isEmpty);
      final c = CardResumo.fromJson({'chave': 'acuracia', 'label': 'x', 'valor': null});
      expect(c.valor, isNull);
    });
  });
}

/// Cofre que sempre falha (Keystore do Android corrompido, armazenamento do navegador bloqueado...).
class _CofreQuebrado implements TokenStore {
  @override
  Future<String?> read() async => throw StateError('cofre indisponível');

  @override
  Future<void> write(String token) async => throw StateError('cofre indisponível');

  @override
  Future<void> clear() async => throw StateError('cofre indisponível');
}
