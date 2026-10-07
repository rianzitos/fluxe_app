import 'package:fluxe_app/core/api_client.dart';
import 'package:fluxe_app/core/format.dart';
import 'package:fluxe_app/models/models.dart';
import 'package:fluxe_app/widgets/charts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
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
