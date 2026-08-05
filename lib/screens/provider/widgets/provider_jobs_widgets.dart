import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../theme/mobile_layout.dart';
import '../../../widgets/mobile_stat_row.dart';
import '../../../models/booking.dart';
import '../../../theme/role_theme.dart';
import 'provider_dashboard_widgets.dart';

enum ProviderJobStatusBucket { newRequest, pending, accepted, inProgress, completed, cancelled, other }

ProviderJobStatusBucket jobStatusBucket(Booking booking) {
  final s = booking.status.toLowerCase();
  if (s == 'cancelled' || s == 'canceled') return ProviderJobStatusBucket.cancelled;
  if (s == 'completed' || s == 'milestone complete') return ProviderJobStatusBucket.completed;
  if (s == 'in progress' && booking.startedAt != null) {
    return ProviderJobStatusBucket.inProgress;
  }
  if (s == 'accepted' || booking.canStartJob) return ProviderJobStatusBucket.accepted;
  if (s == 'in progress') return ProviderJobStatusBucket.inProgress;
  if (s == 'pending') {
    final hours = DateTime.now().difference(booking.createdAt.toDate()).inHours;
    if (hours < 48) return ProviderJobStatusBucket.newRequest;
    return ProviderJobStatusBucket.pending;
  }
  return ProviderJobStatusBucket.other;
}

String jobStatusLabel(Booking booking) {
  switch (jobStatusBucket(booking)) {
    case ProviderJobStatusBucket.newRequest:
      return 'New';
    case ProviderJobStatusBucket.pending:
      return 'Pending';
    case ProviderJobStatusBucket.accepted:
      return 'Accepted';
    case ProviderJobStatusBucket.inProgress:
      return 'In Progress';
    case ProviderJobStatusBucket.completed:
      return 'Completed';
    case ProviderJobStatusBucket.cancelled:
      return 'Cancelled';
    case ProviderJobStatusBucket.other:
      final s = booking.status;
      return s.isEmpty ? 'Unknown' : s[0].toUpperCase() + s.substring(1);
  }
}

Color jobStatusColor(Booking booking) {
  switch (jobStatusBucket(booking)) {
    case ProviderJobStatusBucket.newRequest:
      return FigmaColors.yellow500;
    case ProviderJobStatusBucket.pending:
      return FigmaColors.navy;
    case ProviderJobStatusBucket.accepted:
      return FigmaColors.navy;
    case ProviderJobStatusBucket.inProgress:
      return const Color(0xFF3B82F6);
    case ProviderJobStatusBucket.completed:
      return FigmaColors.navy;
    case ProviderJobStatusBucket.cancelled:
      return FigmaColors.red600;
    case ProviderJobStatusBucket.other:
      return FigmaColors.gray600;
  }
}

Color jobStatusBg(Booking booking) {
  switch (jobStatusBucket(booking)) {
    case ProviderJobStatusBucket.newRequest:
      return FigmaColors.yellow50;
    case ProviderJobStatusBucket.pending:
      return FigmaColors.tintBlue;
    case ProviderJobStatusBucket.accepted:
      return FigmaColors.tintBlue;
    case ProviderJobStatusBucket.inProgress:
      return FigmaColors.tintBlue;
    case ProviderJobStatusBucket.completed:
      return FigmaColors.tintBlue;
    case ProviderJobStatusBucket.cancelled:
      return FigmaColors.red50;
    case ProviderJobStatusBucket.other:
      return FigmaColors.gray100;
  }
}

class ProviderJobsHeader extends StatelessWidget {
  const ProviderJobsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MobileLayout.isNativeApp(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking requests',
          style: GoogleFonts.inter(
            fontSize: compact ? 26 : 32,
            fontWeight: FontWeight.w700,
            color: FigmaColors.gray900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Accept, decline, or complete jobs from customers',
          style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45),
        ),
      ],
    );
  }
}

class ProviderJobsStatsRow extends StatelessWidget {
  const ProviderJobsStatsRow({
    super.key,
    required this.total,
    required this.newRequests,
    required this.inProgress,
    required this.completed,
  });

