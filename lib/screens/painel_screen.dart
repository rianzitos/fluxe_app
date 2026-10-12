import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

/// Painel Geral: indicadores, previsão de demanda, distribuição e alertas.
class PainelScreen extends StatefulWidget {
  final VoidCallback onMenu;
  final ValueListenable<int> tabRefresh;
  const PainelScreen({super.key, required this.onMenu, required this.tabRefresh});

  @override
  State<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends State<PainelScreen> with TabRefresh {
  late Future<PainelData> _future;

  @override
  ValueListenable<int> get tabRefresh => widget.tabRefresh;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PainelData> _load() async {
    final app = AppScope.read(context);
    final res = await app.api.get('/painel');
    final data = PainelData.fromJson(res);
    app.setAlertas(data.alertas);
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
          title: 'Painel Geral',
          subtitle: 'Visão geral do sistema',
          onMenu: widget.onMenu,
        ),
        Expanded(
          child: AsyncBody<PainelData>(
            future: _future,
            onRefresh: _refresh,
            onRetry: reload,
            builder: (context, d) => PageList(children: [
              _PeriodChip(d.mesReferencia),
              CardGrid(children: [for (final c in d.cards) StatCard(c)]),
              _DemandCard(d.demanda),
              _DistribuicaoCard(d.distribuicao),
              _ProximasHorasCard(d.proximasHoras),
              _AlertasCard(d.alertas),
            ]),
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String mes;
  const _PeriodChip(this.mes);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: pal.textMuted),
            const SizedBox(width: 8),
            Text(mes.isEmpty ? 'Mês atual' : mes, style: AppText.strong(context, size: 13.5)),
          ],
        ),
      ),
    );
  }
}

class _DemandCard extends StatelessWidget {
  final SerieDemanda serie;
  const _DemandCard(this.serie);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Previsão de Demanda'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            children: [
              const LegendDot(AppColors.accent, 'Previsto (em KG)'),
              LegendDot(adaptiveInk(context, AppColors.black), 'Realizado (em KG)'),
            ],
          ),
          const SizedBox(height: 18),
          LineSeriesChart(
            labels: serie.labels,
            primary: serie.previsto,
            primaryColor: AppColors.accent,
            secondary: serie.realizado,
            secondaryColor: adaptiveInk(context, AppColors.black),
          ),
        ],
      ),
    );
  }
}

class _DistribuicaoCard extends StatelessWidget {
  final List<FatiaRefeicao> fatias;
  const _DistribuicaoCard(this.fatias);

  @override
  Widget build(BuildContext context) {
    final cores = [for (final f in fatias) adaptiveInk(context, corHex(f.cor))];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Distribuição de Refeições'),
          const SizedBox(height: 16),
          if (fatias.isEmpty)
            const EmptyNote('Sem dados de produção ou metas de refeições cadastradas.')
          else ...[
            Center(child: DonutChart(values: [for (final f in fatias) f.percentual], colors: cores)),
            const SizedBox(height: 18),
            for (var i = 0; i < fatias.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: cores[i], shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(fatias[i].label, style: AppText.strong(context, size: 14))),
                    Text('${fmtNum(fatias[i].percentual)}%', style: AppText.muted(context, size: 14)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProximasHorasCard extends StatelessWidget {
  final List<HoraPrevista> horas;
  const _ProximasHorasCard(this.horas);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Previsão · Próximas Horas'),
          const SizedBox(height: 10),
          if (horas.isEmpty)
            const EmptyNote('Sem movimento previsto para as próximas horas (fora do expediente ou sem histórico suficiente).')
          else
            for (final h in horas)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Text(h.hora, style: AppText.title(context, size: 15)),
                    const SizedBox(width: 14),
                    _StatusPill(h.status),
                    const Spacer(),
                    Text('${h.pessoas} pessoas', style: AppText.muted(context, size: 13.5)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final (bg, fg) = switch (status) {
      'alto' => (pal.warningBg, AppColors.warning),
      'baixo' => (pal.card, pal.textMuted),
      _ => (pal.successBg, AppColors.success),
    };
    final text = status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1);
    return Pill(text, background: bg, foreground: fg);
  }
}

class _AlertasCard extends StatelessWidget {
  final List<Alerta> alertas;
  const _AlertasCard(this.alertas);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Alertas e Recomendações'),
          const SizedBox(height: 12),
          if (alertas.isEmpty)
            const EmptyNote('Nenhum alerta no momento. Tudo dentro do esperado.')
          else
            for (final a in alertas) ...[
              AlertTile(a),
              if (a != alertas.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
