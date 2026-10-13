import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';
import 'cadastro_pessoas.dart';

/// Pessoas: quem está no local agora, por grupo (aba "Presentes agora"), e o cadastro de pessoas e cartões (aba "Cadastro").
class PessoasScreen extends StatefulWidget {
  final VoidCallback onMenu;
  final ValueListenable<int> tabRefresh;
  const PessoasScreen({super.key, required this.onMenu, required this.tabRefresh});

  @override
  State<PessoasScreen> createState() => _PessoasScreenState();
}

class _PessoasScreenState extends State<PessoasScreen> with TabRefresh {
  late Future<PessoasData> _future;
  final _busca = TextEditingController();
  String _dataExtenso = '';

  /// 0 = Presentes agora, 1 = Cadastro. O Cadastro só é montado (e só consulta o servidor) na primeira vez que é aberto.
  int _aba = 0;
  bool _cadastroAberto = false;

  @override
  ValueListenable<int> get tabRefresh => widget.tabRefresh;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<PessoasData> _load() async {
    final res = await AppScope.read(context).api.get('/pessoas');
    final data = PessoasData.fromJson(res);
    _dataExtenso = data.dataExtenso;
    return data;
  }

  @override
  void reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  void _selecionarAba(int i) => setState(() {
        _aba = i;
        if (i == 1) _cadastroAberto = true;
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Pessoas',
          subtitle: _aba == 1
              ? 'Cadastro de pessoas e cartões'
              : (_dataExtenso.isEmpty ? 'Quem está no local agora' : _dataExtenso),
          onMenu: widget.onMenu,
        ),
        _AbasPessoas(selecionada: _aba, onSelect: _selecionarAba),
        Expanded(
          child: IndexedStack(
            index: _aba,
            sizing: StackFit.expand,
            children: [
              AsyncBody<PessoasData>(
                future: _future,
                onRefresh: _refresh,
                onRetry: reload,
                builder: (context, d) => ListenableBuilder(
                  listenable: _busca,
                  builder: (context, _) {
                    final termo = _busca.text.trim().toLowerCase();
                    return PageList(children: [
                      CardGrid(children: [for (final c in d.cards) StatCard(c)]),
                      SearchField(controller: _busca, hint: 'Buscar por nome ou função...'),
                      for (final g in d.grupos) _GrupoCard(g, termo),
                    ]);
                  },
                ),
              ),
              if (_cadastroAberto) CadastroPessoasTab(tabRefresh: widget.tabRefresh) else const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Seletor das duas abas da tela: Presentes agora | Cadastro.
class _AbasPessoas extends StatelessWidget {
  final int selecionada;
  final ValueChanged<int> onSelect;
  const _AbasPessoas({required this.selecionada, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;

    Widget aba(int i, IconData icone, String rotulo) {
      final ativa = selecionada == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: ativa,
          child: Material(
            color: ativa ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              key: Key('aba-pessoas-$i'),
              borderRadius: BorderRadius.circular(11),
              onTap: () => onSelect(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icone, size: 18, color: ativa ? Colors.black : pal.textMuted),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        rotulo,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: ativa ? Colors.black : pal.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        // No celular ocupa a largura toda; no PC não estica por uma janela de 1000 pixels.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              children: [
                aba(0, Icons.how_to_reg_rounded, 'Presentes agora'),
                aba(1, Icons.badge_outlined, 'Cadastro'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  final GrupoPessoas grupo;
  final String termo;
  const _GrupoCard(this.grupo, this.termo);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final lista = termo.isEmpty
        ? grupo.pessoas
        : grupo.pessoas
            .where((p) => p.nome.toLowerCase().contains(termo) || p.funcao.toLowerCase().contains(termo))
            .toList();

    // Com busca ativa, esconde grupos sem resultado.
    if (termo.isNotEmpty && lista.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.circular(9)),
                child: Icon(iconeCard(grupo.chave), color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(grupo.titulo, style: AppText.title(context, size: 16))),
              Pill('${grupo.presentes} presentes', background: pal.accentSoft, foreground: AppColors.accentText),
            ],
          ),
          const SizedBox(height: 10),
          if (lista.isEmpty)
            const EmptyNote('Ninguém presente no momento.')
          else
            for (var i = 0; i < lista.length; i++) _PessoaTile(lista[i], kAvatarColors[i % kAvatarColors.length]),
        ],
      ),
    );
  }
}

class _PessoaTile extends StatelessWidget {
  final PessoaPresente pessoa;
  final Color color;
  const _PessoaTile(this.pessoa, this.color);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color,
            child: Text(pessoa.nome.isEmpty ? '?' : pessoa.nome[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pessoa.nome, style: AppText.strong(context, size: 15), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: pal.textMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text('Entrada: ${pessoa.entrada}  ·  ${pessoa.funcao}',
                          overflow: TextOverflow.ellipsis, style: AppText.muted(context, size: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const CircleAvatar(radius: 5, backgroundColor: Color(0xFF22C55E)),
        ],
      ),
    );
  }
}
