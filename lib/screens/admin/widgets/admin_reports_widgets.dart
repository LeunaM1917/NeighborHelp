import '../../../models/review.dart';
import '../../../utils/report_analytics.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import 'admin_chart_touch.dart';
import 'admin_report_count_chart.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

class CategoryReportRow {
  const CategoryReportRow({
    required this.category,
    required this.total,
    required this.completed,
    required this.avgRating,
  });

  final String category;
  final int total;
  final int completed;
  final double avgRating;

  double get completionRate => total > 0 ? completed / total : 0;
}

List<CategoryReportRow> buildCategoryRows({
  required List<Booking> bookings,
  required Map<String, ServiceListing> servicesById,
  required List<ServiceProviderProfile> providers,
  List<Review>? reviews,
}) {
  final totals = <String, int>{};
  final completed = <String, int>{};
  final ratingSum = <String, double>{};
  final ratingCount = <String, int>{};
  final providerRating = {for (final p in providers) p.userId: p.averageRating};

  for (final b in bookings) {
    final cat = _categoryForBooking(b, servicesById);
    totals[cat] = (totals[cat] ?? 0) + 1;
    if (b.isCompleted) {
      completed[cat] = (completed[cat] ?? 0) + 1;
    }
    final r = reviews == null ? providerRating[b.providerId] ?? 0 : 0;
    if (r > 0) {
      ratingSum[cat] = (ratingSum[cat] ?? 0) + r;
      ratingCount[cat] = (ratingCount[cat] ?? 0) + 1;
    }
  }

  if (reviews != null) {
    for (final review in {for (final r in reviews) r.reviewId: r}.values) {
      if (!review.isCustomerReview || review.rating < 1 || review.rating > 5) {
        continue;
      }
      final raw = servicesById[review.serviceId]?.category.trim();
      final category = raw == null || raw.isEmpty ? 'Other' : raw;
      ratingSum[category] = (ratingSum[category] ?? 0) + review.rating;
      ratingCount[category] = (ratingCount[category] ?? 0) + 1;
    }
  }
  final rows = <CategoryReportRow>[];
  totals.forEach((cat, total) {
    rows.add(
      CategoryReportRow(
        category: cat,
        total: total,
        completed: completed[cat] ?? 0,
        avgRating: ratingCount[cat] != null && ratingCount[cat]! > 0
            ? ratingSum[cat]! / ratingCount[cat]!
            : 0,
      ),
    );
  });
  rows.sort((a, b) => b.total.compareTo(a.total));
  return rows;
}

String _categoryForBooking(
  Booking b,
  Map<String, ServiceListing> servicesById,
) {
  final cat = servicesById[b.serviceId]?.category.trim();
  if (cat == null || cat.isEmpty) return 'Other';
  return cat;
}

Map<String, int> bookingCountsByCategory(
  List<Booking> bookings,
  Map<String, ServiceListing> servicesById,
) {
  final counts = <String, int>{};
  for (final b in bookings) {
    final cat = _categoryForBooking(b, servicesById);
    counts[cat] = (counts[cat] ?? 0) + 1;
  }
  return counts;
}

Map<int, int> providerRatingDistribution(
  List<ServiceProviderProfile> providers,
) {
  final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  for (final p in providers) {
    if (p.averageRating <= 0) continue;
    final star = p.averageRating.clamp(1.0, 5.0).round();
    dist[star] = (dist[star] ?? 0) + 1;
  }
  return dist;
}

class AdminReportsTrendChart extends StatelessWidget {
  const AdminReportsTrendChart({
    super.key,
    required this.bookings,
    this.granularity = 'Daily',
    this.range = 'This month',
    this.period,
  });

  final List<Booking> bookings;
  final String granularity;
  final String range;
  final ReportPeriod? period;

