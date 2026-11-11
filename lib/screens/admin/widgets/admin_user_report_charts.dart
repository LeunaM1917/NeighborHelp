import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../utils/user_report_stats.dart';
import 'admin_dashboard_widgets.dart';

class AdminUserReportCharts extends StatelessWidget {
  const AdminUserReportCharts({super.key, required this.stats});

  final UserReportStats stats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final status = AdminPanelCard(
        title: 'Report status',
        child: _StatusChart(stats: stats),
      );
      final trend = AdminPanelCard(
        title: 'Reports received',
        child: _MonthlyChart(stats: stats),
      );
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [status, const SizedBox(height: 20), trend],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: status),
          const SizedBox(width: 20),
          Expanded(child: trend),
        ],
      );
    },
  );
}

class _StatusChart extends StatelessWidget {
  const _StatusChart({required this.stats});
  final UserReportStats stats;

  @override
  Widget build(BuildContext context) {
    final values = [stats.open, stats.resolved, stats.dismissed];
    const labels = ['Open reports', 'Resolved', 'Dismissed'];
    const colors = [
      FigmaColors.orange600,
      FigmaColors.green,
      FigmaColors.red600,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              stats.isLimited
                  ? 'Latest ${stats.total} reports · current status'
                  : 'All reports · current status',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (stats.total > 0)
                  ExcludeSemantics(
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 48,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        sections: [
                          for (var i = 0; i < values.length; i++)
                            if (values[i] > 0)
                              PieChartSectionData(
                                value: values[i].toDouble(),
                                color: colors[i],
                                radius: 30,
                                showTitle: false,
                              ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: FigmaColors.gray200, width: 22),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${stats.total}',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      stats.total == 0 ? 'No reports yet' : 'Total reports',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FigmaColors.gray500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[i],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(labels[i])),
                  Text(
                    '${values[i]} (${stats.total == 0 ? '0' : (values[i] * 100 / stats.total).toStringAsFixed(0)}%)',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Open includes cases under review or waiting for a response.',
            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.stats});
  final UserReportStats stats;

  @override
  Widget build(BuildContext context) {
    final maximum = stats.monthlyCounts.fold<int>(0, (a, b) => a > b ? a : b);
    final interval = maximum < 4 ? 1.0 : (maximum / 4).ceilToDouble();
    final cap = maximum < 4
        ? 4.0
        : ((maximum / interval).ceil() + 1) * interval;
    final period =
        '${DateFormat('MMM yyyy').format(stats.months.first)} – ${DateFormat('MMM yyyy').format(stats.months.last)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$period · Asia/Manila'),
          const SizedBox(height: 24),
          Semantics(
            label:
                'Reports received. ${List.generate(6, (i) => '${DateFormat('MMMM yyyy').format(stats.months[i])}: ${stats.monthlyCounts[i]}').join('. ')}',
            child: ExcludeSemantics(
              child: SizedBox(
                height: 230,
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: cap,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: FigmaColors.gray200,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => FigmaColors.white,
                        tooltipBorder: const BorderSide(
                          color: FigmaColors.gray300,
                        ),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                              '${DateFormat('MMM yyyy').format(stats.months[group.x])}\n${rod.toY.round()} ${rod.toY == 1 ? 'report' : 'reports'}',
                              GoogleFonts.inter(
                                color: FigmaColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      ),
                    ),
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
                          reservedSize: 32,
                          interval: interval,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: FigmaColors.gray500,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                i >= 0 && i < 6
                                    ? DateFormat('MMM').format(stats.months[i])
                                    : '',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: FigmaColors.gray500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < 6; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: stats.monthlyCounts[i].toDouble(),
                              width: 24,
                              color: FigmaColors.navy,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            maximum == 0
                ? (stats.isLimited
                      ? 'No reports in this period among the latest ${stats.total} reports.'
                      : 'No reports received in this period.')
                : (stats.isLimited
                      ? 'Monthly counts among the latest ${stats.total} reports only'
                      : 'New reports submitted each month · last 6 months'),
            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
          ),
        ],
      ),
    );
  }
}
