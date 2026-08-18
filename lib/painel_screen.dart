import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'main.dart'; // reaproveita a paleta AppColors já usada no login

// =======================================================
// Cores extras usadas só nesta tela (cards claros, gráficos, positivo)
// =======================================================
class _PainelColors {
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardText = Color(0xFF1A1A1A);
  static const Color cardTextMuted = Color(0xFF6E6E6E);
  static const Color positive = Color(0xFF1FAE5A);
  static const Color chartGray = Color(0xFFBDBDBD);
  static const Color chartGrayLight = Color(0xFFE0E0E0);
}

// =======================================================
// Dados mockados — trocar depois pela API real do SICAPDA
// =======================================================
class _Indicator {
  final IconData icon;
  final String label;
  final String value;
  final String growth;
  const _Indicator(this.icon, this.label, this.value, this.growth);
}

const _indicators = [
  _Indicator(Icons.groups_rounded, 'Usuários Ativos', '1.248', '12,5%'),
  _Indicator(Icons.badge_rounded, 'Acessos Realizados', '3.842', '18,2%'),
  _Indicator(Icons.restaurant_rounded, 'Refeições Previstas', '5.736', '9,4%'),
  _Indicator(Icons.show_chart_rounded, 'Acurácia da Previsão', '87%', '6,7%'),
];

const _demandLabels = ['01/05', '08/05', '15/05', '22/05', '29/05'];
const _demandPrevisto = [180.0, 420.0, 520.0, 780.0, 950.0];
const _demandRealizado = [120.0, 300.0, 480.0, 650.0, 700.0];

const _mealSlices = [
  {'label': 'Almoço', 'percent': 45.0, 'color': AppColors.accent},
  {'label': 'Jantar', 'percent': 30.0, 'color': _PainelColors.cardText},
  {'label': 'Lanche', 'percent': 15.0, 'color': _PainelColors.chartGray},
  {'label': 'Outros', 'percent': 5.0, 'color': _PainelColors.chartGrayLight},
  {'label': 'Outros dados', 'percent': 5.0, 'color': Color(0xFFF3F3F3)},
];