  final int total;
  final int newRequests;
  final int inProgress;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final compact = MobileLayout.isNativeApp(context);
    final cards = [
      _JobsStatCard(
        icon: Icons.layers_outlined,
        iconColor: FigmaColors.navy,
        iconBg: FigmaColors.tintBlue,
        value: '$total',
        title: 'Total Requests',
        subtitle: 'All booking requests',
        compact: compact,
      ),
      _JobsStatCard(
        icon: Icons.mark_email_unread_outlined,
        iconColor: FigmaColors.navy,
        iconBg: FigmaColors.tintBlue,
        value: '$newRequests',
        title: 'New Requests',
        subtitle: 'Awaiting your response',
        subtitleColor: FigmaColors.navy,
        compact: compact,
      ),
      _JobsStatCard(
        icon: Icons.schedule,
        iconColor: FigmaColors.orange600,
        iconBg: FigmaColors.orange50,
        value: '$inProgress',
        title: 'In Progress',
        subtitle: 'Currently active jobs',
        subtitleColor: FigmaColors.orange600,
        compact: compact,
      ),
      _JobsStatCard(
        icon: Icons.shopping_bag_outlined,
        iconColor: FigmaColors.purple600,
        iconBg: FigmaColors.purple50,
        value: '$completed',
        title: 'Completed Jobs',
        subtitle: 'All completed jobs',
        subtitleColor: FigmaColors.purple600,
        compact: compact,
      ),
    ];

    return MobileStatCardRow(cards: cards);
  }
}

class _JobsStatCard extends StatelessWidget {
  const _JobsStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
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
          SizedBox(height: compact ? 10 : 14),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: compact ? 26 : 30,
              fontWeight: FontWeight.w700,
              color: FigmaColors.gray900,
              height: 1.05,
            ),
          ),
          SizedBox(height: compact ? 6 : 4),
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

class ProviderJobsFilterBar extends StatelessWidget {
  const ProviderJobsFilterBar({
    super.key,
    required this.searchController,
    required this.status,
    required this.category,
    required this.sort,
    required this.categories,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onSortChanged,
  });

  final TextEditingController searchController;
  final String status;
  final String category;
  final String sort;
  final List<String> categories;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSortChanged;

  static const statusOptions = ['All statuses', 'New', 'Pending', 'Accepted', 'In Progress', 'Completed', 'Cancelled'];
  static const sortOptions = ['Newest first', 'Oldest first', 'Date: soonest', 'Date: latest'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final search = TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search jobs or customers…',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500),
            prefixIcon: const Icon(Icons.search, size: 20, color: FigmaColors.gray500),
            filled: true,
            fillColor: FigmaColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FigmaColors.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FigmaColors.gray300),
            ),
          ),
        );

        final filters = [
          _JobsFilterDropdown(
            label: 'Status',
            value: status,
            items: statusOptions,
            onChanged: onStatusChanged,
          ),
          _JobsFilterDropdown(
            label: 'Category',
            value: category,
            items: ['All categories', ...categories],
            onChanged: onCategoryChanged,
          ),
          _JobsFilterDropdown(
            label: 'Sort by',
            value: sort,
            items: sortOptions,
            onChanged: onSortChanged,
          ),
        ];

        if (!wide) {
          return Column(
            children: [
              search,
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: filters),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.tune, color: FigmaColors.gray600),
                  tooltip: 'Filters',
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 3, child: search),
            const SizedBox(width: 12),
            for (var i = 0; i < filters.length; i++) ...[
              Expanded(flex: 2, child: filters[i]),
              if (i < filters.length - 1) const SizedBox(width: 12),
            ],
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune, color: FigmaColors.gray600),
              tooltip: 'Filters',
            ),
          ],
        );
      },
    );
  }
}

class _JobsFilterDropdown extends StatelessWidget {
  const _JobsFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: FigmaColors.gray600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: FigmaColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FigmaColors.gray300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
              items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ProviderJobListRow {
  ProviderJobListRow({
    required this.booking,
    required this.customerName,
    required this.serviceTitle,
    required this.category,
  });

  final Booking booking;
  final String customerName;
  final String serviceTitle;
  final String category;
}

class ProviderJobsTablePanel extends StatelessWidget {
  const ProviderJobsTablePanel({
    super.key,
    required this.rows,
    required this.providerId,
    this.hasAnyBookings = true,
    required this.onViewDetails,
    required this.onRespond,
    required this.onStart,
    required this.onComplete,
  });

