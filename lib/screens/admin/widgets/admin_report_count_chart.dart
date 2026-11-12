import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../figma_ui/figma_colors.dart';
import 'admin_widgets.dart';

/// Room for every number is reserved before painting; longer periods scroll
/// horizontally instead of dropping labels or squeezing bars together.
class AdminReportCountChart extends StatelessWidget {
  const AdminReportCountChart({
    super.key,
    required this.labels,
    required this.series,
    required this.values,
    required this.periodLabel,
    this.colors = const [FigmaColors.green, FigmaColors.navy],
  });
  final List<String> labels, series;
  final List<List<int>> values;
  final List<Color> colors;
  final String periodLabel;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || !values.any((row) => row.any((n) => n > 0))) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No records in this period.'),
      );
    }
    final maxValue = values.expand((v) => v).reduce(math.max);
    final numberWidth = math.max(32.0, maxValue.toString().length * 8.0 + 12);
    final groupWidth = math.max(96.0, series.length * numberWidth + 28);
    final maxY = math.max(4.0, maxValue * 1.25);
    const left = 56.0, bottom = 44.0, height = 250.0;
    final totals = [
      for (var j = 0; j < series.length; j++)
        values.fold<int>(0, (n, row) => n + row[j]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var j = 0; j < series.length; j++)
              Text(
                '${series[j]}: ${totals[j]}',
                style: TextStyle(
                  color: colors[j % colors.length],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AdminHorizontalScrollTable(
          minTableWidth: left + labels.length * groupWidth,
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.minWidth,
              height: height,
              child: RepaintBoundary(
                child: Stack(
                  children: [
                    BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: maxY,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: math.max(
                            1.0,
                            (maxY / 4).ceilToDouble(),
                          ),
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
                              reservedSize: left,
                              interval: math.max(
                                1.0,
                                (maxY / 4).ceilToDouble(),
                              ),
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: bottom,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                return i < 0 || i >= labels.length
                                    ? const SizedBox.shrink()
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          labels[i],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipColor: (_) => FigmaColors.white,
                            tooltipBorder: const BorderSide(
                              color: FigmaColors.gray300,
                            ),
                            maxContentWidth: 260,
                            getTooltipItem: (group, index, rod, j) =>
                                BarTooltipItem(
                                  '${labels[index]} · ${series[j]}\n${rod.toY.toInt()} (${totals[j] == 0 ? '0.0' : (rod.toY * 100 / totals[j]).toStringAsFixed(1)}% of ${series[j].toLowerCase()})\n$periodLabel',
                                  const TextStyle(
                                    fontSize: 12,
                                    color: FigmaColors.gray900,
                                  ),
                                ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < values.length; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: numberWidth - 12,
                              barRods: [
                                for (var j = 0; j < series.length; j++)
                                  BarChartRodData(
                                    toY: values[i][j].toDouble(),
                                    width: 12,
                                    color: colors[j % colors.length],
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      duration: Duration.zero,
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _CountLabels(
                            values,
                            maxY,
                            left,
                            bottom,
                            numberWidth,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountLabels extends CustomPainter {
  _CountLabels(
    this.values,
    this.maxY,
    this.left,
    this.bottom,
    this.numberWidth,
  );
  final List<List<int>> values;
  final double maxY, left, bottom, numberWidth;
  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - bottom;
    final groupWidth = (size.width - left) / values.length;
    for (var i = 0; i < values.length; i++) {
      for (var j = 0; j < values[i].length; j++) {
        final text = TextPainter(
          text: TextSpan(
            text: '${values[i][j]}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final x =
            left +
            groupWidth * (i + .5) +
            (j - (values[i].length - 1) / 2) * numberWidth;
        final y = plotHeight * (1 - values[i][j] / maxY) - text.height - 4;
        text.paint(canvas, Offset(x - text.width / 2, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CountLabels old) =>
      old.values != values || old.maxY != maxY;
}
