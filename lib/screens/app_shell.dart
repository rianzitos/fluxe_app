import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'producao_screen.dart';
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

/// Produção não tem lugar na barra de abas do celular (lá ela abre por cima, como Configurações). No PC e no
/// tablet deitado ela é uma seção do menu lateral, como no site, e fica nesta posição do IndexedStack.
const _iProducao = 5;
const _nSecoes = 6;

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
  final _ticks = List.generate(_nSecoes, (_) => ValueNotifier<int>(0));
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
    // Em segundo plano (ou com a tela apagada) não consulta nada; ao voltar, consulta na hora. "inactive" não pausa:
    // no PC é só a janela sem foco (o app continua à vista), e no celular passa rápido (ex.: puxar as notificações).
    _emPrimeiroPlano = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
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
    // No chat do Assistente o aviso ficaria em cima do campo de escrever: lá não mostra (o resto segue igual).
    if (!mounted || novos.eventos.isEmpty || _index == 3) return;
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
    } else if (caminho == '/producao') {
      _abrirProducao();
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
      4 => RelatoriosScreen(onMenu: _openMenu, tabRefresh: _ticks[4]),
      _ => ProducaoScreen(onMenu: _openMenu, tabRefresh: _ticks[_iProducao]),
    };
  }

  /// Produção: no PC é uma seção do menu lateral (como no site); no celular abre por cima, como Configurações,
  /// porque não cabe na barra de abas. Ao voltar, a aba aberta (painel, análise) recarrega com os números novos.
  Future<void> _abrirProducao() async {
    if (isWide(context)) {
      _select(_iProducao);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProducaoScreen()));
    if (mounted) _ticks[_index].value++;
  }

  /// Recolhe ou abre o menu lateral do PC (botão « / » ou Ctrl + B, como no site). Fica salvo no aparelho.
  void _alternarMenu() {
    if (!isWide(context)) return;
    _app.setMenuRecolhido(!_app.menuRecolhido);
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
        children: [for (var i = 0; i < _nSecoes; i++) _page(i)],
      ),
    );

    // PC / tablet deitado: menu lateral sempre visível (igual ao painel web), sem barra de abas.
    if (largo) {
      final recolhido = AppScope.of(context).menuRecolhido;
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): _alternarMenu,
          const SingleActivator(LogicalKeyboardKey.keyB, meta: true): _alternarMenu,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: recolhido ? kSidebarRecolhidaWidth : kSidebarWidth,
                  child: ClipRect(
                    child: _SideMenu(
                      fixed: true,
                      recolhido: recolhido,
                      onRecolher: _alternarMenu,
                      selected: _index,
                      onSelect: _select,
                      onConfig: _openConfig,
                      onProducao: _abrirProducao,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: kContentMaxWidth), child: conteudo),
                  ),
                ),
              ],
            ),
          ),
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
        onProducao: () {
          Navigator.of(context).pop();
          _abrirProducao();
        },
      ),
      body: conteudo,
      // Com o teclado aberto (ex.: escrevendo no chat do assistente) a barra de abas sai de cena: sobra espaço
      // para a conversa e o campo de texto fica logo acima do teclado. Também some se a janela do PC estreitar
      // com a Produção aberta (ela não tem aba): o menu ☰ do cabeçalho continua levando a todas as telas.
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0 || _index >= _destinos.length ? null : NavigationBar(
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

/// Menu lateral escuro, com os itens na ordem do menu do site: Painel, Análise mensal, Produção, Pessoas,
/// Assistente, Relatórios e Configurações. No PC ([fixed]) pode ser recolhido para uma faixa só com os ícones.
class _SideMenu extends StatelessWidget {
  /// true = painel fixo ao lado do conteúdo (PC); false = menu deslizante (celular).
  final bool fixed;

  /// Só os ícones (PC): o nome aparece ao passar o mouse ou segurar o dedo, como no site.
  final bool recolhido;
  final VoidCallback? onRecolher;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfig;
  final VoidCallback onProducao;

  const _SideMenu({
    this.fixed = false,
    this.recolhido = false,
    this.onRecolher,
    required this.selected,
    required this.onSelect,
    required this.onConfig,
    required this.onProducao,
  });

  @override
  Widget build(BuildContext context) {
    Widget painel(Widget child) => fixed
        ? ColoredBox(color: AppColors.black, child: child)
        : Drawer(backgroundColor: AppColors.black, shape: const RoundedRectangleBorder(), child: child);

    // Compacto pela largura real (e não só pela escolha): durante a animação de abrir, o menu ainda estreito
    // continua com o desenho compacto, sem nada cortado.
    return painel(SafeArea(
      child: LayoutBuilder(
        builder: (context, c) => _conteudo(context, compacto: fixed && (recolhido || c.maxWidth < 200)),
      ),
    ));
  }

  Widget _conteudo(BuildContext context, {required bool compacto}) {
    final app = AppScope.of(context);
    final user = app.user;

    Widget item(String label, IconData icon, {required bool active, required VoidCallback onTap, Key? key}) =>
        _MenuItem(key: key, label: label, icon: icon, active: active, compacto: compacto, onTap: onTap);

    final itens = <Widget>[
      for (var i = 0; i < _destinos.length; i++) ...[
        item(_destinos[i].label, _destinos[i].iconSelected, active: i == selected, onTap: () => onSelect(i)),
        // Mesma ordem do menu do site: Painel, Análise mensal, Produção, Pessoas...
        if (i == 1)
          item('Produção', Icons.restaurant_rounded,
              key: const Key('menu-producao'), active: selected == _iProducao, onTap: onProducao),
      ],
      item('Configurações', Icons.settings_rounded, active: false, onTap: onConfig),
    ];

    final botaoRecolher = onRecolher == null
        ? null
        : IconButton(
            key: const Key('btn-recolher-menu'),
            tooltip: compacto ? 'Abrir menu (Ctrl + B)' : 'Recolher menu (Ctrl + B)',
            onPressed: onRecolher,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C21),
              foregroundColor: const Color(0xFFB0B0B8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(compacto ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
                size: 20),
          );

    final sair = IconButton(
      tooltip: 'Sair',
      onPressed: () async {
        final ok = await confirmLogout(context);
        if (ok && context.mounted) {
          if (!fixed) Navigator.of(context).pop(); // fecha o menu deslizante
          await app.logout();
        }
      },
      icon: const Icon(Icons.logout_rounded, color: Color(0xFFB0B0B8)),
    );

    // Tocar na foto ou no nome abre Configurações → Perfil, como no site.
    final perfil = InkWell(
      key: const Key('menu-perfil'),
      borderRadius: BorderRadius.circular(12),
      onTap: onConfig,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: compacto
            ? UserAvatar(user?.nome ?? '', user?.foto, radius: 20)
            : Row(
                children: [
                  UserAvatar(user?.nome ?? '', user?.foto, radius: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.nome ?? '',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(user?.perfilRotulo ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF9A9AA3), fontSize: 12.5)),
                            ),
                            const SizedBox(width: 6),
                            const CircleAvatar(radius: 3, backgroundColor: Color(0xFF22C55E)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );

    return Column(
      children: [
        if (compacto)
          Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 16), child: Center(child: botaoRecolher))
        else
          Padding(
            padding: EdgeInsets.fromLTRB(24, 28, botaoRecolher == null ? 24 : 12, 20),
            child: Row(
              children: [
                const Expanded(child: Align(alignment: Alignment.centerLeft, child: SicapdaLogo(width: 196))),
                if (botaoRecolher != null) ...[const SizedBox(width: 8), botaoRecolher],
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: compacto ? 12 : 14),
            children: itens,
          ),
        ),
        const Divider(color: Color(0xFF26262B), height: 1),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compacto ? 8 : 12, vertical: compacto ? 12 : 12),
          child: compacto
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: user?.nome ?? 'Meu perfil',
                      excludeFromSemantics: true,
                      child: Semantics(
                        button: true,
                        label: 'Meu perfil${user == null ? '' : ' (${user.nome})'}',
                        onTap: onConfig,
                        excludeSemantics: true,
                        child: perfil,
                      ),
                    ),
                    const SizedBox(height: 6),
                    sair,
                  ],
                )
              : Row(children: [Expanded(child: perfil), sair]),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool compacto;
  final VoidCallback onTap;

  const _MenuItem({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = active ? AppColors.accent : const Color(0xFFD4D4D8);
    final botao = Material(
      color: active ? const Color(0xFF2A2210) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: compacto
              ? const EdgeInsets.symmetric(vertical: 14)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: compacto
              ? Center(child: Icon(icon, size: 22, color: cor))
              : Row(
                  children: [
                    Icon(icon, size: 21, color: cor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                            color: cor,
                          )),
                    ),
                  ],
                ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      // Recolhido só aparece o ícone: o nome vai na dica (mouse) e para o leitor de tela, como um botão.
      child: compacto
          ? Tooltip(
              message: label,
              preferBelow: false,
              waitDuration: const Duration(milliseconds: 250),
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                selected: active,
                label: label,
                onTap: onTap,
                excludeSemantics: true,
                child: botao,
              ),
            )
          : botao,
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
