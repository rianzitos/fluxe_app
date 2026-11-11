/// Modelos que espelham o JSON da API (SystemFluxe /api/*).
library;

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _i(dynamic v) => _d(v)?.round() ?? 0;

String _s(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

bool _b(dynamic v) => v == true || v == 1 || v == '1';

List<Map<String, dynamic>> _list(dynamic v) =>
    (v as List? ?? const []).whereType<Map<String, dynamic>>().toList();

List<double> _doubles(dynamic v) =>
    (v as List? ?? const []).map((e) => _d(e) ?? 0).toList();

List<String> _strings(dynamic v) => (v as List? ?? const []).map((e) => _s(e)).toList();

// ─── Usuário ───────────────────────────────────────────────────────────────

class Empresa {
  final int id;
  final String nome;
  final String? cnpj;
  final String? cidade;
  final String? estado;
  final String? horario;

  const Empresa({
    required this.id,
    required this.nome,
    this.cnpj,
    this.cidade,
    this.estado,
    this.horario,
  });

  factory Empresa.fromJson(Map<String, dynamic> j) => Empresa(
        id: _i(j['id']),
        nome: _s(j['nome']),
        cnpj: j['cnpj'] as String?,
        cidade: j['cidade'] as String?,
        estado: j['estado'] as String?,
        horario: j['horario_funcionamento'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cnpj': cnpj,
        'cidade': cidade,
        'estado': estado,
        'horario_funcionamento': horario,
      };
}

class Usuario {
  final int id;
  final String nome;
  final String email;
  final String perfil;
  final String? cargo;
  final String? telefone;
  final String? matricula;
  final String? foto;
  final Empresa empresa;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    required this.empresa,
    this.cargo,
    this.telefone,
    this.matricula,
    this.foto,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: _i(j['id']),
        nome: _s(j['nome']),
        email: _s(j['email']),
        perfil: _s(j['perfil']),
        cargo: j['cargo'] as String?,
        telefone: j['telefone'] as String?,
        matricula: j['matricula'] as String?,
        foto: j['foto'] as String?,
        empresa: Empresa.fromJson((j['empresa'] as Map<String, dynamic>?) ?? const {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'email': email,
        'perfil': perfil,
        'cargo': cargo,
        'telefone': telefone,
        'matricula': matricula,
        'foto': foto,
        'empresa': empresa.toJson(),
      };

  /// "admin" -> "Admin"
  String get perfilRotulo =>
      perfil.isEmpty ? '' : perfil[0].toUpperCase() + perfil.substring(1);
}

// ─── Cards ─────────────────────────────────────────────────────────────────

class CardResumo {
  final String chave;
  final String label;
  final double? valor;
  final String sufixo;
  final double? variacao;
  final bool? positiva;
  final String? periodo;
  final String? extra;

  /// Valor já formatado (ex.: "6h 39min"); quando presente, substitui [valor].
  final String? valorTexto;

  const CardResumo({
    required this.chave,
    required this.label,
    this.valor,
    this.sufixo = '',
    this.variacao,
    this.positiva,
    this.periodo,
    this.extra,
    this.valorTexto,
  });

  factory CardResumo.fromJson(Map<String, dynamic> j) => CardResumo(
        chave: _s(j['chave']),
        label: _s(j['label']),
        valor: _d(j['valor']),
        sufixo: _s(j['sufixo']),
        variacao: _d(j['variacao']),
        positiva: j['positiva'] as bool?,
        periodo: j['periodo'] as String?,
        extra: j['extra'] as String?,
      );
}

class Alerta {
  final String tipo; // aviso | info | sucesso
  final String titulo;
  final String descricao;
  final String? data;
  final String? rotulo;

  /// Onde o assunto é tratado, como no sino do site ("/relatorios", "/configuracoes#integracoes"...).
  final String? link;

  const Alerta({
    required this.tipo,
    required this.titulo,
    required this.descricao,
    this.data,
    this.rotulo,
    this.link,
  });

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        tipo: _s(j['tipo'], 'info'),
        titulo: _s(j['titulo']),
        descricao: _s(j['descricao']),
        data: j['data'] as String?,
        rotulo: j['rotulo'] as String?,
        link: j['link'] as String?,
      );
}

// ─── Painel ────────────────────────────────────────────────────────────────

class SerieDemanda {
  final List<String> labels;
  final List<double> previsto;
  final List<double> realizado;
  const SerieDemanda(this.labels, this.previsto, this.realizado);
}

class FatiaRefeicao {
  final String label;
  final double percentual;
  final String cor;
  const FatiaRefeicao(this.label, this.percentual, this.cor);
}

class HoraPrevista {
  final String hora;
  final String status; // alto | normal | baixo
  final int pessoas;
  const HoraPrevista(this.hora, this.status, this.pessoas);
}

class PainelData {
  final List<CardResumo> cards;
  final SerieDemanda demanda;
  final List<FatiaRefeicao> distribuicao;
  final List<HoraPrevista> proximasHoras;
  final List<Alerta> alertas;
  final String mesReferencia;

  const PainelData({
    required this.cards,
    required this.demanda,
    required this.distribuicao,
    required this.proximasHoras,
    required this.alertas,
    required this.mesReferencia,
  });

  factory PainelData.fromJson(Map<String, dynamic> j) {
    final g = (j['graficoDemanda'] as Map<String, dynamic>?) ?? const {};
    final dist = (j['graficoDistribuicao'] as Map<String, dynamic>?) ?? const {};
    final labels = _strings(dist['labels']);
    final valores = _doubles(dist['valores']);
    final cores = _strings(dist['cores']);

    return PainelData(
      cards: _list(j['cardsResumo']).map(CardResumo.fromJson).toList(),
      demanda: SerieDemanda(_strings(g['labels']), _doubles(g['previsto']), _doubles(g['realizado'])),
      distribuicao: [
        for (var i = 0; i < labels.length && i < valores.length; i++)
          FatiaRefeicao(labels[i], valores[i], i < cores.length ? cores[i] : '#6B7280'),
      ],
      proximasHoras: _list(j['previsaoProximasHoras'])
          .map((e) => HoraPrevista(_s(e['hora']), _s(e['status'], 'normal'), _i(e['pessoas'])))
          .toList(),
      alertas: _list(j['alertas']).map(Alerta.fromJson).toList(),
      mesReferencia: _s(j['mesReferencia']),
    );
  }
}

// ─── Análise mensal ────────────────────────────────────────────────────────

class SerieDia {
  final List<String> labels;
  final List<double> valores;
  const SerieDia(this.labels, this.valores);

  factory SerieDia.fromJson(dynamic raw) {
    final j = (raw as Map<String, dynamic>?) ?? const {};
    return SerieDia(_strings(j['labels']), _doubles(j['valores']));
  }
}

class Insight {
  final String label;
  final String valor;
  final String icone;
  const Insight(this.label, this.valor, this.icone);
}

class MesOpcao {
  final String valor; // 2026-10
  final String rotulo; // Outubro 2026
  const MesOpcao(this.valor, this.rotulo);
}

class AnaliseData {
  final String mes;
  final String mesRotulo;
  final List<MesOpcao> meses;
  final List<CardResumo> cards;
  final SerieDia pessoasDia;
  final SerieDia producao;
  final SerieDia desperdicio;
  final List<Insight> insights;

  const AnaliseData({
    required this.mes,
    required this.mesRotulo,
    required this.meses,
    required this.cards,
    required this.pessoasDia,
    required this.producao,
    required this.desperdicio,
    required this.insights,
  });

  factory AnaliseData.fromJson(Map<String, dynamic> j) => AnaliseData(
        mes: _s(j['mes']),
        mesRotulo: _s(j['mesRotulo']),
        meses: _list(j['meses']).map((e) => MesOpcao(_s(e['valor']), _s(e['rotulo']))).toList(),
        cards: _list(j['cardsResumo']).map(CardResumo.fromJson).toList(),
        pessoasDia: SerieDia.fromJson(j['graficoPessoasDia']),
        producao: SerieDia.fromJson(j['graficoProducao']),
        desperdicio: SerieDia.fromJson(j['graficoDesperdicio']),
        insights: _list(j['insights'])
            .map((e) => Insight(_s(e['label']), _s(e['valor']), _s(e['icone'])))
            .toList(),
      );
}

// ─── Pessoas ───────────────────────────────────────────────────────────────

class PessoaPresente {
  final String nome;
  final String funcao;
  final String entrada;
  const PessoaPresente(this.nome, this.funcao, this.entrada);
}

class GrupoPessoas {
  final String chave;
  final String titulo;
  final int presentes;
  final List<PessoaPresente> pessoas;
  const GrupoPessoas(this.chave, this.titulo, this.presentes, this.pessoas);
}

class PessoasData {
  final List<CardResumo> cards;
  final List<GrupoPessoas> grupos;
  final String dataExtenso;
  const PessoasData(this.cards, this.grupos, this.dataExtenso);

  factory PessoasData.fromJson(Map<String, dynamic> j) => PessoasData(
        _list(j['cardsResumo']).map(CardResumo.fromJson).toList(),
        _list(j['grupos'])
            .map((g) => GrupoPessoas(
                  _s(g['chave']),
                  _s(g['titulo']),
                  _i(g['presentes']),
                  _list(g['pessoas'])
                      .map((p) => PessoaPresente(_s(p['nome']), _s(p['funcao']), _s(p['entrada'])))
                      .toList(),
                ))
            .toList(),
        _s(j['dataExtenso']),
      );
}

// ─── Cadastro de pessoas e cartões ─────────────────────────────────────────

class CartaoPessoa {
  final int id;
  final String uid;
  final bool ativo;
  const CartaoPessoa({required this.id, required this.uid, required this.ativo});

  factory CartaoPessoa.fromJson(Map<String, dynamic> j) =>
      CartaoPessoa(id: _i(j['id']), uid: _s(j['uid']), ativo: _b(j['ativo']));
}

class PessoaCadastro {
  final int id;
  final String nome;
  final String cargo;
  final String categoria; // operador | supervisor | prestador
  final String categoriaRotulo;
  final String? matricula;
  final bool ativo;
  final bool presente;
  final List<CartaoPessoa> cartoes;

  const PessoaCadastro({
    required this.id,
    required this.nome,
    required this.cargo,
    required this.categoria,
    required this.categoriaRotulo,
    required this.ativo,
    required this.presente,
    required this.cartoes,
    this.matricula,
  });

  factory PessoaCadastro.fromJson(Map<String, dynamic> j) {
    final matricula = _s(j['matricula']).trim();
    return PessoaCadastro(
      id: _i(j['id']),
      nome: _s(j['nome']),
      cargo: _s(j['cargo']),
      categoria: _s(j['categoria'], 'operador'),
      categoriaRotulo: _s(j['categoriaRotulo'], _s(j['categoria'])),
      matricula: matricula.isEmpty ? null : matricula,
      ativo: _b(j['ativo']),
      presente: _b(j['presente']),
      cartoes: _list(j['cartoes']).map(CartaoPessoa.fromJson).toList(),
    );
  }

  bool get temCartaoAtivo => cartoes.any((c) => c.ativo);

  /// Texto da busca (nome, função, matrícula e cartões, em minúsculas), como na aba Cadastro do site.
  String get textoBusca => [nome, cargo, matricula ?? '', ...cartoes.map((c) => c.uid)].join(' ').toLowerCase();
}

class CategoriaOpcao {
  final String valor;
  final String rotulo;
  const CategoriaOpcao(this.valor, this.rotulo);
}

/// Categorias usadas se o servidor não mandar a lista (as mesmas do site).
const kCategoriasPadrao = [
  CategoriaOpcao('operador', 'Operador'),
  CategoriaOpcao('supervisor', 'Supervisor'),
  CategoriaOpcao('prestador', 'Prestador de Serviço'),
];

class CadastroData {
  /// Só o administrador da empresa altera o cadastro; os outros usuários só consultam.
  final bool podeEditar;
  final int total;
  final int ativas;
  final int semCartaoAtivo;
  final List<CategoriaOpcao> categorias;
  final List<PessoaCadastro> pessoas;

  const CadastroData({
    required this.podeEditar,
    required this.total,
    required this.ativas,
    required this.semCartaoAtivo,
    required this.categorias,
    required this.pessoas,
  });

  factory CadastroData.fromJson(Map<String, dynamic> j) {
    final resumo = (j['resumo'] as Map<String, dynamic>?) ?? const {};
    final categorias = _list(j['categorias']).map((e) => CategoriaOpcao(_s(e['valor']), _s(e['rotulo']))).toList();
    final pessoas = _list(j['pessoas']).map(PessoaCadastro.fromJson).toList();
    return CadastroData(
      podeEditar: _b(j['podeEditar']),
      total: _i(resumo['total'] ?? pessoas.length),
      ativas: _i(resumo['ativas']),
      semCartaoAtivo: _i(resumo['semCartaoAtivo']),
      categorias: categorias.isEmpty ? kCategoriasPadrao : categorias,
      pessoas: pessoas,
    );
  }
}

/// Cartão lido numa catraca que ainda não tem dono (aparece para o administrador vincular).
class LeituraCartao {
  final String uid;
  final int leituras;
  final String dispositivo;
  final String quando; // "agora", "há 2 min"...
  const LeituraCartao({required this.uid, required this.leituras, required this.dispositivo, required this.quando});

  factory LeituraCartao.fromJson(Map<String, dynamic> j) => LeituraCartao(
        uid: _s(j['uid']),
        leituras: _i(j['leituras']),
        dispositivo: _s(j['dispositivo']),
        quando: _s(j['quando']),
      );
}

// ─── Relatórios ────────────────────────────────────────────────────────────

class RegistroAcesso {
  final int id;
  final String nome;
  final String cargo;
  final String categoria;
  final String categoriaRotulo;
  final String dia; // yyyy-MM-dd
  final String? entrada;
  final String? saida;
  final String? duracao;

  const RegistroAcesso({
    required this.id,
    required this.nome,
    required this.cargo,
    required this.categoria,
    required this.categoriaRotulo,
    required this.dia,
    this.entrada,
    this.saida,
    this.duracao,
  });

  factory RegistroAcesso.fromJson(Map<String, dynamic> j) => RegistroAcesso(
        id: _i(j['id']),
        nome: _s(j['nome']),
        cargo: _s(j['cargo']),
        categoria: _s(j['categoria']),
        categoriaRotulo: _s(j['categoriaRotulo']),
        dia: _s(j['dia']),
        entrada: j['entrada'] as String?,
        saida: j['saida'] as String?,
        duracao: j['duracao'] as String?,
      );
}

class RelatorioData {
  final String de;
  final String ate;
  final int total;
  final int pagina;
  final int paginas;
  final int porPagina;
  final int hoje;
  final String duracaoMedia;
  final String pico;
  final List<RegistroAcesso> registros;

  const RelatorioData({
    required this.de,
    required this.ate,
    required this.total,
    required this.pagina,
    required this.paginas,
    required this.porPagina,
    required this.hoje,
    required this.duracaoMedia,
    required this.pico,
    required this.registros,
  });

  factory RelatorioData.fromJson(Map<String, dynamic> j) {
    final f = (j['filtros'] as Map<String, dynamic>?) ?? const {};
    final c = (j['cards'] as Map<String, dynamic>?) ?? const {};
    return RelatorioData(
      de: _s(f['de']),
      ate: _s(f['ate']),
      total: _i(j['total']),
      pagina: _i(j['pagina']),
      paginas: _i(j['paginas']),
      porPagina: _i(j['porPagina']),
      hoje: _i(c['hoje']),
      duracaoMedia: _s(c['duracao'], '—'),
      pico: _s(c['pico'], '—'),
      registros: _list(j['registros']).map(RegistroAcesso.fromJson).toList(),
    );
  }
}

// ─── Assistente ────────────────────────────────────────────────────────────

class PrecisaoIA {
  final double precisao;
  final int dias;
  const PrecisaoIA(this.precisao, this.dias);
}

class AssistenteInfo {
  final String boasVindas;
  final PrecisaoIA? precisao;
  final List<Alerta> eventos;
  final List<String> perguntasRapidas;

  const AssistenteInfo({
    required this.boasVindas,
    required this.precisao,
    required this.eventos,
    required this.perguntasRapidas,
  });

  factory AssistenteInfo.fromJson(Map<String, dynamic> j) {
    final p = j['precisao'] as Map<String, dynamic>?;
    return AssistenteInfo(
      boasVindas: _s(j['boasVindas']),
      precisao: p == null ? null : PrecisaoIA(_d(p['precisao']) ?? 0, _i(p['dias'])),
      eventos: _list(j['eventos']).map(Alerta.fromJson).toList(),
      perguntasRapidas: _strings(j['perguntasRapidas']),
    );
  }
}

// ─── Configurações ─────────────────────────────────────────────────────────

/// Valor + rótulo de uma lista de opções vinda do servidor (tipos de dispositivo, refeições, períodos...).
class OpcaoValor {
  final String valor;
  final String rotulo;
  const OpcaoValor(this.valor, this.rotulo);

  factory OpcaoValor.fromJson(Map<String, dynamic> j) => OpcaoValor(_s(j['valor']), _s(j['rotulo']));
}

/// Um alerta que a pessoa liga ou desliga (Configurações → Notificações).
class PreferenciaNotificacao {
  final String chave;
  final String label;
  final String descricao;

  /// false = ainda não funciona no sistema ("Em breve"): aparece desligada e travada.
  final bool disponivel;
  final bool ativo;

  const PreferenciaNotificacao({
    required this.chave,
    required this.label,
    required this.descricao,
    required this.disponivel,
    required this.ativo,
  });

  factory PreferenciaNotificacao.fromJson(Map<String, dynamic> j) => PreferenciaNotificacao(
        chave: _s(j['chave']),
        label: _s(j['label']),
        descricao: _s(j['descricao']),
        disponivel: _b(j['disponivel']),
        ativo: _b(j['ativo']),
      );

  PreferenciaNotificacao comAtivo(bool valor) =>
      PreferenciaNotificacao(chave: chave, label: label, descricao: descricao, disponivel: disponivel, ativo: valor);
}

/// Notificações e "Sistema" (período padrão e itens por página dos Relatórios) da conta.
class PreferenciasData {
  final List<PreferenciaNotificacao> notificacoes;
  final String periodoPadrao;
  final int itensPagina;
  final List<OpcaoValor> periodos;
  final List<int> opcoesItens;
  final String fuso;

  const PreferenciasData({
    required this.notificacoes,
    required this.periodoPadrao,
    required this.itensPagina,
    required this.periodos,
    required this.opcoesItens,
    required this.fuso,
  });

  factory PreferenciasData.fromJson(Map<String, dynamic> j) {
    final sistema = (j['sistema'] as Map<String, dynamic>?) ?? const {};
    final opcoes = (j['opcoes'] as Map<String, dynamic>?) ?? const {};
    final periodos = _list(opcoes['periodos']).map(OpcaoValor.fromJson).toList();
    final itens = (opcoes['itensPagina'] as List? ?? const []).map(_i).where((n) => n > 0).toList();
    return PreferenciasData(
      notificacoes: _list(j['notificacoes']).map(PreferenciaNotificacao.fromJson).toList(),
      periodoPadrao: _s(sistema['periodo_padrao'], 'mes'),
      itensPagina: _i(sistema['itens_pagina'] ?? 20),
      periodos: periodos.isEmpty
          ? const [
              OpcaoValor('mes', 'Este mês'),
              OpcaoValor('7', 'Últimos 7 dias'),
              OpcaoValor('30', 'Últimos 30 dias'),
              OpcaoValor('90', 'Últimos 90 dias'),
            ]
          : periodos,
      opcoesItens: itens.isEmpty ? const [10, 20, 50] : itens,
      fuso: _s(opcoes['fuso'], 'Horário de Brasília (GMT-3)'),
    );
  }
}

/// Onde a conta está aberta no site (navegador). O aplicativo não aparece aqui: ele entra com token.
class SessaoWeb {
  final int id;
  final String dispositivo; // "Chrome · Windows"
  final bool celular;
  final String ip;
  final String ultimoAcesso; // "há 5 min"

  const SessaoWeb({
    required this.id,
    required this.dispositivo,
    required this.celular,
    required this.ip,
    required this.ultimoAcesso,
  });

  factory SessaoWeb.fromJson(Map<String, dynamic> j) => SessaoWeb(
        id: _i(j['id']),
        dispositivo: _s(j['dispositivo']),
        celular: _b(j['celular']),
        ip: _s(j['ip'], '—'),
        ultimoAcesso: _s(j['ultimo_acesso']),
      );
}

// ─── Dispositivos IoT ──────────────────────────────────────────────────────

/// Catraca, leitor RFID/biometria ou balança de desperdício da empresa.
class DispositivoIot {
  final int id;
  final String nome;
  final String tipo; // rfid | biometria | hibrido | balanca
  final String tipoRotulo;
  final String? localizacao;

  /// Sempre mascarado ("8f2a1c…c91d"): o token inteiro só aparece ao criar ou gerar outro.
  final String tokenMascarado;
  final bool online;
  final String ultimoSinal; // "Último sinal há 2 min" / "Nunca conectou"

  const DispositivoIot({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.tipoRotulo,
    required this.tokenMascarado,
    required this.online,
    required this.ultimoSinal,
    this.localizacao,
  });

  bool get ehBalanca => tipo == 'balanca';

  factory DispositivoIot.fromJson(Map<String, dynamic> j) {
    final local = _s(j['localizacao']).trim();
    return DispositivoIot(
      id: _i(j['id']),
      nome: _s(j['nome']),
      tipo: _s(j['tipo'], 'rfid'),
      tipoRotulo: _s(j['tipo_rotulo'], _s(j['tipo'])),
      localizacao: local.isEmpty ? null : local,
      tokenMascarado: _s(j['token']),
      online: _s(j['status']) == 'online',
      ultimoSinal: _s(j['ultimo_sinal']),
    );
  }
}

/// Total de desperdício registrado hoje numa refeição (null = ainda sem registro).
class DesperdicioRefeicao {
  final String tipo; // cafe | almoco | jantar | ceia
  final String rotulo;
  final double? kg;
  const DesperdicioRefeicao(this.tipo, this.rotulo, this.kg);

  factory DesperdicioRefeicao.fromJson(Map<String, dynamic> j) =>
      DesperdicioRefeicao(_s(j['tipo']), _s(j['rotulo']), _d(j['kg']));
}

class DispositivosData {
  /// Só o administrador da empresa cria dispositivos, gera tokens e testa leituras e pesagens.
  final bool podeEditar;
  final List<DispositivoIot> dispositivos;
  final List<OpcaoValor> tipos;
  final List<OpcaoValor> refeicoes;
  final List<DesperdicioRefeicao> desperdicioHoje;
  final String data; // yyyy-MM-dd

  const DispositivosData({
    required this.podeEditar,
    required this.dispositivos,
    required this.tipos,
    required this.refeicoes,
    required this.desperdicioHoje,
    required this.data,
  });

  List<DispositivoIot> get catracas => dispositivos.where((d) => !d.ehBalanca).toList();
  List<DispositivoIot> get balancas => dispositivos.where((d) => d.ehBalanca).toList();

  factory DispositivosData.fromJson(Map<String, dynamic> j) => DispositivosData(
        podeEditar: _b(j['podeEditar']),
        dispositivos: _list(j['dispositivos']).map(DispositivoIot.fromJson).toList(),
        tipos: _list(j['tipos']).map(OpcaoValor.fromJson).toList(),
        refeicoes: _list(j['refeicoes']).map(OpcaoValor.fromJson).toList(),
        desperdicioHoje: _list(j['desperdicioHoje']).map(DesperdicioRefeicao.fromJson).toList(),
        data: _s(j['data']),
      );
}

/// Resposta de "Simular leitura": o que a catraca faria com o cartão.
class ResultadoLeitura {
  final bool autorizado;
  final String? direcao; // entrada | saida
  final String? nome;
  final String mensagem;
  final String uid;

  const ResultadoLeitura({required this.autorizado, required this.mensagem, required this.uid, this.direcao, this.nome});

  factory ResultadoLeitura.fromJson(Map<String, dynamic> j) {
    final r = (j['resultado'] as Map<String, dynamic>?) ?? const {};
    return ResultadoLeitura(
      autorizado: _b(r['autorizado']),
      direcao: r['direcao'] as String?,
      nome: r['nome'] as String?,
      mensagem: _s(r['mensagem'], _s(j['mensagem'])),
      uid: _s(j['uid']),
    );
  }
}

// ─── Planilha ──────────────────────────────────────────────────────────────

class ErroImportacao {
  final int linha;
  final String motivo;
  const ErroImportacao(this.linha, this.motivo);
}

/// Resultado de "Importar planilha" em Pessoas → Cadastro.
class ResultadoImportacao {
  final int total;
  final int pessoas;
  final int cartoes;
  final int ignoradas;
  final List<ErroImportacao> erros;

  const ResultadoImportacao({
    required this.total,
    required this.pessoas,
    required this.cartoes,
    required this.ignoradas,
    required this.erros,
  });

  factory ResultadoImportacao.fromJson(Map<String, dynamic> j) => ResultadoImportacao(
        total: _i(j['total']),
        pessoas: _i(j['pessoas']),
        cartoes: _i(j['cartoes']),
        ignoradas: _i(j['ignoradas']),
        erros: _list(j['erros']).map((e) => ErroImportacao(_i(e['linha']), _s(e['motivo']))).toList(),
      );
}

// ─── Tempo real ────────────────────────────────────────────────────────────

/// Um acesso novo nas catracas (vira um aviso rápido na tela).
class EventoAcesso {
  final int id;
  final String direcao; // entrada | saida
  final String resultado; // autorizado | negado
  final String? nome;
  final String hora;

  const EventoAcesso({required this.id, required this.direcao, required this.resultado, required this.hora, this.nome});

  bool get negado => resultado == 'negado';

  factory EventoAcesso.fromJson(Map<String, dynamic> j) => EventoAcesso(
        id: _i(j['id']),
        direcao: _s(j['direcao'], 'entrada'),
        resultado: _s(j['resultado'], 'autorizado'),
        nome: j['nome'] as String?,
        hora: _s(j['hora']),
      );

  /// "Entrada · Maria Souza · 10:32", "Acesso negado · cartão não cadastrado · 10:33"
  String get texto {
    final quem = (nome == null || nome!.trim().isEmpty) ? (negado ? 'cartão não cadastrado' : 'sem nome') : nome!.trim();
    final oQue = negado ? 'Acesso negado' : (direcao == 'saida' ? 'Saída' : 'Entrada');
    return '$oQue · $quem · $hora';
  }
}

/// Resposta de GET /api/aovivo: a assinatura muda sempre que algo na empresa muda.
class EstadoAoVivo {
  final String assinatura;
  final int ultimoLog;
  final List<EventoAcesso> eventos;
  final int novosAcessos;

  const EstadoAoVivo({required this.assinatura, required this.ultimoLog, required this.eventos, required this.novosAcessos});

  factory EstadoAoVivo.fromJson(Map<String, dynamic> j) => EstadoAoVivo(
        assinatura: _s(j['assinatura']),
        ultimoLog: _i(j['ultimoLog']),
        eventos: _list(j['eventos']).map(EventoAcesso.fromJson).toList(),
        novosAcessos: _i(j['novosAcessos']),
      );
}