// =======================================================
// Tela Painel
// =======================================================
class PainelScreen extends StatelessWidget {
  const PainelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Builder(builder: (context) => _buildHeader(context)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: 24),
                    _buildOverviewCard(),
                    const SizedBox(height: 24),
                    _buildIndicatorsGrid(),
                    const SizedBox(height: 24),
                    _buildDemandChart(),
                    const SizedBox(height: 24),
                    _buildMealChart(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // Header: menu, logo, avatar, sino
  // -----------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Scaffold.of(context).openDrawer(),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.menu_rounded,
              color: AppColors.textPrimary,
              size: 26,
            ),
          ),
        ),
        const Spacer(),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            children: [
              TextSpan(
                text: 'SICA',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              TextSpan(
                text: 'PDA',
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: const Text(
            'A',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textPrimary,
              size: 26,
            ),
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '2',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------
  // Saudação
  // -----------------------------------------------------
  Widget _buildGreeting() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Olá, Administrador! 👋',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Aqui está um resumo do que está acontecendo hoje.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  // -----------------------------------------------------
  // Card "Visão Geral do Sistema"
  // -----------------------------------------------------
  Widget _buildOverviewCard() {
    return _cardWrapper(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visão Geral do Sistema',
                  style: TextStyle(
                    color: _PainelColors.cardText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Acompanhe os principais indicadores',
                  style: TextStyle(
                    color: _PainelColors.cardTextMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.trending_up_rounded,
            color: AppColors.accent,
            size: 22,
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // Grade 2x2 de indicadores
  // -----------------------------------------------------
  Widget _buildIndicatorsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _indicators.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (context, i) {
        final data = _indicators[i];
        return _cardWrapper(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        color: _PainelColors.cardTextMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                data.value,
                style: const TextStyle(
                  color: _PainelColors.cardText,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.arrow_upward_rounded,
                    color: _PainelColors.positive,
                    size: 14,
                  ),
                  Flexible(
                    child: Text(
                      ' ${data.growth} este mês',
                      style: const TextStyle(
                        color: _PainelColors.positive,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -----------------------------------------------------
  // Gráfico de Previsão de Demanda (linhas)
  // -----------------------------------------------------
  Widget _buildDemandChart() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Previsão de Demanda',
                style: TextStyle(
                  color: _PainelColors.cardText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _PeriodPill(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _LegendDot(color: AppColors.accent, label: 'Previsto'),
              SizedBox(width: 16),
              _LegendDot(color: _PainelColors.chartGray, label: 'Realizado'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1000,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 250,
                  getDrawingHorizontalLine: (v) =>
                      const FlLine(color: Color(0xFFEDEDED), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 250,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                          color: _PainelColors.cardTextMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= _demandLabels.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _demandLabels[i],
                            style: const TextStyle(
                              color: _PainelColors.cardTextMuted,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _line(_demandPrevisto, AppColors.accent, withArea: true),
                  _line(
                    _demandRealizado,
                    _PainelColors.chartGray,
                    withArea: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(
    List<double> values,
    Color color, {
    required bool withArea,
  }) {
    return LineChartBarData(
      spots: [
        for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: _PainelColors.cardBackground,
        ),
      ),
      belowBarData: BarAreaData(show: withArea, color: color.withOpacity(0.12)),
    );
  }

  // -----------------------------------------------------
  // Gráfico de Distribuição de Refeições (rosca)
  // -----------------------------------------------------
  Widget _buildMealChart() {
    return _cardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Distribuição de Refeições',
                style: TextStyle(
                  color: _PainelColors.cardText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _PeriodPill(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      for (final s in _mealSlices)
                        PieChartSectionData(
                          value: s['percent'] as double,
                          color: s['color'] as Color,
                          showTitle: false,
                          radius: 22,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (final s in _mealSlices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: s['color'] as Color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s['label'] as String,
                                style: const TextStyle(
                                  color: _PainelColors.cardText,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(s['percent'] as double).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: _PainelColors.cardText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------
  // Navegação inferior
  // -----------------------------------------------------
  Widget _buildBottomNav() {
    final items = [
      (Icons.dashboard_rounded, 'Painel', true),
      (Icons.link_rounded, 'Acessos', false),
      (Icons.people_alt_rounded, 'Pessoas', false),
      (Icons.restaurant_menu_rounded, 'Refeições', false),
      (Icons.more_horiz_rounded, 'Mais', false),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final item in items)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.$1,
                    color: item.$3 ? AppColors.accent : AppColors.textSecondary,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: item.$3
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: item.$3 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // Menu lateral (aside)
  // -----------------------------------------------------
  Widget _buildDrawer(BuildContext context) {
    final items = [
      (Icons.dashboard_rounded, 'Painel'),
      (Icons.link_rounded, 'Acessos'),
      (Icons.people_alt_rounded, 'Pessoas'),
      (Icons.restaurant_menu_rounded, 'Refeições'),
      (Icons.settings_rounded, 'Configurações'),
    ];

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      'A',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrador',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Fluxe · SICAPDA',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.fieldBorder, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  for (final item in items)
                    ListTile(
                      leading: Icon(
                        item.$1,
                        color: item.$2 == 'Painel'
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                      title: Text(
                        item.$2,
                        style: TextStyle(
                          color: item.$2 == 'Painel'
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: item.$2 == 'Painel'
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.fieldBorder, height: 1),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Sair',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _handleLogout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Fecha o painel e volta para a tela de login, limpando o histórico de
  // navegação para que o botão "voltar" não retorne ao painel.
  void _handleLogout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // -----------------------------------------------------
  // Helpers
  // -----------------------------------------------------
  Widget _cardWrapper({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _PainelColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _PainelColors.chartGrayLight),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Este mês',
            style: TextStyle(
              color: _PainelColors.cardText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: _PainelColors.cardTextMuted,
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _PainelColors.cardTextMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