  final List<ProviderJobListRow> rows;
  final String providerId;
  /// False when the provider has no bookings at all (show onboarding empty state).
  final bool hasAnyBookings;
  final void Function(Booking booking) onViewDetails;
  final Future<void> Function(Booking booking, bool accept) onRespond;
  final Future<void> Function(Booking booking) onStart;
  final Future<void> Function(Booking booking) onComplete;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      final title = hasAnyBookings ? 'No jobs match your filters' : 'No booking requests yet';
      final message = hasAnyBookings
          ? 'Try changing status, category, or search.'
          : 'When a customer sends a booking request for your service, it will appear here.';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.gray200),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FigmaColors.tintBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_available_outlined, color: FigmaColors.navy, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
            ProviderJobTableRow(
              row: rows[i],
              providerId: providerId,
              onViewDetails: () => onViewDetails(rows[i].booking),
              onRespond: onRespond,
              onStart: onStart,
              onComplete: onComplete,
            ),
          ],
        ],
      ),
    );
  }
}

class ProviderJobTableRow extends StatefulWidget {
  const ProviderJobTableRow({
    super.key,
    required this.row,
    required this.providerId,
    required this.onViewDetails,
    required this.onRespond,
    required this.onStart,
    required this.onComplete,
  });

  final ProviderJobListRow row;
  final String providerId;
  final VoidCallback onViewDetails;
  final Future<void> Function(Booking booking, bool accept) onRespond;
  final Future<void> Function(Booking booking) onStart;
  final Future<void> Function(Booking booking) onComplete;

  @override
  State<ProviderJobTableRow> createState() => _ProviderJobTableRowState();
}

class _ProviderJobTableRowState extends State<ProviderJobTableRow> {
  bool _busy = false;

  String get _initials {
    final parts = widget.row.customerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _avatarColor {
    const colors = [FigmaColors.navy, FigmaColors.navy, FigmaColors.purple600, FigmaColors.orange600];
    return colors[widget.row.customerName.hashCode.abs() % colors.length];
  }

  String get _feeLabel {
    final b = widget.row.booking;
    if (b.totalFee != null) return '₱${b.totalFee!.toStringAsFixed(0)} Est. fee';
    final summary = b.pricingSummary;
    if (summary != null) return summary;
    return 'Fee TBD';
  }

  ButtonStyle _filledActionStyle(RolePalette rc) {
    return FilledButton.styleFrom(
      backgroundColor: rc.primary,
      foregroundColor: rc.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  ButtonStyle _outlinedActionStyle(RolePalette rc, {Color? foreground, BorderSide? side}) {
    return OutlinedButton.styleFrom(
      foregroundColor: foreground ?? rc.primary,
      side: side ?? BorderSide(color: rc.primary),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final b = widget.row.booking;
    final status = b.status.toLowerCase();
    final bucket = jobStatusBucket(b);
    final isPending = status == 'pending';
    final canStart = b.canStartJob;
    final canComplete = b.canMarkCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      _initials,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _avatarColor, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.row.serviceTitle,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                        ),
                        if (widget.row.category.isNotEmpty)
                          Text(
                            widget.row.category,
                            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                          ),
                        Text(
                          widget.row.customerName,
                          style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: FigmaColors.gray500),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      b.scheduledWindowLabel,
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
                      b.serviceLocation.isNotEmpty ? b.serviceLocation : 'Location TBD',
                      style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _feeLabel,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
              ),
            ],
          );

          Widget actionButtons() {
            if (isPending && bucket != ProviderJobStatusBucket.completed) {
              return FilledButton(
                onPressed: widget.onViewDetails,
                style: _filledActionStyle(rc),
                child: const Text('Review request'),
              );
            }
            if (canStart) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () async {
                      setState(() => _busy = true);
                      await widget.onStart(b);
                      if (mounted) setState(() => _busy = false);
                    },
                    style: _filledActionStyle(rc),
                    child: const Text('Start job'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.onViewDetails,
                    style: _outlinedActionStyle(rc),
                    child: const Text('View Details'),
                  ),
                ],
              );
            }
            if (canComplete) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () async {
                      setState(() => _busy = true);
                      await widget.onComplete(b);
                      if (mounted) setState(() => _busy = false);
                    },
                    style: _filledActionStyle(rc),
                    child: const Text('Complete milestone'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.onViewDetails,
                    style: _outlinedActionStyle(rc),
                    child: const Text('View Details'),
                  ),
                ],
              );
            }
            return OutlinedButton(
              onPressed: widget.onViewDetails,
              style: _outlinedActionStyle(rc),
              child: const Text('View Details'),
            );
          }

          final actions = _busy
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: jobStatusBg(b),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        jobStatusLabel(b),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: jobStatusColor(b),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    actionButtons(),
                  ],
                );

          final actionsSlot = Align(
            alignment: wide ? Alignment.topRight : Alignment.centerLeft,
            child: actions,
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 12), actionsSlot],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              actionsSlot,
            ],
          );
        },
      ),
    );
  }
}

