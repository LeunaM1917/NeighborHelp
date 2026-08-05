import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../theme/mobile_layout.dart';
import '../../../widgets/mobile_stat_row.dart';
import '../../../models/booking.dart';
import '../../../theme/role_theme.dart';

class ProviderDashboardHero extends StatelessWidget {
  const ProviderDashboardHero({
    super.key,
    required this.firstName,
    this.showSuccessBanner = true,
  });

  final String firstName;
  final bool showSuccessBanner;

  @override
  Widget build(BuildContext context) {
    return FigmaHeroGradientBackground(
      child: FigmaWideContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: MobileLayout.heroVerticalPadding(context)),
          child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 720;
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName',
                  style: GoogleFonts.inter(
                    fontSize: wide ? 36 : 28,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.gray900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Manage your services, bookings, and job requests in one place.',
                  style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45),
                ),
                if (showSuccessBanner) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: FigmaColors.navy, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "You're all set! Keep up the great work.",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: FigmaColors.gray700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );

            if (!wide) {
              final compact = MobileLayout.isNativeApp(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  if (!compact) ...[const SizedBox(height: 24), const _HeroIllustration()],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: text),
                const SizedBox(width: 24),
                const _HeroIllustration(),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 8,
            bottom: 0,
            child: Container(
              width: 120,
              height: 88,
              decoration: BoxDecoration(
                color: FigmaColors.tintBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FigmaColors.navy.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.home_rounded, size: 52, color: FigmaColors.navy),
            ),
          ),
          Positioned(
            right: 0,
            top: 8,
            child: Icon(Icons.park_outlined, size: 36, color: FigmaColors.navy.withValues(alpha: 0.55)),
          ),
          Positioned(
            left: 24,
            bottom: 20,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FigmaColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.handshake_outlined, color: FigmaColors.navy, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderDashboardStatsRow extends StatelessWidget {
  const ProviderDashboardStatsRow({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.completedTrendLabel,
    required this.pendingRequests,
    required this.activeServices,
  });

  final double rating;
  final int reviewCount;
  final int completedJobs;
  final String completedTrendLabel;
  final int pendingRequests;
  final int activeServices;

  @override
  Widget build(BuildContext context) {
    final compact = MobileLayout.isNativeApp(context);
    final cards = [
      _DashboardStatCard(
        icon: Icons.star_rounded,
        iconColor: const Color(0xFFEAB308),
        iconBg: FigmaColors.yellow50,
        value: rating > 0 ? rating.toStringAsFixed(1) : '—',
        title: 'Rating',
        subtitle: reviewCount > 0 ? 'Based on $reviewCount reviews' : 'No reviews yet',
        trailing: rating > 0 && !compact ? _StarRow(rating: rating) : null,
        compact: compact,
      ),
      _DashboardStatCard(
        icon: Icons.check_circle,
        iconColor: FigmaColors.navy,
        iconBg: FigmaColors.tintBlue,
        value: '$completedJobs',
        title: 'Completed Jobs',
        subtitle: completedTrendLabel,
        subtitleColor: FigmaColors.navy,
        compact: compact,
      ),
      _DashboardStatCard(
        icon: Icons.schedule,
        iconColor: FigmaColors.navy,
        iconBg: FigmaColors.tintBlue,
        value: '$pendingRequests',
        title: 'Pending Requests',
        subtitle: 'Requires your response',
        compact: compact,
      ),
      _DashboardStatCard(
        icon: Icons.work_outline,
        iconColor: FigmaColors.purple600,
        iconBg: FigmaColors.purple50,
        value: '$activeServices',
        title: 'Active Services',
        subtitle: 'Visible to customers',
        compact: compact,
      ),
    ];

    return MobileStatCardRow(cards: cards);
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = rating >= i + 1 - 0.25;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: const Color(0xFFEAB308),
        );
      }),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 36.0 : 44.0;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: compact ? 20 : 24),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: compact ? 26 : 32,
              fontWeight: FontWeight.w700,
              color: FigmaColors.gray900,
              height: 1.05,
            ),
          ),
          if (trailing != null) ...[SizedBox(height: compact ? 4 : 6), trailing!],
          SizedBox(height: compact ? 6 : 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 13,
              height: 1.25,
              color: subtitleColor ?? FigmaColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderDashboardPanel extends StatelessWidget {
  const ProviderDashboardPanel({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
  });

  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class ProviderRecentJobRow {
  ProviderRecentJobRow({
    required this.booking,
    required this.customerName,
    required this.serviceTitle,
  });

  final Booking booking;
  final String customerName;
  final String serviceTitle;
}

class ProviderRecentJobRequestsPanel extends StatelessWidget {
  const ProviderRecentJobRequestsPanel({
    super.key,
    required this.rows,
    required this.onViewAll,
    this.onRespond,
    this.onView,
  });

  final List<ProviderRecentJobRow> rows;
  final VoidCallback onViewAll;
  final void Function(Booking booking)? onRespond;
  final void Function(Booking booking)? onView;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return ProviderDashboardPanel(
      title: 'Recent Job Requests',
      trailing: TextButton(
        onPressed: onViewAll,
        child: Text('View all', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: rc.primary)),
      ),
      padding: EdgeInsets.zero,
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'No job requests yet. New bookings will appear here.',
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
                  _RecentJobTile(
                    row: rows[i],
                    onRespond: onRespond,
                    onView: onView,
                  ),
                ],
              ],
            ),
    );
  }
}

