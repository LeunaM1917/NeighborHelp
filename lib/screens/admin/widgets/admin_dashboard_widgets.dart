import 'package:fl_chart/fl_chart.dart';

import 'admin_chart_touch.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

/// Header row: title, subtitle, date range, export.
class AdminDashboardHeader extends StatelessWidget {
  const AdminDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.dateRange,
    this.onDateRangeChanged,
    this.onExport,
  });

  final String title;
  final String subtitle;
  final String? dateRange;
  final ValueChanged<String>? onDateRangeChanged;
  final VoidCallback? onExport;

  static const dateRanges = ['This week', 'This month', 'Last 3 months', 'This year'];

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: FigmaColors.gray900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
        ),
      ],
    );

    final controls = <Widget>[];
    if (onDateRangeChanged != null) {
      controls.add(
        SizedBox(
          width: 180,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: FigmaColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FigmaColors.gray300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: dateRange ?? dateRanges[1],
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                isExpanded: true,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: FigmaColors.gray800),
                items: [
                  for (final r in dateRanges)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) {
                  if (v != null) onDateRangeChanged!(v);
                },
              ),
            ),
          ),
        ),
      );
    }
    if (onExport != null) {
      controls.add(
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: Text('Export report', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: FigmaColors.green,
            side: const BorderSide(color: FigmaColors.green),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 720 || controls.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              if (controls.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: controls),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            for (var i = 0; i < controls.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              controls[i],
            ],
          ],
        );
      },
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.trendLabel,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? trendLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              if (trendLabel != null)
                Flexible(
                  child: Text(
                    trendLabel!,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.green),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
          const SizedBox(height: 4),
          Text(hint, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
        ],
      ),
    );
  }
}

