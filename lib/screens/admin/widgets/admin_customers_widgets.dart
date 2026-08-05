import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/account_status.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

class AdminCustomerStatusChip extends StatelessWidget {
  const AdminCustomerStatusChip({super.key, required this.status});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case AccountStatus.active:
        bg = FigmaColors.tintGreen;
        fg = FigmaColors.green;
      case AccountStatus.suspended:
        bg = FigmaColors.red50;
        fg = FigmaColors.red600;
      case AccountStatus.pending:
        bg = FigmaColors.orange50;
        fg = FigmaColors.orange600;
      case AccountStatus.deactivated:
        bg = FigmaColors.gray100;
        fg = FigmaColors.gray600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.firestoreValue,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class AdminCustomersTablePanel extends StatelessWidget {
  const AdminCustomersTablePanel({
    super.key,
    required this.customers,
    required this.bookingCounts,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onExport,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onStatusMenu,
    required this.onOpenDetail,
  });

  final List<AppUser> customers;
  final Map<String, int> bookingCounts;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final String? selectedId;
  final void Function(AppUser user, bool selected) onSelect;
  final VoidCallback onExport;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final void Function(AppUser user, String action) onStatusMenu;
  final ValueChanged<AppUser> onOpenDetail;

  static const statusFilters = ['All Status', 'Active', 'Suspended', 'Pending', 'Deactivated'];

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, customers.length);
    final pageItems = customers.length <= start ? <AppUser>[] : customers.sublist(start, end.clamp(0, customers.length));

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
                    const Icon(Icons.people_outline, size: 22, color: FigmaColors.gray700),
                    const SizedBox(width: 8),
                    Text(
                      'Customers (${customers.length})',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Search and manage registered customer accounts',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
                const SizedBox(height: 16),
                AdminTableFilterToolbar(
                  search: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search customers…',
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
                child: Text('No customers match your filters.', style: GoogleFonts.inter(color: FigmaColors.gray500)),
              ),
            )
          else
            AdminHorizontalScrollTable(
              minTableWidth: 1150,
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
                dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
                columns: const [
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Bookings')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Joined')),
                  DataColumn(label: Text('Last Activity')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final u in pageItems)
                    DataRow(
                      selected: selectedId == u.userId,
                      onSelectChanged: (v) => onSelect(u, v ?? false),
                      cells: [
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onOpenDetail(u),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: FigmaColors.tintGreen,
                                  backgroundImage: u.profilePhotoUrl != null ? NetworkImage(u.profilePhotoUrl!) : null,
                                  child: u.profilePhotoUrl == null
                                      ? Text(
                                          adminInitials(u.fullName.isNotEmpty ? u.fullName : u.email),
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.green),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    u.fullName.isNotEmpty ? u.fullName : u.email,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(u.email, softWrap: false)),
                        DataCell(Text('${bookingCounts[u.userId] ?? 0}')),
                        DataCell(AdminCustomerStatusChip(status: u.accountStatus)),
                        DataCell(Text(dateFmt.format(u.createdAt.toDate()), softWrap: false)),
                        DataCell(Text(_relativeTime(u.lastActive ?? u.updatedAt), softWrap: false)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdminTableViewButton(onPressed: () => onOpenDetail(u)),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: FigmaColors.gray600),
                                onSelected: (action) => onStatusMenu(u, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'bookings', child: Text('View bookings')),
                              PopupMenuItem(value: 'suspend', child: Text('Suspend account')),
                              PopupMenuItem(value: 'deactivate', child: Text('Deactivate account')),
                              PopupMenuItem(value: 'notify', child: Text('Send notification')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'active', child: Text('Set Active')),
                              PopupMenuItem(value: 'suspended', child: Text('Set Suspended')),
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
            child: _CustomersPagination(
              total: customers.length,
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

  static String _relativeTime(Timestamp ts) {
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return DateFormat('MMM d, yyyy').format(dt);
    if (diff.inDays >= 1) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours >= 1) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'Just now';
  }
}

class _CustomersPagination extends StatelessWidget {
  const _CustomersPagination({
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
          'Showing $start to $end of $total customer${total == 1 ? '' : 's'}',
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

class AdminCustomerInsightsPanel extends StatelessWidget {
  const AdminCustomerInsightsPanel({
    super.key,
    required this.customer,
    required this.bookings,
  });

  final AppUser? customer;
  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    var completed = 0;
    var upcoming = 0;
    var cancelled = 0;
    for (final b in bookings) {
      final s = b.status.toLowerCase();
      if (s == 'completed') {
        completed++;
      } else if (s == 'cancelled' || s == 'canceled') {
        cancelled++;
      } else {
        upcoming++;
      }
    }
    final bookingTotal = completed + upcoming + cancelled;

    final isActive = customer?.accountStatus == AccountStatus.active;
    final isSuspended = customer?.accountStatus == AccountStatus.suspended;

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
                Text('Customer Insights', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            if (customer == null) ...[
              const SizedBox(height: 24),
              Text(
                'Select a customer to view insights.',
                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
              ),
            ] else ...[
              const SizedBox(height: 20),
              Text('Bookings Overview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final chart = bookingTotal == 0
                      ? Center(child: Text('No bookings', style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 12)))
                      : PieChart(
                          PieChartData(
                            sections: [
                              if (completed > 0)
                                PieChartSectionData(value: completed.toDouble(), color: FigmaColors.green, radius: 32, showTitle: false),
                              if (upcoming > 0)
                                PieChartSectionData(value: upcoming.toDouble(), color: FigmaColors.tintGreen2, radius: 32, showTitle: false),
                              if (cancelled > 0)
                                PieChartSectionData(value: cancelled.toDouble(), color: const Color(0xFF93C5FD), radius: 32, showTitle: false),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            startDegreeOffset: -90,
                          ),
                        );
                  final legend = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InsightLegend('Completed', completed, bookingTotal, FigmaColors.green),
                      _InsightLegend('Upcoming', upcoming, bookingTotal, FigmaColors.green.withValues(alpha: 0.5)),
                      _InsightLegend('Cancelled', cancelled, bookingTotal, const Color(0xFF93C5FD)),
                    ],
                  );
                  if (c.maxWidth < 260) {
                    return Column(
                      children: [
                        SizedBox(height: 120, width: 120, child: chart),
                        const SizedBox(height: 12),
                        legend,
                      ],
                    );
                  }
                  return SizedBox(
                    height: 120,
                    child: Row(
                      children: [
                        SizedBox(width: c.maxWidth * 0.45, child: chart),
                        const SizedBox(width: 8),
                        Expanded(child: legend),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Account Status Distribution', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (isActive)
                        Expanded(
                          flex: isSuspended ? 1 : 1,
                          child: ColoredBox(color: FigmaColors.green),
                        ),
                      if (isSuspended)
                        Expanded(
                          child: ColoredBox(color: FigmaColors.gray300),
                        ),
                      if (!isActive && !isSuspended)
                        const Expanded(child: ColoredBox(color: FigmaColors.orange600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _InsightLegend('Active', isActive ? 1 : 0, 1, FigmaColors.green),
              _InsightLegend('Suspended', isSuspended ? 1 : 0, 1, FigmaColors.gray400),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightLegend extends StatelessWidget {
  const _InsightLegend(this.label, this.count, this.total, this.color);

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? '${((count / total) * 100).toStringAsFixed(0)}%' : '0%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('$count/$pct', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