  @override
  Widget build(BuildContext context) {
    final selected = period ?? ReportPeriod.named(range, DateTime.now());
    final from = reportDay(selected.start);
    final last = reportDay(
      selected.endExclusive.subtract(const Duration(microseconds: 1)),
    );
    final step = granularity == 'Weekly' ? 7 : 1;
    final days = List.generate(
      last.difference(from).inDays ~/ step + 1,
      (i) => from.add(Duration(days: i * step)),
    );
    final values = List.generate(days.length, (_) => [0, 0]);
    for (final b in {for (final b in bookings) b.bookingId: b}.values) {
      if (!selected.contains(b.createdAt.toDate())) continue;
      final index =
          reportDay(b.createdAt.toDate()).difference(from).inDays ~/ step;
      values[index][1]++;
      if (b.isCompleted) values[index][0]++;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: AdminReportCountChart(
        labels: [
          for (var i = 0; i < days.length; i++)
            granularity == 'Weekly'
                ? '${DateFormat('MMM d').format(days[i])}–\n${DateFormat('MMM d').format(i + 1 < days.length ? days[i + 1].subtract(const Duration(days: 1)) : last)}'
                : DateFormat('MMM d').format(days[i]),
        ],
        series: const ['Completed', 'Total'],
        values: values,
        periodLabel: selected.label,
      ),
    );
  }
}

class AdminReportsCategoryDonut extends StatefulWidget {
  const AdminReportsCategoryDonut({
    super.key,
    required this.categoryCounts,
    this.periodLabel = '',
  });

  final Map<String, int> categoryCounts;
  final String periodLabel;
  @override
  State<AdminReportsCategoryDonut> createState() =>
      _AdminReportsCategoryDonutState();
}

class _AdminReportsCategoryDonutState extends State<AdminReportsCategoryDonut> {
  int? _touched;

  static const _colors = [
    FigmaColors.green,
    FigmaColors.navy,
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
    Color(0xFF0EA5E9),
    FigmaColors.gray400,
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.categoryCounts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No booking data',
            style: GoogleFonts.inter(color: FigmaColors.gray500),
          ),
        ),
      );
    }

    final sorted = widget.categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < sorted.length; i++) {
      sections.add(
        PieChartSectionData(
          value: sorted[i].value.toDouble(),
          color: _colors[i % _colors.length],
          radius: 36,
          showTitle: sorted[i].value / total >= .08,
          title:
              '${sorted[i].value}\n${(sorted[i].value * 100 / total).toStringAsFixed(1)}%',
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 148,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: adminPieChartTouchData(
                      onSectionIndex: (i) => setState(() => _touched = i),
                    ),
                    sections: sections,
                    sectionsSpace: sorted.length > 1 ? 2 : 0,
                    centerSpaceRadius: 44,
                    startDegreeOffset: -90,
                  ),
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Total',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: FigmaColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_touched != null &&
                    _touched! >= 0 &&
                    _touched! < sorted.length)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: AdminPieChartTooltip(
                        label:
                            '${sorted[_touched!].key} · ${widget.periodLabel}',
                        value: sorted[_touched!].value,
                        percentLabel:
                            '${(sorted[_touched!].value * 100 / total).toStringAsFixed(1)}%',
                        color: _colors[_touched! % _colors.length],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sorted.length; i++)
            _ReportsCategoryLegendRow(
              color: _colors[i % _colors.length],
              label: sorted[i].key,
              count: sorted[i].value,
              percent:
                  '${((sorted[i].value / total) * 100).toStringAsFixed(1)}%',
            ),
        ],
      ),
    );
  }
}

class _ReportsCategoryLegendRow extends StatelessWidget {
  const _ReportsCategoryLegendRow({
    required this.color,
    required this.label,
    required this.count,
    required this.percent,
  });

