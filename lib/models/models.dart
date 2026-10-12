/// Modelos que espelham o JSON da API (SystemFluxe /api/*).
library;

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _i(dynamic v) => _d(v)?.round() ?? 0;

String _s(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();

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

  const Alerta({
    required this.tipo,
    required this.titulo,
    required this.descricao,
    this.data,
    this.rotulo,
  });

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        tipo: _s(j['tipo'], 'info'),
        titulo: _s(j['titulo']),
        descricao: _s(j['descricao']),
        data: j['data'] as String?,
        rotulo: j['rotulo'] as String?,
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
