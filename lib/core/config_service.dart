import 'dart:convert';
import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';

/// Configurações da conta e da empresa pela API do SystemFluxe: perfil, senha e foto; notificações e sistema;
/// sessões abertas no site; dispositivos IoT; sino; importação de planilha. As regras são as mesmas do site
/// (o servidor usa o mesmo código), então as mensagens de erro já chegam prontas para mostrar ([ApiException]).
class ConfigService {
  final ApiClient api;
  const ConfigService(this.api);

  // ─── Conta ──────────────────────────────────────────────────────────────

  /// Trocar o e-mail muda o login: o servidor exige a [senhaAtual].
  Future<({String mensagem, Usuario usuario})> atualizarPerfil({
    required String nome,
    required String email,
    required String cargo,
    String senhaAtual = '',
  }) async {
    final res = await api.post('/perfil', {
      'nome': nome,
      'email': email,
      'cargo': cargo,
      if (senhaAtual.isNotEmpty) 'senha_atual': senhaAtual,
    });
    return (mensagem: _mensagem(res), usuario: Usuario.fromJson(res['usuario'] as Map<String, dynamic>));
  }

  Future<String> atualizarSenha({required String atual, required String nova, required String confirmar}) async =>
      _mensagem(await api.post('/perfil/senha', {'senha_atual': atual, 'senha_nova': nova, 'senha_confirmar': confirmar}));

  /// Foto JPG ou PNG (até 5 MB; o app já manda reduzida).
  Future<({String mensagem, Usuario usuario})> enviarFoto(Uint8List imagem) async {
    final res = await api.post('/perfil/foto', {'imagem': base64Encode(imagem)});
    return (mensagem: _mensagem(res), usuario: Usuario.fromJson(res['usuario'] as Map<String, dynamic>));
  }

  // ─── Preferências ───────────────────────────────────────────────────────

  Future<PreferenciasData> preferencias() async => PreferenciasData.fromJson(await api.get('/preferencias'));

  /// Liga/desliga um alerta do sino. Devolve o novo número do sino.
  Future<int> salvarNotificacao(String chave, bool ativo) async {
    final res = await api.post('/preferencias/notificacao', {'chave': chave, 'ativo': ativo});
    return (res['sino'] as num?)?.toInt() ?? 0;
  }

  Future<String> salvarSistema({required String periodoPadrao, required int itensPagina}) async =>
      _mensagem(await api.post('/preferencias/sistema', {'periodo_padrao': periodoPadrao, 'itens_pagina': itensPagina}));

  // ─── Sessões do site ────────────────────────────────────────────────────

  /// null = o servidor ainda não controla sessões (falta a migration 004 no banco).
  Future<List<SessaoWeb>?> sessoes() async {
    final res = await api.get('/sessoes');
    if (res['disponivel'] == false) return null;
    return (res['sessoes'] as List? ?? const []).whereType<Map<String, dynamic>>().map(SessaoWeb.fromJson).toList();
  }

  Future<String> encerrarSessao(int id) async => _mensagem(await api.post('/sessoes/encerrar', {'id': id}));

  Future<String> encerrarTodasAsSessoes() async => _mensagem(await api.post('/sessoes/encerrar', {'todas': true}));

  // ─── Sino ───────────────────────────────────────────────────────────────

  /// Os mesmos alertas do sino do site (previsão + catracas, conforme as preferências), com o destino de cada um.
  Future<List<Alerta>> notificacoes() async {
    final res = await api.get('/notificacoes');
    return (res['alertas'] as List? ?? const []).whereType<Map<String, dynamic>>().map(Alerta.fromJson).toList();
  }

  // ─── Dispositivos IoT ───────────────────────────────────────────────────

  Future<DispositivosData> dispositivos() async => DispositivosData.fromJson(await api.get('/dispositivos'));

  /// Devolve o token INTEIRO, que o servidor não mostra de novo.
  Future<({String mensagem, String token, DispositivoIot dispositivo})> criarDispositivo({
    required String nome,
    required String tipo,
    String localizacao = '',
  }) async {
    final res = await api.post('/dispositivos/criar', {'nome': nome, 'tipo': tipo, 'localizacao': localizacao});
    return _comToken(res);
  }

  /// O aparelho que usa o token antigo deixa de ser aceito.
  Future<({String mensagem, String token, DispositivoIot dispositivo})> novoToken(int id) async =>
      _comToken(await api.post('/dispositivos/token', {'id': id}));

  /// Passa um cartão pela catraca, pela mesma regra de uma leitura real: registra um acesso de verdade.
  Future<ResultadoLeitura> simularLeitura(int dispositivoId, String uid) async =>
      ResultadoLeitura.fromJson(await api.post('/dispositivos/simular', {'id': dispositivoId, 'uid': uid}));

  /// Substitui o total de desperdício da refeição no dia (para a empresa toda).
  Future<String> registrarPesagem({required int balancaId, required String refeicao, required double kg}) async =>
      _mensagem(await api.post('/dispositivos/pesagem', {'id': balancaId, 'tipo': refeicao, 'desperdicio_kg': kg}));

  // ─── Planilha de pessoas ────────────────────────────────────────────────

  Future<ResultadoImportacao> importarPlanilha(String csv) async =>
      ResultadoImportacao.fromJson(await api.post('/pessoas/importar', {'csv': csv}));

  Future<String> modeloPlanilha() => api.getText('/pessoas/modelo');

  // ─── Helpers ────────────────────────────────────────────────────────────

  static String _mensagem(Map<String, dynamic> res) => (res['mensagem'] as String?) ?? 'Pronto.';

  static ({String mensagem, String token, DispositivoIot dispositivo}) _comToken(Map<String, dynamic> res) => (
        mensagem: _mensagem(res),
        token: res['token'] as String? ?? '',
        dispositivo: DispositivoIot.fromJson((res['dispositivo'] as Map<String, dynamic>?) ?? const {}),
      );
}

/// O app é mais novo que o SystemFluxe do servidor: a rota ainda não existe lá (o servidor responde 404 com
/// "Rota não encontrada."; um 404 de regra, como "Dispositivo não encontrado.", tem outra mensagem).
bool servidorDesatualizado(Object erro) =>
    erro is ApiException && erro.status == 404 && erro.message == 'Rota não encontrada.';

const mensagemServidorDesatualizado =
    'O servidor ainda não tem esta função pelo aplicativo. Atualize o SystemFluxe e tente de novo.';

/// Texto para mostrar de um erro de uma ação (servidor antigo vira a explicação do que fazer).
String mensagemDoErro(Object erro) {
  if (servidorDesatualizado(erro)) return mensagemServidorDesatualizado;
  if (erro is ApiException) return erro.message;
  return 'Não foi possível concluir. Tente novamente.';
}

/// Para as consultas das telas: troca o 404 de servidor antigo por uma explicação do que fazer.
Future<T> comAvisoDeServidorAntigo<T>(Future<T> Function() chamada) async {
  try {
    return await chamada();
  } on ApiException catch (e) {
    if (servidorDesatualizado(e)) throw const ApiException(mensagemServidorDesatualizado, status: 404);
    rethrow;
  }
}