class ProviderJobsPagination extends StatelessWidget {
  const ProviderJobsPagination({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final nativeMobile = MobileLayout.isNativeApp(context);
    final totalPages = total == 0 ? 1 : (total / pageSize).ceil();
    final start = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final end = (page * pageSize).clamp(0, total);
    final summary = 'Showing $start to $end of $total requests';

    Widget pageControls() {
      if (totalPages <= 1) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.chevron_left, size: 22),
          ),
          for (var p = 1; p <= totalPages && p <= 5; p++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: nativeMobile ? 1 : 2),
              child: TextButton(
                onPressed: () => onPageChanged(p),
                style: TextButton.styleFrom(
                  backgroundColor: p == page ? FigmaColors.tintBlue : null,
                  foregroundColor: p == page ? FigmaColors.navy : FigmaColors.gray600,
                  minimumSize: Size(nativeMobile ? 32 : 36, nativeMobile ? 32 : 36),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('$p', style: GoogleFonts.inter(fontSize: nativeMobile ? 13 : 14)),
              ),
            ),
          IconButton(
            onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.chevron_right, size: 22),
          ),
        ],
      );
    }

    if (nativeMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
          ),
          if (totalPages > 1) ...[
            const SizedBox(height: 8),
            Center(child: pageControls()),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            summary,
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
          ),
        ),
        pageControls(),
      ],
    );
  }
}

