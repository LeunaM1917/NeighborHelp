import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import 'admin_chart_touch.dart';
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
}) {
  final totals = <String, int>{};
  final completed = <String, int>{};
  final ratingSum = <String, double>{};
  final ratingCount = <String, int>{};
  final providerRating = {for (final p in providers) p.userId: p.averageRating};

  for (final b in bookings) {
    final cat = _categoryForBooking(b, servicesById);
    totals[cat] = (totals[cat] ?? 0) + 1;
    if (b.status.toLowerCase() == 'completed') {
      completed[cat] = (completed[cat] ?? 0) + 1;
    }
    final r = providerRating[b.providerId] ?? 0;
    if (r > 0) {
      ratingSum[cat] = (ratingSum[cat] ?? 0) + r;
      ratingCount[cat] = (ratingCount[cat] ?? 0) + 1;
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

String _categoryForBooking(Booking b, Map<String, ServiceListing> servicesById) {
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

Map<int, int> providerRatingDistribution(List<ServiceProviderProfile> providers) {
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
  });

  final List<Booking> bookings;
  final String granularity;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      now.day.clamp(7, 31),
      (i) => DateTime(now.year, now.month, i + 1),
    );
    if (days.length > 14 && granularity == 'Daily') {
      // Sample every other day label on small screens handled by chart
    }

    final completed = List<double>.filled(days.length, 0);
    final total = List<double>.filled(days.length, 0);

    for (final b in bookings) {
      final dt = b.scheduledDate.toDate();
      if (dt.year != now.year || dt.month != now.month) continue;
      final idx = dt.day - 1;
      if (idx < 0 || idx >= days.length) continue;
      total[idx]++;
      if (b.status.toLowerCase() == 'completed') completed[idx]++;
    }

    final maxY = [...completed, ...total].fold<double>(0, (a, b) => a > b ? a : b);
    final cap = maxY < 1 ? 4.0 : (maxY * 1.2).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ChartLegendDot(color: FigmaColors.green, label: 'Completed'),
              const SizedBox(width: 16),
              _ChartLegendDot(color: FigmaColors.navy, label: 'Total'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: cap,
                barTouchData: adminBarChartTouchData(
                  rodLabels: const ['Completed', 'Total'],
                  rodColors: [FigmaColors.green, FigmaColors.navy],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: FigmaColors.gray200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray500),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: days.length > 14 ? 4 : 2,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        if (days.length > 14 && i % 4 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${days[i].month}/${days[i].day}',
                            style: GoogleFonts.inter(fontSize: 9, color: FigmaColors.gray500),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: completed[i],
                          color: FigmaColors.green,
                          width: days.length > 20 ? 4 : 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                        BarChartRodData(
                          toY: total[i],
                          color: FigmaColors.navy.withValues(alpha: 0.85),
                          width: days.length > 20 ? 4 : 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ],
                      barsSpace: 2,
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

class AdminReportsCategoryDonut extends StatelessWidget {
  const AdminReportsCategoryDonut({
    super.key,
    required this.categoryCounts,
  });

  final Map<String, int> categoryCounts;

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
    final total = categoryCounts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('No booking data', style: GoogleFonts.inter(color: FigmaColors.gray500))),
      );
    }

    final sorted = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < sorted.length; i++) {
      sections.add(
        PieChartSectionData(
          value: sorted[i].value.toDouble(),
          color: _colors[i % _colors.length],
          radius: 36,
          showTitle: false,
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
                    sections: sections,
                    sectionsSpace: sorted.length > 1 ? 2 : 0,
                    centerSpaceRadius: 44,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Total', style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sorted.length && i < 6; i++)
            _ReportsCategoryLegendRow(
              color: _colors[i % _colors.length],
              label: sorted[i].key,
              count: sorted[i].value,
              percent: '${((sorted[i].value / total) * 100).toStringAsFixed(1)}%',
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
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count ($percent)',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
          ),
        ],
      ),
    );
  }
}

class AdminReportsRatingDistribution extends StatelessWidget {
  const AdminReportsRatingDistribution({super.key, required this.distribution});

  final Map<int, int> distribution;

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No rated providers', style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 13)),
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
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text('$star Stars', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    width: 36,
                    child: Text(
                      '${((distribution[star] ?? 0) / total * 100).round()}%',
                      style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${distribution[star] ?? 0}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
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

class AdminReportsRatingTrend extends StatelessWidget {
  const AdminReportsRatingTrend({super.key, required this.providers});

  final List<ServiceProviderProfile> providers;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      now.day.clamp(5, 31),
      (i) => DateTime(now.year, now.month, i + 1),
    );
    final values = List<double>.filled(days.length, 0);
    final counts = List<int>.filled(days.length, 0);

    for (final p in providers) {
      if (p.averageRating <= 0) continue;
      final dt = p.updatedAt.toDate();
      if (dt.year != now.year || dt.month != now.month) continue;
      final idx = dt.day - 1;
      if (idx < 0 || idx >= days.length) continue;
      values[idx] += p.averageRating;
      counts[idx]++;
    }

    var last = providers
        .where((p) => p.averageRating > 0)
        .fold<double>(4.0, (a, p) => p.averageRating);
    if (providers.any((p) => p.averageRating > 0)) {
      last = providers.where((p) => p.averageRating > 0).map((p) => p.averageRating).reduce((a, b) => a + b) /
          providers.where((p) => p.averageRating > 0).length;
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < days.length; i++) {
      final v = counts[i] > 0 ? values[i] / counts[i] : last;
      last = v;
      spots.add(FlSpot(i.toDouble(), v));
    }

    final minY = (spots.map((s) => s.y).fold<double>(5, math.min) - 0.3).clamp(3.5, 4.9);
    final maxY = (spots.map((s) => s.y).fold<double>(0, math.max) + 0.2).clamp(4.0, 5.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: FigmaColors.gray200, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 0.5,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(1),
                    style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray500),
                  ),
                ),
              ),
              bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: FigmaColors.green,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: FigmaColors.tintGreen.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking completion rate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(
                          '$completed of $total completed',
                          style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
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
                    decoration: BoxDecoration(color: FigmaColors.tintGreen, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.emoji_events_outlined, color: FigmaColors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Top performing category', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(
                          topCategory.isEmpty ? '—' : topCategory,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.green),
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
                      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                      const SizedBox(width: 8),
                      Text('Provider quality overview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    avgRating > 0 ? 'Average rating ${avgRating.toStringAsFixed(2)}/5' : 'No ratings yet',
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                  ),
                  if (avgRating > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
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
    final display = rows.take(5).toList();

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
              headingTextStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
              dataTextStyle: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray800),
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
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                                ),
                              )
                            : Text(r.category, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
                                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                ],
                              )
                            : Text('—', style: GoogleFonts.inter(color: FigmaColors.gray500)),
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
                    Text('View all categories', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.green)),
                    const Icon(Icons.chevron_right, size: 18, color: FigmaColors.green),
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
              subtitle: 'Create AI-powered summary',
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
                decoration: BoxDecoration(color: FigmaColors.gray100, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: FigmaColors.gray700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
      ],
    );
  }
}
