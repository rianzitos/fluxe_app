import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../widgets/sicapda_logo.dart';
import 'analise_screen.dart';
import 'assistente_screen.dart';
import 'configuracoes_screen.dart';
import 'painel_screen.dart';
import 'pessoas_screen.dart';
import 'relatorios_screen.dart';

class _Destino {
  final String label;
  final IconData icon;
  final IconData iconSelected;
  const _Destino(this.label, this.icon, this.iconSelected);
}

const _destinos = [
  _Destino('Painel', Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded),
  _Destino('Análise mensal', Icons.calendar_today_outlined, Icons.calendar_today_rounded),
  _Destino('Pessoas', Icons.people_outline_rounded, Icons.people_alt_rounded),
  _Destino('Assistente IA', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  _Destino('Relatórios', Icons.assessment_outlined, Icons.assessment_rounded),
];

/// Estrutura principal: menu lateral escuro (igual à sidebar da web) + barra de abas.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _visited = <int>{0};
  final _ticks = List.generate(_destinos.length, (_) => ValueNotifier<int>(0));
  int _index = 0;

  @override
  void dispose() {
    for (final t in _ticks) {
      t.dispose();
    }
    super.dispose();
  }

  void _select(int i) {
    setState(() {
      // Voltar para uma aba já aberta recarrega os dados (ex.: quem está presente agora).
      if (_visited.contains(i)) _ticks[i].value++;
      _visited.add(i);
      _index = i;
    });
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  Widget _page(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    return switch (i) {
      0 => PainelScreen(onMenu: _openMenu, tabRefresh: _ticks[0]),
      1 => AnaliseScreen(onMenu: _openMenu, tabRefresh: _ticks[1]),
      2 => PessoasScreen(onMenu: _openMenu, tabRefresh: _ticks[2]),
      3 => AssistenteScreen(onMenu: _openMenu),
      _ => RelatoriosScreen(onMenu: _openMenu, tabRefresh: _ticks[4]),
    };
  }

  void _openConfig() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConfiguracoesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = SafeArea(
      bottom: false,
      child: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _destinos.length; i++) _page(i)],
      ),
    );

    // PC / tablet deitado: menu lateral sempre visível (igual ao painel web), sem barra de abas.
    if (isWide(context)) {
      return Scaffold(
        key: _scaffoldKey,
        body: Row(
          children: [
            SizedBox(
              width: kSidebarWidth,
              child: _SideMenu(fixed: true, selected: _index, onSelect: _select, onConfig: _openConfig),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kContentMaxWidth), child: conteudo),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _SideMenu(
        selected: _index,
        onSelect: (i) {
          Navigator.of(context).pop();
          _select(i);
        },
        onConfig: () {
          Navigator.of(context).pop();
          _openConfig();
        },
      ),
      body: conteudo,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 66,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinos)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.iconSelected),
              label: switch (d.label) {
                'Análise mensal' => 'Análise',
                'Assistente IA' => 'IA',
                final l => l,
              },
            ),
        ],
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  /// true = painel fixo ao lado do conteúdo (PC); false = menu deslizante (celular).
  final bool fixed;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfig;

  const _SideMenu({this.fixed = false, required this.selected, required this.onSelect, required this.onConfig});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final user = app.user;

    Widget painel(Widget child) => fixed
        ? ColoredBox(color: AppColors.black, child: child)
        : Drawer(backgroundColor: AppColors.black, shape: const RoundedRectangleBorder(), child: child);

    return painel(
      SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Align(alignment: Alignment.centerLeft, child: SicapdaLogo(width: 196)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (var i = 0; i < _destinos.length; i++)
                    _MenuItem(
                      label: _destinos[i].label,
                      icon: _destinos[i].iconSelected,
                      active: i == selected,
                      onTap: () => onSelect(i),
                    ),
                  _MenuItem(
                    label: 'Configurações',
                    icon: Icons.settings_rounded,
                    active: false,
                    onTap: onConfig,
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF26262B), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  UserAvatar(user?.nome ?? '', user?.foto, radius: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nome ?? '',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(user?.perfilRotulo ?? '',
                                style: const TextStyle(color: Color(0xFF9A9AA3), fontSize: 12.5)),
                            const SizedBox(width: 6),
                            const CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sair',
                    onPressed: () async {
                      final ok = await confirmLogout(context);
                      if (ok && context.mounted) {
                        if (!fixed) Navigator.of(context).pop(); // fecha o menu deslizante
                        await app.logout();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFB0B0B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MenuItem({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? const Color(0xFF2A2210) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 21, color: active ? AppColors.accent : const Color(0xFFD4D4D8)),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? AppColors.accent : const Color(0xFFD4D4D8),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto do usuário (se houver) ou iniciais sobre fundo amarelo.
class UserAvatar extends StatelessWidget {
  final String nome;
  final String? foto;
  final double radius;
  const UserAvatar(this.nome, this.foto, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent,
      child: Text(inicial,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: radius * 0.85)),
    );
    if (foto == null || foto!.isEmpty) return fallback;

    return ClipOval(
      child: Image.network(
        foto!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

Future<bool> confirmLogout(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sair do SICAPDA?'),
      content: const Text('Você precisará entrar novamente para acessar os dados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.black),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  return r ?? false;
}
