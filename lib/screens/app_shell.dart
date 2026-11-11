import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/navegacao.dart';
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
///
/// Também liga o tempo real (como o "Ao vivo" do site): enquanto o app está aberto na tela, a aba visível se
/// atualiza sozinha quando algo muda na empresa, o sino acompanha e os acessos novos aparecem num aviso rápido.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _visited = <int>{0};
  final _ticks = List.generate(_destinos.length, (_) => ValueNotifier<int>(0));
  int _index = 0;

  late final AppController _app = AppScope.read(context);
  StreamSubscription<({List<EventoAcesso> eventos, int total})>? _avisos;
  bool _emPrimeiroPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _app.addListener(_sincronizarAoVivo);
    _app.aoVivo.mudancas.addListener(_algoMudou);
    _avisos = _app.aoVivo.eventos.listen(_avisarAcessos);
    _sincronizarAoVivo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _app.removeListener(_sincronizarAoVivo);
    _app.aoVivo.mudancas.removeListener(_algoMudou);
    _avisos?.cancel();
    _app.aoVivo.pausar();
    for (final t in _ticks) {
      t.dispose();
    }
    super.dispose();
  }

  // ─── Tempo real ────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Em segundo plano (ou com a tela apagada) não consulta nada; ao voltar, consulta na hora.
    _emPrimeiroPlano = state == AppLifecycleState.resumed;
    _sincronizarAoVivo();
  }

  /// Liga ou desliga as consultas conforme a preferência (Configurações → Sistema) e o app estar na tela.
  void _sincronizarAoVivo() {
    final aoVivo = _app.aoVivo;
    if (_app.aoVivoAtivo && _emPrimeiroPlano && _app.isLoggedIn) {
      aoVivo.retomar();
    } else {
      aoVivo.pausar();
    }
  }

  /// Algo mudou na empresa: atualiza a aba visível (as outras se atualizam ao serem abertas) e o sino.
  void _algoMudou() {
    if (!mounted) return;
    _ticks[_index].value++;
    _app.atualizarAlertas();
  }

  void _avisarAcessos(({List<EventoAcesso> eventos, int total}) novos) {
    if (!mounted || novos.eventos.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ultimo = novos.eventos.last;
    final outros = novos.total - 1;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Icon(
            ultimo.negado ? Icons.block_rounded : (ultimo.direcao == 'saida' ? Icons.logout_rounded : Icons.login_rounded),
            color: ultimo.negado ? const Color(0xFFFCA5A5) : AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(outros > 0 ? '${ultimo.texto} (+$outros ${outros == 1 ? 'acesso' : 'acessos'})' : ultimo.texto),
          ),
        ],
      ),
      action: SnackBarAction(
        label: 'Ver',
        textColor: AppColors.accent,
        onPressed: () => _abrirLink(ultimo.negado ? '/relatorios' : '/pessoas'),
      ),
    ));
  }

  // ─── Navegação ─────────────────────────────────────────────────────────

  /// Destino de um alerta, no formato do site ("/relatorios", "/configuracoes#integracoes"...).
  void _abrirLink(String link) {
    final caminho = link.split('#').first.split('?').first;
    final aba = switch (caminho) {
      '/painel' => 0,
      '/acessos' => 1,
      '/pessoas' => 2,
      '/assistente' => 3,
      '/relatorios' => 4,
      _ => null,
    };
    if (aba != null) {
      _select(aba);
    } else if (caminho == '/configuracoes') {
      _openConfig(abaDoLink(link));
    }
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

  void _openConfig([AbaConfig aba = AbaConfig.perfil]) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ConfiguracoesScreen(abaInicial: aba)));
  }

  @override
  Widget build(BuildContext context) => ShellNavegacao(
        abrirLink: _abrirLink,
        abrirConfiguracoes: _openConfig,
        child: _estrutura(context),
      );

  Widget _estrutura(BuildContext context) {
    final largo = isWide(context);
    final conteudo = SafeArea(
      // No celular a barra de abas fica embaixo e já respeita a barra do sistema. Sem ela (PC, tablet ou celular
      // deitado), o conteúdo não pode ir até a borda: o campo do chat ficaria embaixo da barra de navegação do Android.
      bottom: largo,
      child: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _destinos.length; i++) _page(i)],
      ),
    );

    // PC / tablet deitado: menu lateral sempre visível (igual ao painel web), sem barra de abas.
    if (largo) {
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
      // Com o teclado aberto (ex.: escrevendo no chat do assistente) a barra de abas sai de cena: sobra espaço
      // para a conversa e o campo de texto fica logo acima do teclado.
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0 ? null : NavigationBar(
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
