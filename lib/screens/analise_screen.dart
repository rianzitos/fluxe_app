import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/page_header.dart';

/// Análise Mensal: totais do mês, gráficos diários e insights.
class AnaliseScreen extends StatefulWidget {
  final VoidCallback onMenu;
  final ValueListenable<int> tabRefresh;
  const AnaliseScreen({super.key, required this.onMenu, required this.tabRefresh});

  @override
  State<AnaliseScreen> createState() => _AnaliseScreenState();
}

class _AnaliseScreenState extends State<AnaliseScreen> with TabRefresh {
  late Future<AnaliseData> _future;
  String _mes = ''; // vazio = mês atual
  List<MesOpcao> _meses = const [];
  String _rotulo = '';

  @override
  ValueListenable<int> get tabRefresh => widget.tabRefresh;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AnaliseData> _load() async {
    final res = await AppScope.read(context).api.get('/analise-mensal', query: {'mes': _mes});
    final data = AnaliseData.fromJson(res);
    _meses = data.meses;
    _mes = data.mes;
    if (mounted) setState(() => _rotulo = data.mesRotulo);
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

  Future<void> _pickMonth() async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.pal.background,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Selecionar mês', style: AppText.title(ctx, size: 18)),
            const SizedBox(height: 8),
            for (final m in _meses)
              ListTile(
                title: Text(m.rotulo, style: AppText.strong(ctx, size: 15)),
                trailing: m.valor == _mes ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
                onTap: () => Navigator.pop(ctx, m.valor),
              ),
          ],
        ),
      ),
    );
    if (escolhido != null && escolhido != _mes) {
      _mes = escolhido;
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: 'Análise Mensal',
          subtitle: _rotulo.isEmpty ? 'Carregando…' : _rotulo,
          onMenu: widget.onMenu,
        ),
        Expanded(
          child: AsyncBody<AnaliseData>(
            future: _future,
            onRefresh: _refresh,
            onRetry: reload,
            builder: (context, d) => PageList(children: [
              _MonthButton(label: d.mesRotulo, onTap: _pickMonth),
              CardGrid(children: [for (final c in d.cards) StatCard(c)]),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('Número de Pessoas por Dia'),
                    const SizedBox(height: 16),
                    LineSeriesChart(
                      labels: d.pessoasDia.labels,
                      primary: d.pessoasDia.valores,
                      primaryColor: AppColors.accent,
                    ),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('Produção Diária (kg)'),
                    const SizedBox(height: 16),
                    BarSeriesChart(labels: d.producao.labels, values: d.producao.valores, color: AppColors.purple),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('Desperdício Diário (kg)'),
                    const SizedBox(height: 16),
                    BarSeriesChart(labels: d.desperdicio.labels, values: d.desperdicio.valores, color: AppColors.red),
                  ],
                ),
              ),
              _InsightsCard(d.insights),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MonthButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: pal.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: pal.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: pal.textMuted),
                const SizedBox(width: 8),
                Text(label, style: AppText.strong(context, size: 13.5)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: pal.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<Insight> insights;
  const _InsightsCard(this.insights);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle('Insights do Mês'),
          const SizedBox(height: 12),
          for (final i in insights)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: pal.chip, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  IconTile(i.icone == 'pulse' ? Icons.monitor_heart_outlined : Icons.trending_up_rounded, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.label, style: AppText.muted(context, size: 12.5)),
                        const SizedBox(height: 2),
                        Text(i.valor, style: AppText.strong(context, size: 15)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