class _RecentJobTile extends StatelessWidget {
  const _RecentJobTile({required this.row, this.onRespond, this.onView});

  final ProviderRecentJobRow row;
  final void Function(Booking booking)? onRespond;
  final void Function(Booking booking)? onView;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final nativeMobile = MobileLayout.isNativeApp(context);
    final b = row.booking;
    final status = b.status.toLowerCase();
    final isNew = status == 'pending' &&
        DateTime.now().difference(b.createdAt.toDate()).inHours < 48;
    final badgeLabel = isNew ? 'New' : _statusLabel(status);
    final badgeColor = isNew
        ? FigmaColors.orange600
        : status == 'pending'
            ? FigmaColors.navy
            : FigmaColors.navy;
    final badgeBg = isNew
        ? FigmaColors.orange50
        : status == 'pending'
            ? FigmaColors.tintBlue
            : FigmaColors.tintBlue;
    final initials = _initials(row.customerName);
    final avatarColor = _avatarColor(row.customerName);
    final schedule = b.scheduledWindowLabel;
    final location = b.serviceLocation.isNotEmpty ? b.serviceLocation : 'Location TBD';

    Widget statusBadge() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          badgeLabel,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: badgeColor),
        ),
      );
    }

    Widget actionButton() {
      if (status == 'pending') {
        return OutlinedButton(
          onPressed: onRespond == null ? null : () => onRespond!(b),
          style: OutlinedButton.styleFrom(
            foregroundColor: rc.primary,
            side: BorderSide(color: rc.primary),
            minimumSize: Size(nativeMobile ? double.infinity : 88, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('Review request', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
        );
      }
      return OutlinedButton(
        onPressed: onView == null ? null : () => onView!(b),
        style: OutlinedButton.styleFrom(
          foregroundColor: rc.primary,
          side: BorderSide(color: rc.primary),
          minimumSize: Size(nativeMobile ? double.infinity : 88, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('View', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
      );
    }

    if (nativeMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    initials,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: avatarColor, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.serviceTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                statusBadge(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: FigmaColors.gray500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    schedule,
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: FigmaColors.gray500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            actionButton(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarColor.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: avatarColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.customerName,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                ),
                const SizedBox(height: 2),
                Text(row.serviceTitle, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: FigmaColors.gray500),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        schedule,
                        style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: FigmaColors.gray500),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        location,
                        style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              statusBadge(),
              const SizedBox(height: 8),
              actionButton(),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      FigmaColors.navy,
      FigmaColors.navy,
      FigmaColors.purple600,
      FigmaColors.orange600,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'milestone complete':
        return 'Milestone done';
      default:
        return status.isEmpty ? 'Pending' : status[0].toUpperCase() + status.substring(1);
    }
  }
}

class ProviderPerformanceOverviewPanel extends StatefulWidget {
  const ProviderPerformanceOverviewPanel({super.key, required this.bookings});

  final List<Booking> bookings;

  @override
  State<ProviderPerformanceOverviewPanel> createState() => _ProviderPerformanceOverviewPanelState();
}

class _ProviderPerformanceOverviewPanelState extends State<ProviderPerformanceOverviewPanel> {
  String _range = 'This Month';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final completedThisMonth = _completedInMonth(widget.bookings, now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    final completedLastMonth = _completedInMonth(widget.bookings, lastMonth.year, lastMonth.month);
    final trendPct = completedLastMonth > 0
        ? (((completedThisMonth - completedLastMonth) / completedLastMonth) * 100).round()
        : (completedThisMonth > 0 ? 100 : 0);
    final trendUp = trendPct >= 0;
    final prevLabel = DateFormat('MMM d').format(DateTime(lastMonth.year, lastMonth.month, 1));
    final prevEnd = DateFormat('MMM d').format(DateTime(lastMonth.year, lastMonth.month + 1, 0));

    return ProviderDashboardPanel(
      title: 'Performance Overview',
      trailing: SizedBox(
        width: 140,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: FigmaColors.gray300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _range,
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: FigmaColors.gray800),
              items: const [
                DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _range = v);
              },
            ),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 520;
          final metrics = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Completed Jobs', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
              const SizedBox(height: 6),
              Text(
                '$completedThisMonth',
                style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    trendUp ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: trendUp ? FigmaColors.navy : FigmaColors.red600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trendUp ? '↑' : '↓'} ${trendPct.abs()}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: trendUp ? FigmaColors.navy : FigmaColors.red600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'vs $prevLabel – $prevEnd',
                style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
              ),
            ],
          );

          final chart = SizedBox(
            height: 180,
            child: _CompletedJobsLineChart(
              bookings: widget.bookings,
              year: _range == 'This Month' ? now.year : lastMonth.year,
              month: _range == 'This Month' ? now.month : lastMonth.month,
            ),
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [metrics, const SizedBox(height: 20), chart],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 160, child: metrics),
              const SizedBox(width: 24),
              Expanded(child: chart),
            ],
          );
        },
      ),
    );
  }

  int _completedInMonth(List<Booking> bookings, int year, int month) {
    return bookings.where((b) {
      if (b.status.toLowerCase() != 'completed') return false;
      final d = b.updatedAt.toDate();
      return d.year == year && d.month == month;
    }).length;
  }
}