class ProviderJobsOverviewPanel extends StatelessWidget {
  const ProviderJobsOverviewPanel({
    super.key,
    required this.newCount,
    required this.acceptedCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  final int newCount;
  final int acceptedCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;

  @override
  Widget build(BuildContext context) {
    final total = newCount + acceptedCount + inProgressCount + completedCount + cancelledCount;
    String pct(int n) => total > 0 ? '${((n / total) * 100).round()}%' : '0%';

    final sections = <PieChartSectionData>[
      if (newCount > 0)
        PieChartSectionData(value: newCount.toDouble(), color: FigmaColors.yellow500, radius: 38, showTitle: false),
      if (acceptedCount > 0)
        PieChartSectionData(
          value: acceptedCount.toDouble(),
          color: FigmaColors.green,
          radius: 38,
          showTitle: false,
        ),
      if (inProgressCount > 0)
        PieChartSectionData(
          value: inProgressCount.toDouble(),
          color: const Color(0xFF3B82F6),
          radius: 38,
          showTitle: false,
        ),
      if (completedCount > 0)
        PieChartSectionData(value: completedCount.toDouble(), color: FigmaColors.navy, radius: 38, showTitle: false),
      if (cancelledCount > 0)
        PieChartSectionData(value: cancelledCount.toDouble(), color: FigmaColors.red600, radius: 38, showTitle: false),
    ];

    return ProviderDashboardPanel(
      title: 'Jobs Overview',
      child: total == 0
          ? Text('No jobs yet', style: GoogleFonts.inter(color: FigmaColors.gray500))
          : Column(
              children: [
                SizedBox(
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (sections.isNotEmpty)
                        PieChart(
                          PieChartData(
                            sections: sections,
                            sectionsSpace: 3,
                            centerSpaceRadius: 50,
                            startDegreeOffset: -90,
                          ),
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
                          Text('Total', style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _LegendRow(color: FigmaColors.yellow500, label: 'New', count: newCount, percent: pct(newCount)),
                _LegendRow(color: FigmaColors.green, label: 'Accepted', count: acceptedCount, percent: pct(acceptedCount)),
                _LegendRow(
                  color: const Color(0xFF3B82F6),
                  label: 'In Progress',
                  count: inProgressCount,
                  percent: pct(inProgressCount),
                ),
                _LegendRow(
                  color: FigmaColors.navy,
                  label: 'Completed',
                  count: completedCount,
                  percent: pct(completedCount),
                ),
                _LegendRow(
                  color: FigmaColors.red600,
                  label: 'Cancelled',
                  count: cancelledCount,
                  percent: pct(cancelledCount),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'View full report',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
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
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700))),
          Text('$count', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(percent, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
        ],
      ),
    );
  }
}

class ProviderJobsQuickActionsPanel extends StatelessWidget {
  const ProviderJobsQuickActionsPanel({
    super.key,
    required this.onViewMessages,
    required this.onUpdateAvailability,
    required this.onManageServices,
    required this.onViewEarnings,
  });

  final VoidCallback onViewMessages;
  final VoidCallback onUpdateAvailability;
  final VoidCallback onManageServices;
  final VoidCallback onViewEarnings;

  @override
  Widget build(BuildContext context) {
    return ProviderDashboardPanel(
      title: 'Quick Actions',
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          _QuickTile(icon: Icons.chat_bubble_outline, color: FigmaColors.purple600, bg: FigmaColors.purple50, label: 'View Messages', onTap: onViewMessages),
          _QuickTile(icon: Icons.calendar_month_outlined, color: FigmaColors.orange600, bg: FigmaColors.orange50, label: 'Update Availability', onTap: onUpdateAvailability),
          _QuickTile(icon: Icons.grid_view_rounded, color: FigmaColors.navy, bg: FigmaColors.tintBlue, label: 'Manage Services', onTap: onManageServices),
          _QuickTile(icon: Icons.payments_outlined, color: FigmaColors.navy, bg: FigmaColors.tintBlue, label: 'View Earnings', onTap: onViewEarnings),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderJobsResponseTipCard extends StatelessWidget {
  const ProviderJobsResponseTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.tintBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.navy.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: FigmaColors.navy, size: 22),
              const SizedBox(width: 8),
              Text(
                'Response tip',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Respond within 1 hour to new requests to increase your booking rate.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: rc.primary,
              side: BorderSide(color: rc.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Learn more', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

List<Booking> filterProviderJobs({
  required List<Booking> bookings,
  required String query,
  required String status,
  required String category,
  required String sort,
  required Map<String, String> serviceCategories,
  required Map<String, String> customerNames,
}) {
  var list = List<Booking>.from(bookings);

  if (query.trim().isNotEmpty) {
    final q = query.trim().toLowerCase();
    list = list.where((b) {
      final cat = serviceCategories[b.serviceId] ?? '';
      final customer = customerNames[b.customerId] ?? '';
      return b.serviceLocation.toLowerCase().contains(q) ||
          cat.toLowerCase().contains(q) ||
          customer.toLowerCase().contains(q);
    }).toList();
  }

  if (status != 'All statuses') {
    list = list.where((b) {
      final label = jobStatusLabel(b);
      return label == status;
    }).toList();
  }

  if (category != 'All categories') {
    list = list.where((b) => serviceCategories[b.serviceId] == category).toList();
  }

  switch (sort) {
    case 'Oldest first':
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case 'Date: soonest':
      list.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    case 'Date: latest':
      list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    default:
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  return list;
}

Map<String, int> countJobBuckets(List<Booking> bookings) {
  var newC = 0;
  var pending = 0;
  var accepted = 0;
  var inProgress = 0;
  var completed = 0;
  var cancelled = 0;
  for (final b in bookings) {
    switch (jobStatusBucket(b)) {
      case ProviderJobStatusBucket.newRequest:
        newC++;
      case ProviderJobStatusBucket.pending:
        pending++;
      case ProviderJobStatusBucket.accepted:
        accepted++;
      case ProviderJobStatusBucket.inProgress:
        inProgress++;
      case ProviderJobStatusBucket.completed:
        completed++;
      case ProviderJobStatusBucket.cancelled:
        cancelled++;
      case ProviderJobStatusBucket.other:
        break;
    }
  }
  return {
    'new': newC,
    'pending': pending,
    'accepted': accepted,
    'inProgress': inProgress,
    'completed': completed,
    'cancelled': cancelled,
  };
}
