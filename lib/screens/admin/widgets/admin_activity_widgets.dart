import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import 'admin_chart_touch.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

enum ActivityLogType { booking, provider, service, other }

class AdminActivityEntry {
  const AdminActivityEntry({
    required this.id,
    required this.eventTitle,
    required this.type,
    required this.actorId,
    required this.time,
    required this.status,
    this.referenceId,
    this.booking,
    this.service,
    this.provider,
  });

  final String id;
  final String eventTitle;
  final ActivityLogType type;
  final String actorId;
  final DateTime time;
  final String status;
  final String? referenceId;
  final Booking? booking;
  final ServiceListing? service;
  final ServiceProviderProfile? provider;
}

List<AdminActivityEntry> buildActivityLog({
  required List<Booking> bookings,
  required List<ServiceListing> services,
  required List<ServiceProviderProfile> providers,
}) {
  final entries = <AdminActivityEntry>[];

  for (final b in bookings) {
    final st = b.status.toLowerCase();
    final title = st == 'completed'
        ? 'Booking completed'
        : st == 'cancelled' || st == 'canceled'
            ? 'Booking cancelled'
            : 'Booking ${b.status}';
    entries.add(
      AdminActivityEntry(
        id: 'booking-${b.bookingId}',
        eventTitle: title,
        type: ActivityLogType.booking,
        actorId: b.customerId,
        time: b.updatedAt.toDate(),
        status: _normalizeBookingStatus(b.status),
        referenceId: b.bookingId,
        booking: b,
      ),
    );
  }

  for (final s in services) {
    entries.add(
      AdminActivityEntry(
        id: 'service-${s.serviceId}',
        eventTitle: s.isActive ? 'Service listed' : 'Service deactivated',
        type: ActivityLogType.service,
        actorId: s.providerId,
        time: s.updatedAt.toDate(),
        status: s.isActive ? 'Active' : 'Inactive',
        referenceId: s.serviceId,
        service: s,
      ),
    );
  }

  for (final p in providers) {
    final v = p.verificationStatus.trim();
    final approved = p.isVerified ||
        v.toLowerCase() == 'approved' ||
        v.toLowerCase() == 'verified';
    entries.add(
      AdminActivityEntry(
        id: 'provider-${p.providerId}',
        eventTitle: approved
            ? 'Provider profile — Approved'
            : 'Provider profile — ${v.isEmpty ? 'Pending' : v}',
        type: ActivityLogType.provider,
        actorId: p.userId,
        time: p.updatedAt.toDate(),
        status: approved ? 'Verified' : (v.toLowerCase() == 'rejected' ? 'Rejected' : 'Pending'),
        referenceId: p.providerId,
        provider: p,
      ),
    );
  }

  entries.sort((a, b) => b.time.compareTo(a.time));
  return entries;
}

String _normalizeBookingStatus(String status) {
  final s = status.toLowerCase();
  if (s == 'completed') return 'Completed';
  if (s == 'cancelled' || s == 'canceled') return 'Cancelled';
  if (s == 'in progress' || s == 'in_progress') return 'In Progress';
  if (s == 'accepted') return 'Accepted';
  if (s == 'pending') return 'Pending';
  return status;
}

String truncateActor(String id) {
  if (id.length <= 14) return id;
  return '${id.substring(0, 12)}…';
}

String _activityStatusKey(String status) => status.trim().toLowerCase().replaceAll('_', ' ');

/// Unique chart/legend color per activity status (stable — not index-based).
Color activityStatusChartColor(String status) {
  switch (_activityStatusKey(status)) {
    case 'pending':
      return const Color(0xFFF59E0B);
    case 'active':
      return FigmaColors.green;
    case 'in progress':
      return FigmaColors.orange600;
    case 'verified':
    case 'approved':
      return FigmaColors.navy;
    case 'accepted':
      return const Color(0xFF7C3AED);
    case 'completed':
      return const Color(0xFF0EA5E9);
    case 'inactive':
      return FigmaColors.gray400;
    case 'cancelled':
    case 'canceled':
      return FigmaColors.red600;
    case 'rejected':
    case 'disputed':
      return const Color(0xFFEC4899);
    default:
      return FigmaColors.gray500;
  }
}