class AdminPanelCard extends StatelessWidget {
  const AdminPanelCard({super.key, required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class AdminBookingTrendChart extends StatelessWidget {
  const AdminBookingTrendChart({super.key, required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });
    final labels = days.map((d) => DateFormat('MMM d').format(d)).toList();

    final completed = List<double>.filled(7, 0);
    final pending = List<double>.filled(7, 0);

    for (final b in bookings) {
      final dt = b.updatedAt.toDate();
      final day = DateTime(dt.year, dt.month, dt.day);
      final idx = days.indexWhere((d) => d == day);
      if (idx < 0) continue;
      final s = b.status.toLowerCase();
      if (s == 'completed') {
        completed[idx]++;
      } else if (s != 'cancelled' && s != 'canceled') {
        pending[idx]++;
      }
    }

    final maxY = [...completed, ...pending].fold<double>(0, (a, b) => a > b ? a : b);
    final cap = maxY < 1 ? 3.0 : (maxY + 1).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              _ChartLegendDot(color: FigmaColors.green, label: 'Completed'),
              const SizedBox(width: 20),
              _ChartLegendDot(color: FigmaColors.navy, label: 'Pending'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: cap,
                barTouchData: adminBarChartTouchData(
                  rodLabels: const ['Completed', 'Pending'],
                  rodColors: [FigmaColors.green, FigmaColors.navy],
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(color: FigmaColors.gray200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < 7; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: completed[i],
                          color: FigmaColors.green,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: pending[i],
                          color: FigmaColors.navy,
                          width: 10,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                      barsSpace: 4,
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

class AdminVerificationDonut extends StatelessWidget {
  const AdminVerificationDonut({
    super.key,
    required this.approved,
    required this.pending,
    required this.rejected,
  });

  final int approved;
  final int pending;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final total = approved + pending + rejected;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text('No providers yet', style: GoogleFonts.inter(color: FigmaColors.gray500))),
      );
    }

    final sections = <PieChartSectionData>[
      if (approved > 0)
        PieChartSectionData(value: approved.toDouble(), color: FigmaColors.green, radius: 40, showTitle: false),
      if (pending > 0)
        PieChartSectionData(value: pending.toDouble(), color: FigmaColors.orange600, radius: 40, showTitle: false),
      if (rejected > 0)
        PieChartSectionData(value: rejected.toDouble(), color: FigmaColors.gray400, radius: 40, showTitle: false),
    ];

    String pct(int n) => '${((n / total) * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 3,
                    centerSpaceRadius: 52,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text('Total', style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DonutLegendRow(color: FigmaColors.green, label: 'Approved', count: approved, percent: pct(approved)),
          _DonutLegendRow(color: FigmaColors.orange600, label: 'Pending', count: pending, percent: pct(pending)),
          _DonutLegendRow(color: FigmaColors.gray400, label: 'Rejected', count: rejected, percent: pct(rejected)),
        ],
      ),
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(percent, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
        ],
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    if (s == 'completed') {
      bg = FigmaColors.tintGreen;
      fg = FigmaColors.green;
    } else if (s == 'in progress' || s == 'in_progress') {
      bg = FigmaColors.indigo50;
      fg = FigmaColors.indigo600;
    } else if (s == 'pending') {
      bg = FigmaColors.orange50;
      fg = FigmaColors.orange600;
    } else if (s == 'cancelled' || s == 'canceled') {
      bg = FigmaColors.red50;
      fg = FigmaColors.red600;
    } else {
      bg = FigmaColors.gray100;
      fg = FigmaColors.gray700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        _label(status),
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  static String _label(String status) {
    final s = status.toLowerCase();
    if (s == 'in_progress') return 'In Progress';
    if (s.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }
}

String adminBookingDisplayId(String id) {
  final tail = id.length > 4 ? id.substring(id.length - 4).toUpperCase() : id.toUpperCase();
  return 'BK-$tail';
}

String adminInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class AdminRecentBookingsTable extends StatelessWidget {
  const AdminRecentBookingsTable({
    super.key,
    required this.bookings,
    required this.usersById,
    required this.servicesById,
    this.onViewAll,
    this.onOpenBooking,
  });

  final List<Booking> bookings;
  final Map<String, AppUser> usersById;
  final Map<String, ServiceListing> servicesById;
  final VoidCallback? onViewAll;
  final ValueChanged<Booking>? onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy • h:mm a');
    final rows = bookings.take(6).toList();

    return AdminPanelCard(
      title: 'Recent Bookings',
      child: Column(
        children: [
          AdminHorizontalScrollTable(
            minTableWidth: 1080,
            child: DataTable(
              columnSpacing: 28,
              horizontalMargin: 20,
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
              dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
              columns: const [
                DataColumn(label: Text('Booking ID')),
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Provider')),
                DataColumn(label: Text('Service')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Date/Time')),
              ],
              rows: [
                for (final b in rows)
                  DataRow(
                    cells: [
                      DataCell(
                        onOpenBooking != null
                            ? AdminTableDetailTap(
                                onOpen: () => onOpenBooking!(b),
                                child: Text(
                                  adminBookingDisplayId(b.bookingId),
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                                ),
                              )
                            : Text(adminBookingDisplayId(b.bookingId), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      ),
                      DataCell(Text(_userName(usersById[b.customerId], b.customerId), softWrap: false)),
                      DataCell(Text(_userName(usersById[b.providerId], b.providerId), softWrap: false)),
                      DataCell(
                        onOpenBooking != null
                            ? AdminTableDetailTap(
                                onOpen: () => onOpenBooking!(b),
                                child: Text(
                                  servicesById[b.serviceId]?.serviceTitle ?? '—',
                                  softWrap: false,
                                  style: GoogleFonts.inter(color: FigmaColors.navy),
                                ),
                              )
                            : Text(servicesById[b.serviceId]?.serviceTitle ?? '—', softWrap: false),
                      ),
                      DataCell(AdminStatusChip(status: b.status)),
                      DataCell(Text(dateFmt.format(b.scheduledDate.toDate()), softWrap: false)),
                    ],
                  ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No bookings yet.', style: GoogleFonts.inter(color: FigmaColors.gray500)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all bookings', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.green)),
                    const SizedBox(width: 4),
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

  static String _userName(AppUser? u, String fallback) {
    if (u != null && u.fullName.trim().isNotEmpty) return u.fullName;
    return fallback;
  }
}

class AdminPendingVerificationPanel extends StatelessWidget {
  const AdminPendingVerificationPanel({
    super.key,
    required this.providers,
    required this.usersById,
    this.onViewAll,
    this.onReview,
  });

  final List<ServiceProviderProfile> providers;
  final Map<String, AppUser> usersById;
  final VoidCallback? onViewAll;
  final void Function(ServiceProviderProfile provider)? onReview;

  @override
  Widget build(BuildContext context) {
    final pending = providers
        .where((p) => !p.isVerified || p.verificationStatus.toLowerCase() == 'pending')
        .take(4)
        .toList();
    final dateFmt = DateFormat('MMM d, yyyy');

    return AdminPanelCard(
      title: 'Pending Provider Verification',
      trailing: TextButton(
        onPressed: onViewAll,
        child: Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.green)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No pending applications.', style: GoogleFonts.inter(color: FigmaColors.gray500)),
              )
            else
              for (var i = 0; i < pending.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
                _PendingProviderRow(
                  provider: pending[i],
                  user: usersById[pending[i].userId],
                  dateFmt: dateFmt,
                  onReview: () => onReview?.call(pending[i]),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _PendingProviderRow extends StatelessWidget {
  const _PendingProviderRow({
    required this.provider,
    required this.user,
    required this.dateFmt,
    required this.onReview,
  });

  final ServiceProviderProfile provider;
  final AppUser? user;
  final DateFormat dateFmt;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final name = (user?.fullName ?? '').trim().isNotEmpty ? user!.fullName : 'Provider';
    final service = provider.serviceArea.isNotEmpty ? provider.serviceArea : 'General services';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final stack = c.maxWidth < 360;
          final info = Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: FigmaColors.gray200,
                child: Text(adminInitials(name), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      service,
                      style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Submitted ${dateFmt.format(provider.createdAt.toDate())}',
                      style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray400),
                    ),
                  ],
                ),
              ),
            ],
          );
          final reviewBtn = OutlinedButton(
            onPressed: onReview,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.green,
              side: const BorderSide(color: FigmaColors.green),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Review', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: reviewBtn)],
            );
          }
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [info, reviewBtn],
          );
        },
      ),
    );
  }
}