class _CompletedJobsLineChart extends StatelessWidget {
  const _CompletedJobsLineChart({
    required this.bookings,
    required this.year,
    required this.month,
  });

  final List<Booking> bookings;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final counts = List<double>.filled(daysInMonth, 0);
    for (final b in bookings) {
      if (b.status.toLowerCase() != 'completed') continue;
      final d = b.updatedAt.toDate();
      if (d.year == year && d.month == month) counts[d.day - 1]++;
    }

    final maxVal = counts.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxVal < 1 ? 4.0 : (maxVal + 1).ceilToDouble();
    final spots = [for (var i = 0; i < daysInMonth; i++) FlSpot(i.toDouble(), counts[i])];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 4 ? 2 : 1,
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
                style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray500),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: daysInMonth > 20 ? 7 : 5,
              getTitlesWidget: (v, _) {
                final day = v.toInt() + 1;
                if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                if (day != 1 && day != daysInMonth && day % 7 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MMM d').format(DateTime(year, month, day)),
                    style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray500),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => FigmaColors.white,
            tooltipBorder: const BorderSide(color: FigmaColors.gray200),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final count = spot.y.toInt();
                return LineTooltipItem(
                  count == 1 ? '1 job' : '$count jobs',
                  GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.navy,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: FigmaColors.navy,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: FigmaColors.navy,
                strokeWidth: 1.5,
                strokeColor: FigmaColors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: FigmaColors.tintBlue.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderQuickActionsPanel extends StatelessWidget {
  const ProviderQuickActionsPanel({
    super.key,
    required this.onAddService,
    required this.onManageServices,
    required this.onViewMessages,
    required this.onUpdateAvailability,
  });

  final VoidCallback onAddService;
  final VoidCallback onManageServices;
  final VoidCallback onViewMessages;
  final VoidCallback onUpdateAvailability;

  @override
  Widget build(BuildContext context) {
    return ProviderDashboardPanel(
      title: 'Quick Actions',
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          _QuickActionTile(
            icon: Icons.add_box_outlined,
            iconColor: FigmaColors.navy,
            iconBg: FigmaColors.tintBlue,
            title: 'Add New Service',
            subtitle: 'List a new service for customers',
            onTap: onAddService,
          ),
          _QuickActionTile(
            icon: Icons.grid_view_rounded,
            iconColor: FigmaColors.navy,
            iconBg: FigmaColors.tintBlue,
            title: 'Manage Services',
            subtitle: 'Edit pricing, availability, and details',
            onTap: onManageServices,
          ),
          _QuickActionTile(
            icon: Icons.chat_bubble_outline,
            iconColor: FigmaColors.purple600,
            iconBg: FigmaColors.purple50,
            title: 'View Messages',
            subtitle: 'Check and respond to messages',
            onTap: onViewMessages,
          ),
          _QuickActionTile(
            icon: Icons.calendar_month_outlined,
            iconColor: FigmaColors.orange600,
            iconBg: FigmaColors.orange50,
            title: 'Update Availability',
            subtitle: 'Set your schedule and working hours',
            onTap: onUpdateAvailability,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: FigmaColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}

