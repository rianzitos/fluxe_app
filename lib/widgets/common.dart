import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Card branco com cantos arredondados (".painel-card" da web).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? pal.card,
        borderRadius: BorderRadius.circular(16),
        border: dark ? Border.all(color: pal.border) : null,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(color: Color(0x0A101114), blurRadius: 2, offset: Offset(0, 1)),
                BoxShadow(color: Color(0x0D101114), blurRadius: 24, offset: Offset(0, 8)),
              ],
      ),
      child: child,
    );
  }
}

/// Quadrado amarelo com ícone preto (ícone dos cards da web).
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconTile(this.icon, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(icon, color: Colors.black, size: size * 0.5),
      );
}

/// Ícone de cada card de resumo, pela "chave" devolvida pela API.
IconData iconeCard(String chave) => switch (chave) {
      'usuarios' => Icons.person_rounded,
      'acessos' => Icons.meeting_room_rounded,
      'refeicoes' => Icons.coffee_rounded,
      'acuracia' => Icons.show_chart_rounded,
      'produzido' => Icons.trending_up_rounded,
      'desperdicado' => Icons.trending_down_rounded,
      'pessoas' => Icons.groups_rounded,
      'total' => Icons.groups_rounded,
      'operadores' => Icons.settings_rounded,
      'supervisores' => Icons.how_to_reg_rounded,
      'prestadores' => Icons.work_rounded,
      'rel_total' => Icons.assignment_rounded,
      'rel_hoje' => Icons.today_rounded,
      'rel_duracao' => Icons.schedule_rounded,
      'rel_pico' => Icons.bolt_rounded,
      _ => Icons.insights_rounded,
    };

/// Card de indicador: ícone, rótulo, valor grande e variação.
class StatCard extends StatelessWidget {
  final CardResumo data;
  const StatCard(this.data, {super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final v = data.variacao;
    final good = data.positiva ?? ((v ?? 0) >= 0);
    final color = good ? AppColors.success : AppColors.red;
    final valor = data.valorTexto ?? (data.valor == null ? '—' : '${fmtValor(data.valor!)}${data.sufixo}');

    Widget? footer;
    if (v != null) {
      footer = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 2,
        children: [
          Icon(v >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 15, color: color),
          Text(fmtVariacao(v), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
          if (data.periodo != null) Text(data.periodo!, style: AppText.muted(context, size: 12)),
        ],
      );
    } else if (data.periodo != null) {
      footer = Text('Sem base de comparação', style: AppText.muted(context, size: 12));
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(iconeCard(data.chave), size: 42),
          const SizedBox(height: 14),
          Text(data.label, style: AppText.muted(context, size: 12.5)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: AppText.value(context, size: 28)),
          ),
          if (footer != null) ...[const SizedBox(height: 6), footer],
          if (data.extra != null) ...[
            const SizedBox(height: 4),
            Text(data.extra!, style: TextStyle(fontSize: 12, color: pal.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Dispõe cards em colunas de mesma altura; o último de uma linha ímpar ocupa a linha toda.
class CardGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;

  const CardGrid({super.key, required this.children, this.columns = 2, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(i, (i + columns).clamp(0, children.length));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < slice.length; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              Expanded(child: slice[j]),
            ],
          ],
        ),
      ));
      if (i + columns < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(children: rows);
  }
}

/// Título de seção dentro de um card.
class CardTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const CardTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(text, style: AppText.title(context, size: 16))),
          ?trailing,
        ],
      );
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot(this.color, this.label, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.muted(context, size: 12)),
        ],
      );
}

/// Chip pequeno (categoria, status...).
class Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  const Pill(this.text, {super.key, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(color: foreground, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = error is ApiException ? (error as ApiException).message : 'Algo deu errado. Tente novamente.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: context.pal.textMuted),
            const SizedBox(height: 14),
            Text(msg, textAlign: TextAlign.center, style: AppText.muted(context, size: 14)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: AppText.muted(context, size: 13.5)),
      );
}

/// Carrega um Future e mostra loading / erro / conteúdo, com pull-to-refresh.
/// Ao recarregar, mantém o conteúdo anterior na tela (só mostra uma barra de progresso).
class AsyncBody<T> extends StatelessWidget {
  final Future<T>? future;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  const AsyncBody({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError && !snap.hasData) return ErrorState(error: snap.error!, onRetry: onRetry);
        if (!snap.hasData) return const LoadingState();
        final loading = snap.connectionState != ConnectionState.done;
        return Stack(
          children: [
            RefreshIndicator(
              color: Colors.black,
              backgroundColor: AppColors.accent,
              onRefresh: onRefresh,
              child: builder(context, snap.data as T),
            ),
            if (loading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.accent, backgroundColor: Colors.transparent),
              ),
          ],
        );
      },
    );
  }
}

/// Faz a tela recarregar quando o usuário volta para a aba (ver AppShell).
mixin TabRefresh<T extends StatefulWidget> on State<T> {
  ValueListenable<int> get tabRefresh;
  void reload();

  @override
  void initState() {
    super.initState();
    tabRefresh.addListener(reload);
  }

  @override
  void dispose() {
    tabRefresh.removeListener(reload);
    super.dispose();
  }
}

/// ScrollView padrão das telas (sempre rolável para o pull-to-refresh funcionar).
class PageList extends StatelessWidget {
  final List<Widget> children;
  const PageList({super.key, required this.children});

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      );
}

Color corHex(String hex, {Color fallback = AppColors.accent}) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// No tema escuro, troca o preto (que sumiria no card) por um cinza bem claro.
Color adaptiveInk(BuildContext context, Color color) =>
    Theme.of(context).brightness == Brightness.dark && color.computeLuminance() < 0.05
        ? const Color(0xFFF4F4F6)
        : color;