(Color bg, Color fg) activityStatusChipColors(String status) {
  final fg = activityStatusChartColor(status);
  final bg = Color.alphaBlend(fg.withValues(alpha: 0.14), FigmaColors.white);
  return (bg, fg);
}

IconData activityEventIcon(ActivityLogType type, String eventTitle) {
  switch (type) {
    case ActivityLogType.booking:
      return Icons.event_available_outlined;
    case ActivityLogType.provider:
      return Icons.verified_user_outlined;
    case ActivityLogType.service:
      return eventTitle.contains('deactivated')
          ? Icons.settings_outlined
          : Icons.home_repair_service_outlined;
    case ActivityLogType.other:
      return Icons.history_outlined;
  }
}

Color activityIconBg(ActivityLogType type) {
  switch (type) {
    case ActivityLogType.booking:
      return const Color(0xFFF3E8FF);
    case ActivityLogType.provider:
      return FigmaColors.tintBlue;
    case ActivityLogType.service:
      return FigmaColors.tintGreen;
    case ActivityLogType.other:
      return FigmaColors.gray100;
  }
}

Color activityIconColor(ActivityLogType type) {
  switch (type) {
    case ActivityLogType.booking:
      return const Color(0xFF7C3AED);
    case ActivityLogType.provider:
      return FigmaColors.navy;
    case ActivityLogType.service:
      return FigmaColors.green;
    case ActivityLogType.other:
      return FigmaColors.gray600;
  }
}

class AdminActivityStatusChip extends StatelessWidget {
  const AdminActivityStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = activityStatusChipColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: fg),
          const SizedBox(width: 6),
          Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

bool activityMatchesTypeFilter(AdminActivityEntry e, String filter) {
  return switch (filter) {
    'Booking Events' => e.type == ActivityLogType.booking,
    'Provider Updates' => e.type == ActivityLogType.provider,
    'Service Changes' => e.type == ActivityLogType.service,
    _ => true,
  };
}

bool activityMatchesStatusFilter(AdminActivityEntry e, String filter) {
  if (filter == 'All Statuses') return true;
  return e.status.toLowerCase() == filter.toLowerCase();
}

bool activityMatchesDateFilter(AdminActivityEntry e, String filter) {
  if (filter == 'All Dates' || filter == 'Date Range') return true;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter) {
    'Today' =>
      e.time.year == today.year && e.time.month == today.month && e.time.day == today.day,
    'This week' => e.time.isAfter(today.subtract(Duration(days: today.weekday))),
    'This month' => e.time.year == now.year && e.time.month == now.month,
    'Last 30 days' => e.time.isAfter(now.subtract(const Duration(days: 30))),
    _ => true,
  };
}

class AdminActivityTablePanel extends StatelessWidget {
  const AdminActivityTablePanel({
    super.key,
    required this.entries,
    required this.searchController,
    required this.typeFilter,
    required this.statusFilter,
    required this.dateFilter,
    required this.onTypeFilterChanged,
    required this.onStatusFilterChanged,
    required this.onDateFilterChanged,
    required this.onSearchChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onExport,
    required this.onView,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onMenu,
  });

  final List<AdminActivityEntry> entries;
  final TextEditingController searchController;
  final String typeFilter;
  final String statusFilter;
  final String dateFilter;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onDateFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final String? selectedId;
  final void Function(AdminActivityEntry entry, bool selected) onSelect;
  final VoidCallback onExport;
  final ValueChanged<AdminActivityEntry> onView;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final void Function(AdminActivityEntry entry, String action) onMenu;

  static const typeFilters = [
    'All Activity Types',
    'Booking Events',
    'Provider Updates',
    'Service Changes',
  ];

  static const statusFilters = [
    'All Statuses',
    'Active',
    'Verified',
    'Completed',
    'Pending',
    'Inactive',
    'Cancelled',
  ];