  final Color color;
  final String label;
  final int count;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: FigmaColors.gray700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count ($percent)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray800,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminReportsRatingDistribution extends StatelessWidget {
  const AdminReportsRatingDistribution({
    super.key,
    required this.distribution,
    this.periodLabel = '',
  });

  final Map<int, int> distribution;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No rated providers',
          style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 13),
        ),
      );
    }

    const colors = {
      5: FigmaColors.green,
      4: FigmaColors.green,
      3: FigmaColors.orange600,
      2: FigmaColors.orange600,
      1: FigmaColors.red600,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          for (final star in [5, 4, 3, 2, 1])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Tooltip(
                message:
                    '$star stars (rounded provider mean): ${distribution[star] ?? 0} providers (${((distribution[star] ?? 0) * 100 / total).toStringAsFixed(1)}%)\n$periodLabel',
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        '$star Stars',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (distribution[star] ?? 0) / total,
                          minHeight: 8,
                          backgroundColor: FigmaColors.gray100,
                          color: colors[star],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${((distribution[star] ?? 0) / total * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: FigmaColors.gray600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${distribution[star] ?? 0}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminReportsRatingTrend extends StatelessWidget {
  const AdminReportsRatingTrend({super.key, required this.reviews});
  final List<Review> reviews;
  @override
  Widget build(BuildContext context) {
    final values = dailyReviewRatings(reviews);
    if (values.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No customer ratings were submitted during this period.'),
      );
    }
    if (values.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${values.values.single.toStringAsFixed(2)} stars on ${DateFormat('MMM d').format(values.keys.single)}',
        ),
      );
    }
    final days = values.keys.toList();
    final origin = DateTime.utc(
      days.first.year,
      days.first.month,
      days.first.day,
    );
    final spots = [
      for (final day in days)
        FlSpot(
          DateTime.utc(
            day.year,
            day.month,
            day.day,
          ).difference(origin).inDays.toDouble(),
          values[day]!,
        ),
    ];
    final counts = <DateTime, int>{};
    for (final r in {for (final r in reviews) r.reviewId: r}.values) {
      if (r.isCustomerReview && r.rating >= 1 && r.rating <= 5) {
        final day = reportDay(r.createdAt.toDate());
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Daily mean of submitted customer star ratings. Only observed dates are plotted. Asia/Manila.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          AdminHorizontalScrollTable(
            minTableWidth: ((spots.last.x + 1) * 64 + 64).clamp(
              320,
              double.infinity,
            ),
            child: SizedBox(
              width: ((spots.last.x + 1) * 64 + 64).clamp(320, double.infinity),
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 1,
                  maxY: 5.65,
                  minX: -.5,
                  maxX: spots.last.x + .5,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => FigmaColors.white,
                      getTooltipItems: (touched) => touched.map((spot) {
                        final day = origin.add(Duration(days: spot.x.toInt()));
                        final count = counts[day] ?? 0;
                        return LineTooltipItem(
                          '${DateFormat('MMM d, yyyy').format(day)} · Asia/Manila\n${spot.y.toStringAsFixed(2)} / 5 · $count reviews',
                          const TextStyle(
                            fontSize: 12,
                            color: FigmaColors.gray900,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: FigmaColors.green,
                      isCurved: false,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, _, _) =>
                            _RatingDotPainter(spot.y),
                      ),
                    ),
                  ],
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
                        interval: 1,
                        getTitlesWidget: (v, _) => v > 5 || v < 1
                            ? const SizedBox.shrink()
                            : Text(
                                '${v.toInt()}',
                                style: const TextStyle(fontSize: 11),
                              ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) =>
                            v < 0 || v > spots.last.x || v != v.roundToDouble()
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('M/d').format(
                                    origin.add(Duration(days: v.toInt())),
                                  ),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                  ),
                ),
                duration: Duration.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingDotPainter extends FlDotCirclePainter {
  _RatingDotPainter(this.value) : super(color: FigmaColors.green, radius: 3);
  final double value;
  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    super.draw(canvas, spot, offsetInCanvas);
    final text = TextPainter(
      text: TextSpan(
        text: value.toStringAsFixed(2),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: FigmaColors.gray900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      offsetInCanvas.translate(-text.width / 2, -text.height - 7),
    );
  }

  @override
  List<Object?> get props => [...super.props, value];
}

class AdminReportsInsightsPanel extends StatelessWidget {
  const AdminReportsInsightsPanel({
    super.key,
    required this.completionRate,
    required this.completed,
    required this.total,
    required this.topCategory,
    required this.avgRating,
  });

  final double completionRate;
  final int completed;
  final int total;
  final String topCategory;
  final double avgRating;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Insights',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            _InsightCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: completionRate,
                          strokeWidth: 4,
                          color: FigmaColors.green,
                          backgroundColor: FigmaColors.gray200,
                        ),
                        Text(
                          '${(completionRate * 100).round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking completion rate',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$completed of $total completed',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: FigmaColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _InsightCard(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FigmaColors.tintGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: FigmaColors.green,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top performing category',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          topCategory.isEmpty ? '—' : topCategory,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FigmaColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _InsightCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Provider quality overview',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    avgRating > 0
                        ? 'Average rating ${avgRating.toStringAsFixed(2)}/5'
                        : 'No ratings yet',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: FigmaColors.gray600,
                    ),
                  ),
                  if (avgRating > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= avgRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: const Color(0xFFF59E0B),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: child,
    );
  }
}

class AdminReportsCategoryTable extends StatelessWidget {
  const AdminReportsCategoryTable({
    super.key,
    required this.rows,
    this.onViewAll,
    this.onOpenRow,
  });

  final List<CategoryReportRow> rows;
  final VoidCallback? onViewAll;
  final ValueChanged<CategoryReportRow>? onOpenRow;

  @override
  Widget build(BuildContext context) {
    final display = rows;

    return AdminPanelCard(
      title: 'Category performance',
      child: Column(
        children: [
          AdminHorizontalScrollTable(
            minTableWidth: 920,
            child: DataTable(
              columnSpacing: 28,
              horizontalMargin: 20,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 64,
              headingTextStyle: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FigmaColors.gray600,
              ),
              dataTextStyle: GoogleFonts.inter(
                fontSize: 12,
                color: FigmaColors.gray800,
              ),
              columns: const [
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Total bookings')),
                DataColumn(label: Text('Completed')),
                DataColumn(label: Text('Completion rate')),
                DataColumn(label: Text('Average rating')),
              ],
              rows: [
                for (final r in display)
                  DataRow(
                    cells: [
                      DataCell(
                        onOpenRow != null
                            ? AdminTableDetailTap(
                                onOpen: () => onOpenRow!(r),
                                child: Text(
                                  r.category,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: FigmaColors.navy,
                                  ),
                                ),
                              )
                            : Text(
                                r.category,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      DataCell(Text('${r.total}')),
                      DataCell(Text('${r.completed}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(r.completionRate * 100).round()}%'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: r.completionRate,
                                  minHeight: 6,
                                  backgroundColor: FigmaColors.gray200,
                                  color: FigmaColors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        r.avgRating > 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(r.avgRating.toStringAsFixed(1)),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ],
                              )
                            : Text(
                                '—',
                                style: GoogleFonts.inter(
                                  color: FigmaColors.gray500,
                                ),
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'View all categories',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: FigmaColors.green,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: FigmaColors.green,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminReportsQuickActions extends StatelessWidget {
  const AdminReportsQuickActions({
    super.key,
    this.onExportCsv,
    this.onViewBookings,
    this.onReviewProviders,
    this.onGenerateSummary,
  });

  final VoidCallback? onExportCsv;
  final VoidCallback? onViewBookings;
  final VoidCallback? onReviewProviders;
  final VoidCallback? onGenerateSummary;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Quick actions',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          children: [
            _ReportActionRow(
              icon: Icons.file_download_outlined,
              title: 'Export CSV',
              subtitle: 'Download full report data',
              onTap: onExportCsv,
            ),
            _ReportActionRow(
              icon: Icons.event_note_outlined,
              title: 'View bookings',
              subtitle: 'Browse all booking records',
              onTap: onViewBookings,
            ),
            _ReportActionRow(
              icon: Icons.engineering_outlined,
              title: 'Review providers',
              subtitle: 'Manage provider performance',
              onTap: onReviewProviders,
            ),
            _ReportActionRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Generate summary',
              subtitle: 'Preview the selected report',
              onTap: onGenerateSummary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportActionRow extends StatelessWidget {
  const _ReportActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FigmaColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: FigmaColors.gray700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: FigmaColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: FigmaColors.gray400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
