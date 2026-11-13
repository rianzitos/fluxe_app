import '../models/models.dart';
import 'api_client.dart';

/// Produção de refeições pela API do SystemFluxe (GET/POST /api/producao): quilos produzidos e desperdiçados em
/// cada refeição de um dia. As regras são as mesmas do site (o servidor usa o mesmo código), então as mensagens
/// de erro já chegam prontas para mostrar ([ApiException]).
class ProducaoService {
  final ApiClient api;
  const ProducaoService(this.api);

  /// O dia [data] (yyyy-MM-dd); sem data, hoje (pelo relógio do servidor).
  Future<ProducaoDia> carregar([String? data]) async {
    final res = await api.get('/producao', query: {'data': ?data});
    return ProducaoDia.fromJson(res['dia'] as Map<String, dynamic>);
  }

  /// Grava as refeições informadas. Em cada item: tipo, produzido e desperdicado (null = não mexe no valor atual).
  Future<({String mensagem, ProducaoDia dia})> salvar(String data, List<Map<String, Object?>> itens) async {
    final res = await api.post('/producao', {'data': data, 'itens': itens});
    return (
      mensagem: (res['mensagem'] as String?) ?? 'Produção salva.',
      dia: ProducaoDia.fromJson(res['dia'] as Map<String, dynamic>),
    );
  }
}
