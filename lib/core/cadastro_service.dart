import '../models/models.dart';
import 'api_client.dart';

/// UID como o servidor guarda: sem espaços nem ":" e em maiúsculas ("a1:b2 c3" → "A1B2C3").
String normalizarUid(String bruto) => bruto.replaceAll(RegExp(r'[\s:]+'), '').toUpperCase();

final _padraoUid = RegExp(r'^[A-Z0-9_-]{4,100}$');

/// Mesma regra do servidor (o servidor confere de novo): letras, números, hífen ou sublinhado, de 4 a 100 caracteres.
/// Receba o UID já normalizado ([normalizarUid]).
bool uidValido(String uid) => _padraoUid.hasMatch(uid);

const mensagemUidInvalido = 'Cartão inválido. Use só letras, números, hífen ou sublinhado (de 4 a 100 caracteres).';

/// Cadastro de pessoas e cartões pela API do SystemFluxe (/api/pessoas/*). Só o administrador da empresa altera;
/// o servidor confere o perfil em toda escrita. Cada escrita devolve a mensagem do servidor ("Pessoa cadastrada.").
/// Erros chegam como [ApiException] com a mensagem pronta para mostrar (404, 409, 422, 403...).
class CadastroService {
  final ApiClient api;
  const CadastroService(this.api);

  Future<CadastroData> carregar() async => CadastroData.fromJson(await api.get('/pessoas/cadastro'));

  /// Cartões lidos nas catracas que ainda não têm dono (mais recente primeiro).
  Future<List<LeituraCartao>> leituras() async {
    final res = await api.get('/pessoas/leituras');
    return (res['leituras'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LeituraCartao.fromJson)
        .toList();
  }

  /// Cadastra a pessoa; com [uid], vincula o cartão junto (tudo ou nada).
  Future<String> criarPessoa({
    required String nome,
    required String cargo,
    required String categoria,
    String matricula = '',
    String uid = '',
  }) =>
      _escrever('/pessoas/criar', {
        'nome': nome,
        'cargo': cargo,
        'categoria': categoria,
        'matricula': matricula,
        if (uid.isNotEmpty) 'uid': uid,
      });

  Future<String> editarPessoa(
    int id, {
    required String nome,
    required String cargo,
    required String categoria,
    String matricula = '',
  }) =>
      _escrever('/pessoas/editar', {
        'id': id,
        'nome': nome,
        'cargo': cargo,
        'categoria': categoria,
        'matricula': matricula,
      });

  /// Desativada, a pessoa é negada na catraca e sai das contagens, mas o histórico fica.
  Future<String> definirPessoaAtiva(int id, bool ativo) => _escrever('/pessoas/ativo', {'id': id, 'ativo': ativo});

  Future<String> vincularCartao(int pessoaId, String uid) =>
      _escrever('/pessoas/cartao', {'funcionario_id': pessoaId, 'uid': uid});

  Future<String> definirCartaoAtivo(int cartaoId, bool ativo) =>
      _escrever('/pessoas/cartao/ativo', {'id': cartaoId, 'ativo': ativo});

  /// Remove o cartão: ele deixa de funcionar e o UID fica livre para outra pessoa.
  Future<String> removerCartao(int cartaoId) => _escrever('/pessoas/cartao/remover', {'id': cartaoId});

  Future<String> _escrever(String rota, Map<String, dynamic> corpo) async {
    final res = await api.post(rota, corpo);
    return (res['mensagem'] as String?) ?? 'Pronto.';
  }
}
