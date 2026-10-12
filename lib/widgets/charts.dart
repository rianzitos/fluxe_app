import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Escala "redonda" do eixo Y: passo de 1/2/2,5/5/10 (×10ⁿ) com no máximo 5 divisões.
class AxisScale {
  final double max;
  final double interval;
  const AxisScale(this.max, this.interval);
}

AxisScale niceScale(Iterable<double> values) {
  final m = values.fold<double>(0, math.max);
  if (m <= 0) return const AxisScale(1, 0.25);
  final raw = m * 1.08;
  final e = (math.log(raw) / math.ln10).floor() - 1;
  for (var exp = e; exp <= e + 3; exp++) {
    final base = math.pow(10, exp).toDouble();
    for (final f in [1, 2, 2.5, 5]) {
      final step = f * base;
      final divisions = (raw / step).ceil();
      if (divisions <= 5) return AxisScale(divisions * step, step);
    }
  }
  return AxisScale(raw, raw / 4);
}

String _axisLabel(double v) =>
    (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1)).replaceAll('.', ',');

/// Quantos rótulos do eixo X mostrar (evita sobreposição).
int _labelStep(int count, double width) {
  final fit = math.max(2, (width / 44).floor());
  return math.max(1, (count / fit).ceil());
}

FlTitlesData _titles(BuildContext context, List<String> labels, double interval, double width) {
  final muted = context.pal.textMuted;
  final step = _labelStep(labels.length, width);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: interval,
        getTitlesWidget: (v, meta) => Text(_axisLabel(v),
            style: TextStyle(fontSize: 10.5, color: muted)),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.round();
          if (v != i.toDouble() || i < 0 || i >= labels.length || i % step != 0) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(labels[i], style: TextStyle(fontSize: 10.5, color: muted)),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext context, double interval) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (_) => FlLine(color: context.pal.border, strokeWidth: 1),
    );

class _Serie {
  final List<double> values;
  final Color color;
  final bool fill;
  const _Serie(this.values, this.color, {this.fill = false});
}

/// Gráfico de linhas suave com área opcional ("Previsão de Demanda", "Pessoas por Dia").
class LineSeriesChart extends StatelessWidget {
  final List<String> labels;
  final List<double> primary;
  final Color primaryColor;
  final List<double>? secondary;
  final Color? secondaryColor;
  final double height;

  const LineSeriesChart({
    super.key,
    required this.labels,
    required this.primary,
    required this.primaryColor,
    this.secondary,
    this.secondaryColor,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || primary.isEmpty) {
      return SizedBox(
        height: height * 0.5,
        child: Center(child: Text('Sem dados no período', style: AppText.muted(context, size: 13.5))),
      );
    }

    final series = [
      _Serie(primary, primaryColor, fill: true),
      if (secondary != null) _Serie(secondary!, secondaryColor ?? Colors.black),
    ];
    final scale = niceScale(series.expand((s) => s.values));
    final dots = labels.length <= 16;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => LineChart(
          LineChartData(
            minY: 0,
            maxY: scale.max,
            minX: 0,
            maxX: math.max(1, labels.length - 1).toDouble(),
            gridData: _grid(context, scale.interval),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, labels, scale.interval, box.maxWidth),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.blackSoft,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${labels[s.x.round().clamp(0, labels.length - 1)]}: ${_axisLabel(s.y)}',
                      TextStyle(color: s.bar.color ?? Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (final s in series)
                LineChartBarData(
                  spots: [for (var i = 0; i < s.values.length; i++) FlSpot(i.toDouble(), s.values[i])],
                  isCurved: true,
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  color: s.color,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: dots,
                    getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
                      radius: 3.5,
                      color: s.color,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: s.fill,
                    color: s.color.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barras verticais ("Produção Diária", "Desperdício Diário").
class BarSeriesChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color color;
  final double height;

  const BarSeriesChart({
    super.key,
    required this.labels,
    required this.values,
    required this.color,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || values.isEmpty) {
      return SizedBox(
        height: height * 0.5,
        child: Center(child: Text('Sem dados no período', style: AppText.muted(context, size: 13.5))),
      );
    }
    final scale = niceScale(values);
    final barWidth = labels.length > 20 ? 5.0 : (labels.length > 10 ? 9.0 : 14.0);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => BarChart(
          BarChartData(
            minY: 0,
            maxY: scale.max,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(context, scale.interval),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, labels, scale.interval, box.maxWidth),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.blackSoft,
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  'Dia ${labels[group.x]}: ${_axisLabel(rod.toY)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: values[i],
                    color: color,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rosca de distribuição de refeições.
class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double size;

  const DonutChart({super.key, required this.values, required this.colors, this.size = 190});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: size * 0.30,
          startDegreeOffset: -90,
          pieTouchData: PieTouchData(enabled: false),
          sections: [
            for (var i = 0; i < values.length; i++)
              PieChartSectionData(
                value: values[i],
                color: colors[i % colors.length],
                radius: size * 0.2,
                showTitle: false,
              ),
          ],
        ),
      ),
    );
  }
}