  static const dateFilters = [
    'All Dates',
    'Today',
    'This week',
    'This month',
    'Last 30 days',
  ];

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MMM d, h:mm a');
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, entries.length);
    final pageItems = entries.length <= start
        ? <AdminActivityEntry>[]
        : entries.sublist(start, end.clamp(0, entries.length));

    return AdminPanelCard(
      title: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent activity (${entries.length})',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Synthetic log from collection timestamps (no separate audit collection yet).',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
                const SizedBox(height: 16),
                AdminTableFilterToolbar(
                  search: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search activities…',
                      hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20, color: FigmaColors.gray500),
                      filled: true,
                      fillColor: FigmaColors.gray50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: FigmaColors.gray300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: FigmaColors.gray300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  filters: [
                    adminFilterDropdown(value: typeFilter, options: typeFilters, onChanged: onTypeFilterChanged),
                    adminFilterDropdown(value: statusFilter, options: statusFilters, onChanged: onStatusFilterChanged),
                    adminFilterDropdown(value: dateFilter, options: dateFilters, onChanged: onDateFilterChanged),
                  ],
                  actions: [
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text('Export', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FigmaColors.green,
                        side: const BorderSide(color: FigmaColors.green),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: FigmaColors.gray200),
          if (pageItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text('No activities match your filters.', style: GoogleFonts.inter(color: FigmaColors.gray500)),
              ),
            )
          else
            AdminHorizontalScrollTable(
              minTableWidth: 980,
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
                dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
                columns: const [
                  DataColumn(label: Text('Event')),
                  DataColumn(label: Text('Actor')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final e in pageItems)
                    DataRow(
                      selected: selectedId == e.id,
                      onSelectChanged: (v) => onSelect(e, v ?? false),
                      cells: [
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onView(e),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: activityIconBg(e.type),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    activityEventIcon(e.type, e.eventTitle),
                                    size: 18,
                                    color: activityIconColor(e.type),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    e.eventTitle,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(truncateActor(e.actorId))),
                        DataCell(Text(timeFmt.format(e.time))),
                        DataCell(AdminActivityStatusChip(status: e.status)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdminTableViewButton(onPressed: () => onView(e)),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: FigmaColors.gray600),
                                onSelected: (action) => onMenu(e, action),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'view', child: Text('View details')),
                                  PopupMenuItem(value: 'copy', child: Text('Copy actor ID')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: _ActivityPagination(
              total: entries.length,
              page: page,
              pageSize: pageSize,
              onPageChanged: onPageChanged,
              onPageSizeChanged: onPageSizeChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPagination extends StatelessWidget {
  const _ActivityPagination({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final int total;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages = total == 0 ? 1 : (total / pageSize).ceil();
    final start = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final end = (page * pageSize).clamp(0, total);

    return LayoutBuilder(
      builder: (context, c) {
        final info = Text(
          'Showing $start to $end of $total activit${total == 1 ? 'y' : 'ies'}',
          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
        );
        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FigmaColors.tintGreen,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FigmaColors.green.withValues(alpha: 0.3)),
              ),
              child: Text('$page', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: FigmaColors.green)),
            ),
            IconButton(
              onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FigmaColors.gray300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: pageSize,
                  style: GoogleFonts.inter(fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 per page')),
                    DropdownMenuItem(value: 25, child: Text('25 per page')),
                    DropdownMenuItem(value: 50, child: Text('50 per page')),
                  ],
                  onChanged: (v) {
                    if (v != null) onPageSizeChanged(v);
                  },
                ),
              ),
            ),
          ],
        );
        return AdminTablePaginationBar(info: info, controls: controls);
      },
    );
  }
}

class AdminActivityInsightsPanel extends StatefulWidget {
  const AdminActivityInsightsPanel({super.key, required this.statusCounts});

  final Map<String, int> statusCounts;

  @override
  State<AdminActivityInsightsPanel> createState() => _AdminActivityInsightsPanelState();
}

