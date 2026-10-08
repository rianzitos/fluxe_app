import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Cabeçalho das telas: menu, título + subtítulo, ações e sino de alertas.
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
          if (showBell) ...[const SizedBox(width: 8), const AlertBell()],
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
      onTap: () => showAlertsSheet(context, alertas),
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
  const AlertTile(this.alerta, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = estiloAlerta(context, alerta.tipo);
    return Container(
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
        ],
      ),
    );
  }
}

void showAlertsSheet(BuildContext context, List<Alerta> alertas) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.pal.background,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text('Alertas e Recomendações', style: AppText.title(ctx, size: 18)),
            const SizedBox(height: 14),
            if (alertas.isEmpty)
              Text('Nenhum alerta no momento. Tudo dentro do esperado.', style: AppText.muted(ctx, size: 14))
            else
              for (final a in alertas) ...[AlertTile(a), const SizedBox(height: 10)],
          ],
        ),
      ),
    ),
  );
}
