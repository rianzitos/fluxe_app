import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

/// Pessoas: quem está no local agora, por grupo.
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Pessoas',
          subtitle: _dataExtenso.isEmpty ? 'Quem está no local agora' : _dataExtenso,
          onMenu: widget.onMenu,
        ),
        Expanded(
          child: AsyncBody<PessoasData>(
            future: _future,
            onRefresh: _refresh,
            onRetry: reload,
            builder: (context, d) => ListenableBuilder(
              listenable: _busca,
              builder: (context, _) {
                final termo = _busca.text.trim().toLowerCase();
                return PageList(children: [
                  CardGrid(children: [for (final c in d.cards) StatCard(c)]),
                  _SearchField(controller: _busca),
                  for (final g in d.grupos) _GrupoCard(g, termo),
                ]);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: pal.text, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: 'Buscar por nome ou função...',
        hintStyle: TextStyle(color: pal.textMuted, fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: pal.textMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, color: pal.textMuted, size: 20),
                onPressed: controller.clear,
              ),
        filled: true,
        fillColor: pal.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: pal.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: pal.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent, width: 1.4)),
      ),
    );
  }
}

const _avatarColors = [AppColors.purple, AppColors.black, Color(0xFFD97706), Color(0xFF0E9F6E), Color(0xFF2563EB)];

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
            for (var i = 0; i < lista.length; i++) _PessoaTile(lista[i], _avatarColors[i % _avatarColors.length]),
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