class _AdminActivityInsightsPanelState extends State<AdminActivityInsightsPanel> {
  int? _touchedSectionIndex;

  @override
  Widget build(BuildContext context) {
    final statusCounts = widget.statusCounts;
    final total = statusCounts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return AdminPanelCard(
        title: 'Activity Insights',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No activity data', style: GoogleFonts.inter(color: FigmaColors.gray500)),
        ),
      );
    }

    final legend = statusCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < legend.length; i++) {
      final entry = legend[i];
      final color = activityStatusChartColor(entry.key);
      final isTouched = _touchedSectionIndex == i;
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          color: color,
          radius: isTouched ? 40 : 36,
          showTitle: isTouched,
          title: '${entry.value}',
          titleStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FigmaColors.white,
          ),
          titlePositionPercentageOffset: 0.55,
        ),
      );
    }

    final touched = _touchedSectionIndex != null &&
        _touchedSectionIndex! >= 0 &&
        _touchedSectionIndex! < legend.length
        ? legend[_touchedSectionIndex!]
        : null;

    return AdminPanelCard(
      title: 'Activity Insights',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            SizedBox(
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      startDegreeOffset: -90,
                      pieTouchData: adminPieChartTouchData(
                        onSectionIndex: (index) => setState(() => _touchedSectionIndex = index),
                      ),
                    ),
                  ),
                  if (touched != null)
                    Positioned(
                      top: 0,
                      child: AdminPieChartTooltip(
                        label: touched.key,
                        value: touched.value,
                        percentLabel: '${((touched.value / total) * 100).round()}%',
                        color: activityStatusChartColor(touched.key),
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
            for (final entry in legend)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: activityStatusChartColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(entry.key, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600)),
                    ),
                    Text(
                      '${entry.value} (${((entry.value / total) * 100).round()}%)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdminActivityHighlightCard extends StatelessWidget {
  const AdminActivityHighlightCard({super.key, this.entry});

  final AdminActivityEntry? entry;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');

    return AdminPanelCard(
      title: 'Recent Highlights',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: entry == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No highlights yet', style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 13)),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FigmaColors.tintGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: FigmaColors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry!.eventTitle.toLowerCase().contains('booking')
                                    ? 'Booking Completed'
                                    : entry!.eventTitle,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: FigmaColors.tintGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'New',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: FigmaColors.green),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry!.referenceId != null
                              ? 'Booking ID ${entry!.referenceId!.length > 8 ? entry!.referenceId!.substring(0, 8) : entry!.referenceId} was marked completed.'
                              : entry!.eventTitle,
                          style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFmt.format(entry!.time)} • ${timeFmt.format(entry!.time)}',
                          style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AdminActivityQuickActions extends StatelessWidget {
  const AdminActivityQuickActions({
    super.key,
    this.onViewBookings,
    this.onViewProviders,
    this.onExportLogs,
    this.onReviewServices,
  });

  final VoidCallback? onViewBookings;
  final VoidCallback? onViewProviders;
  final VoidCallback? onExportLogs;
  final VoidCallback? onReviewServices;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Quick actions',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          children: [
            _ActivityActionRow(
              icon: Icons.event_note_outlined,
              title: 'View Bookings',
              subtitle: 'Inspect bookings and status',
              onTap: onViewBookings,
            ),
            _ActivityActionRow(
              icon: Icons.engineering_outlined,
              title: 'View Providers',
              subtitle: 'Inspect provider details and history',
              onTap: onViewProviders,
            ),
            _ActivityActionRow(
              icon: Icons.file_download_outlined,
              title: 'Export Logs',
              subtitle: 'Download activity logs as CSV',
              onTap: onExportLogs,
            ),
            _ActivityActionRow(
              icon: Icons.home_repair_service_outlined,
              title: 'Review Services',
              subtitle: 'Inspect services and recent changes',
              onTap: onReviewServices,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityActionRow extends StatelessWidget {
  const _ActivityActionRow({
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

