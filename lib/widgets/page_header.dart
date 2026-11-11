import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'navegacao.dart';

/// Cabeçalho das telas: menu, título + subtítulo, ações, atalho dos dispositivos IoT e sino de alertas
/// (os atalhos do canto direito do cabeçalho do site).
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMenu;
  final List<Widget> actions;
  final bool showBell;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onMenu,
    this.actions = const [],
    this.showBell = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          if (onMenu != null && isWide(context))
            const SizedBox(width: 4) // menu lateral fixo: não precisa do botão (alinha com os cartões)
          else if (onMenu != null)
            IconButton(
              tooltip: 'Menu',
              onPressed: onMenu,
              icon: Icon(Icons.menu_rounded, color: pal.text),
            )
          else
            IconButton(
              tooltip: 'Voltar',
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.arrow_back_rounded, color: pal.text),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(context, size: 22), overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.muted(context), overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          ...actions,
          if (showBell && ShellNavegacao.maybeOf(context) != null) const IotAtalho(),
          if (showBell) ...[const SizedBox(width: 4), const AlertBell()],
        ],
      ),
    );
  }
}

/// Sino com a contagem de alertas; abre a lista de alertas e recomendações.
class AlertBell extends StatelessWidget {
  const AlertBell({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final alertas = AppScope.of(context).alertas;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => abrirNotificacoes(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pal.card,
              shape: BoxShape.circle,
              border: Border.all(color: pal.border),
            ),
            child: Icon(Icons.notifications_none_rounded, color: pal.text, size: 22),
          ),
          if (alertas.isNotEmpty)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: Text('${alertas.length}',
                    style: const TextStyle(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

({Color fg, Color bg, IconData icon}) estiloAlerta(BuildContext context, String tipo) {
  final pal = context.pal;
  return switch (tipo) {
    'sucesso' => (fg: AppColors.success, bg: pal.successBg, icon: Icons.trending_up_rounded),
    'aviso' => (fg: AppColors.warning, bg: pal.warningBg, icon: Icons.warning_amber_rounded),
    _ => (fg: AppColors.info, bg: pal.infoBg, icon: Icons.monitor_heart_outlined),
  };
}

/// Item de alerta colorido (Painel e lista do sino).
class AlertTile extends StatelessWidget {
  final Alerta alerta;

  /// Leva para a tela do assunto (sino); null = só mostra (lista do Painel).
  final VoidCallback? onTap;
  const AlertTile(this.alerta, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = estiloAlerta(context, alerta.tipo);
    final conteudo = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, color: s.fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alerta.titulo, style: AppText.strong(context, size: 14)),
                const SizedBox(height: 2),
                Text(alerta.descricao, style: AppText.muted(context, size: 13)),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: context.pal.textMuted, size: 20),
          ],
        ],
      ),
    );
    if (onTap == null) return conteudo;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: conteudo),
    );
  }
}

/// Atalho "IoT" do cabeçalho (como no site): abre Configurações direto na aba Integrações.
class IotAtalho extends StatelessWidget {
  const IotAtalho({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Dispositivos IoT (catracas e balanças)',
        onPressed: () => ShellNavegacao.maybeOf(context)?.abrirConfiguracoes(AbaConfig.integracoes),
        icon: Icon(Icons.sensors_rounded, color: context.pal.text),
      );
}

/// Painel do sino: os alertas do servidor (previsão + catracas, conforme as preferências da conta). Tocar num
/// alerta leva para a tela onde o assunto é tratado, como no site.
void abrirNotificacoes(BuildContext context) {
  final app = AppScope.read(context);
  final nav = ShellNavegacao.maybeOf(context);
  final atualizando = app.atualizarAlertas();

  void ir(BuildContext ctx, VoidCallback acao) {
    Navigator.pop(ctx);
    acao();
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.pal.background,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        child: FutureBuilder<List<Alerta>>(
          future: atualizando,
          initialData: app.alertas,
          builder: (ctx, snap) {
            final alertas = snap.data ?? const <Alerta>[];
            final carregando = snap.connectionState != ConnectionState.done;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Notificações', style: AppText.title(ctx, size: 18))),
                    if (nav != null)
                      TextButton.icon(
                        onPressed: () => ir(ctx, () => nav.abrirConfiguracoes(AbaConfig.notificacoes)),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: const Text('Preferências'),
                      ),
                  ],
                ),
                if (carregando) const LinearProgressIndicator(minHeight: 2, color: AppColors.accent, backgroundColor: Colors.transparent),
                const SizedBox(height: 10),
                if (alertas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(carregando ? 'Carregando alertas…' : 'Nenhum alerta no momento. Tudo dentro do esperado.',
                        style: AppText.muted(ctx, size: 14)),
                  )
                else
                  for (final a in alertas) ...[
                    AlertTile(
                      a,
                      onTap: nav == null ? null : () => ir(ctx, () => nav.abrirLink(a.link ?? '/assistente')),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (nav != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => ir(ctx, () => nav.abrirLink('/assistente')),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Ver recomendações do assistente'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
