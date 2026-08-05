import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

int bookingStatusBucket(String status) {
  final s = status.toLowerCase();
  if (s == 'completed') return 0;
  if (s == 'cancelled' || s == 'canceled' || s == 'disputed') return 2;
  return 1;
}

String truncateUid(String id, {int head = 7}) {
  if (id.length <= head + 3) return id;
  return '${id.substring(0, head)}…';
}

class AdminBookingTableRow {
  const AdminBookingTableRow({
    required this.booking,
    required this.customer,
    required this.provider,
  });

  final Booking booking;
  final AppUser? customer;
  final AppUser? provider;

  String get customerLabel {
    final name = (customer?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    return truncateUid(booking.customerId);
  }

  String get providerLabel {
    final name = (provider?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    return truncateUid(booking.providerId);
  }

  String get shortBookingId =>
      booking.bookingId.length > 8 ? booking.bookingId.substring(0, 8) : booking.bookingId;
}

class AdminBookingStatusChip extends StatelessWidget {
  const AdminBookingStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final bucket = bookingStatusBucket(status);
    Color bg;
    Color fg;
    String label;
    switch (bucket) {
      case 0:
        bg = FigmaColors.tintGreen;
        fg = FigmaColors.green;
        label = 'Completed';
      case 2:
        bg = FigmaColors.red50;
        fg = FigmaColors.red600;
        label = status.toLowerCase() == 'disputed' ? 'Disputed' : 'Cancelled';
      default:
        bg = FigmaColors.orange50;
        fg = FigmaColors.orange600;
        label = status.trim().isEmpty ? 'In Progress' : status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

class AdminBookingsTablePanel extends StatelessWidget {
  const AdminBookingsTablePanel({
    super.key,
    required this.rows,
    required this.searchController,
    required this.statusFilter,
    required this.dateFilter,
    required this.onStatusFilterChanged,
    required this.onDateFilterChanged,
    required this.onSearchChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onExport,
    required this.onView,
    required this.onCopyId,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onMenu,
  });

  final List<AdminBookingTableRow> rows;
  final TextEditingController searchController;
  final String statusFilter;
  final String dateFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onDateFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final String? selectedId;
  final void Function(AdminBookingTableRow row, bool selected) onSelect;
  final VoidCallback onExport;
  final ValueChanged<AdminBookingTableRow> onView;
  final ValueChanged<String> onCopyId;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final void Function(AdminBookingTableRow row, String action) onMenu;

  static const statusFilters = [
    'All Statuses',
    'Completed',
    'In Progress',
    'Pending',
    'Cancelled / Disputed',
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
    final dateFmt = DateFormat('MMM d, yyyy');
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, rows.length);
    final pageItems = rows.length <= start
        ? <AdminBookingTableRow>[]
        : rows.sublist(start, end.clamp(0, rows.length));

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
                Row(
                  children: [
                    const Icon(Icons.event_note_outlined, size: 22, color: FigmaColors.gray700),
                    const SizedBox(width: 8),
                    Text(
                      'Bookings (${rows.length})',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.info_outline, size: 16, color: FigmaColors.gray400),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Search and manage bookings across customers and providers.',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
                const SizedBox(height: 16),
                AdminTableFilterToolbar(
                  search: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search bookings…',
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
                    adminFilterDropdown(
                      value: statusFilter,
                      options: statusFilters,
                      onChanged: onStatusFilterChanged,
                    ),
                    _filterDropdown(
                      value: dateFilter,
                      options: dateFilters,
                      onChanged: onDateFilterChanged,
                      expanded: true,
                      prefix: Icons.calendar_today_outlined,
                    ),
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
                child: Text(
                  'No bookings match your filters.',
                  style: GoogleFonts.inter(color: FigmaColors.gray500),
                ),
              ),
            )
          else
            AdminHorizontalScrollTable(
              minTableWidth: 1100,
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
                dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
                columns: const [
                  DataColumn(label: Text('Booking ID')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Scheduled')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final row in pageItems)
                    DataRow(
                      selected: selectedId == row.booking.bookingId,
                      onSelectChanged: (v) => onSelect(row, v ?? false),
                      cells: [
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onView(row),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  row.shortBookingId,
                                  style: GoogleFonts.robotoMono(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: FigmaColors.navy,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.copy_outlined, size: 16, color: FigmaColors.gray500),
                                tooltip: 'Copy booking ID',
                                onPressed: () => onCopyId(row.booking.bookingId),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onView(row),
                            child: Text(row.customerLabel, softWrap: false, style: GoogleFonts.inter(color: FigmaColors.navy)),
                          ),
                        ),
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onView(row),
                            child: Text(row.providerLabel, softWrap: false, style: GoogleFonts.inter(color: FigmaColors.navy)),
                          ),
                        ),
                        DataCell(Text(dateFmt.format(row.booking.scheduledDate.toDate()), softWrap: false)),
                        DataCell(AdminBookingStatusChip(status: row.booking.status)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => onView(row),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: FigmaColors.gray800,
                                  side: const BorderSide(color: FigmaColors.gray300),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('View', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: FigmaColors.gray600),
                                onSelected: (action) => onMenu(row, action),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'status', child: Text('Update status')),
                                  PopupMenuItem(value: 'customer', child: Text('View customer')),
                                  PopupMenuItem(value: 'provider', child: Text('View provider')),
                                  PopupMenuItem(value: 'copy', child: Text('Copy booking ID')),
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
            child: _BookingsPagination(
              total: rows.length,
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

  static Widget _filterDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    bool expanded = false,
    IconData? prefix,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: expanded,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Row(
                  children: [
                    if (prefix != null && o == value) ...[
                      Icon(prefix, size: 16, color: FigmaColors.gray500),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: Text(o)),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _BookingsPagination extends StatelessWidget {
  const _BookingsPagination({
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
          'Showing $start to $end of $total booking${total == 1 ? '' : 's'}',
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

class AdminBookingInsightsPanel extends StatelessWidget {
  const AdminBookingInsightsPanel({
    super.key,
    required this.completed,
    required this.inProgress,
    required this.cancelled,
  });

  final int completed;
  final int inProgress;
  final int cancelled;

  @override
  Widget build(BuildContext context) {
    final total = completed + inProgress + cancelled;
    if (total == 0) {
      return AdminPanelCard(
        title: '',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Insights', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('No bookings yet', style: GoogleFonts.inter(color: FigmaColors.gray500)),
            ],
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[
      if (completed > 0)
        PieChartSectionData(value: completed.toDouble(), color: FigmaColors.green, radius: 40, showTitle: false),
      if (inProgress > 0)
        PieChartSectionData(value: inProgress.toDouble(), color: FigmaColors.orange600, radius: 40, showTitle: false),
      if (cancelled > 0)
        PieChartSectionData(value: cancelled.toDouble(), color: FigmaColors.red600, radius: 40, showTitle: false),
    ];
    String pct(int n) => '${((n / total) * 100).toStringAsFixed(0)}%';

    return AdminPanelCard(
      title: '',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_outlined, size: 20, color: FigmaColors.gray700),
                const SizedBox(width: 8),
                Text('Booking Insights', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 3,
                      centerSpaceRadius: 48,
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
            _BookingLegend(color: FigmaColors.green, label: 'Completed', count: completed, percent: pct(completed)),
            _BookingLegend(
              color: FigmaColors.orange600,
              label: 'In Progress',
              count: inProgress,
              percent: pct(inProgress),
            ),
            _BookingLegend(
              color: FigmaColors.red600,
              label: 'Cancelled / Disputed',
              count: cancelled,
              percent: pct(cancelled),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingLegend extends StatelessWidget {
  const _BookingLegend({
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
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600)),
          ),
          Text('$count ($percent)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AdminBookingLatestActivity extends StatelessWidget {
  const AdminBookingLatestActivity({
    super.key,
    required this.bookings,
    this.onViewAll,
  });

  final List<Booking> bookings;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');

    return AdminPanelCard(
      title: '',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Latest Activity', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.green),
                  ),
                ),
              ],
            ),
            if (bookings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No recent activity', style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 13)),
              )
            else
              for (var i = 0; i < bookings.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
                _ActivityItem(
                  booking: bookings[i],
                  dateFmt: dateFmt,
                  timeFmt: timeFmt,
                  isNew: i == 0,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.booking,
    required this.dateFmt,
    required this.timeFmt,
    required this.isNew,
  });

  final Booking booking;
  final DateFormat dateFmt;
  final DateFormat timeFmt;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final bucket = bookingStatusBucket(booking.status);
    final shortId = booking.bookingId.length > 8 ? booking.bookingId.substring(0, 8) : booking.bookingId;
    final title = switch (bucket) {
      0 => 'Booking Completed',
      2 => 'Booking Cancelled',
      _ => 'Booking Updated',
    };
    final subtitle = switch (bucket) {
      0 => 'Booking ID $shortId was marked completed.',
      2 => 'Booking ID $shortId was cancelled.',
      _ => 'Booking ID $shortId status: ${booking.status}.',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bucket == 0 ? FigmaColors.tintGreen : FigmaColors.gray100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              bucket == 0 ? Icons.check_circle_outline : Icons.event_note_outlined,
              color: bucket == 0 ? FigmaColors.green : FigmaColors.gray600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    if (isNew)
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
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
                const SizedBox(height: 4),
                Text(
                  '${dateFmt.format(booking.updatedAt.toDate())} • ${timeFmt.format(booking.updatedAt.toDate())}',
                  style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool bookingMatchesStatusFilter(Booking b, String filter) {
  final bucket = bookingStatusBucket(b.status);
  return switch (filter) {
    'Completed' => bucket == 0,
    'In Progress' => bucket == 1 && b.status.toLowerCase() != 'pending',
    'Pending' => b.status.toLowerCase() == 'pending',
    'Cancelled / Disputed' => bucket == 2,
    _ => true,
  };
}

bool bookingMatchesDateFilter(Booking b, String filter) {
  if (filter == 'All Dates') return true;
  final scheduled = b.scheduledDate.toDate();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (filter) {
    'Today' => scheduled.year == today.year && scheduled.month == today.month && scheduled.day == today.day,
    'This week' => scheduled.isAfter(today.subtract(Duration(days: today.weekday - 1))) &&
        scheduled.isBefore(today.add(const Duration(days: 7))),
    'This month' => scheduled.year == now.year && scheduled.month == now.month,
    'Last 30 days' => scheduled.isAfter(now.subtract(const Duration(days: 30))),
    _ => true,
  };
}
