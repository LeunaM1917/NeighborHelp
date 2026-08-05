import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

class AdminServiceListingStatusChip extends StatelessWidget {
  const AdminServiceListingStatusChip({super.key, required this.service});

  final ServiceListing service;

  @override
  Widget build(BuildContext context) {
    final status = service.approvalStatus;
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case ServiceApprovalStatus.pending:
        bg = FigmaColors.orange50;
        fg = FigmaColors.orange600;
        label = 'Pending review';
      case ServiceApprovalStatus.approved:
        if (service.isActive) {
          bg = FigmaColors.tintGreen;
          fg = FigmaColors.green;
          label = 'Live';
        } else {
          bg = FigmaColors.tintBlue;
          fg = FigmaColors.navy;
          label = 'Paused';
        }
      case ServiceApprovalStatus.rejected:
        bg = FigmaColors.red50;
        fg = FigmaColors.red600;
        label = 'Rejected';
      case ServiceApprovalStatus.draft:
        bg = FigmaColors.gray100;
        fg = FigmaColors.gray600;
        label = 'Draft';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class AdminServiceTableRow {
  const AdminServiceTableRow({
    required this.service,
    required this.providerUser,
    required this.providerProfile,
  });

  final ServiceListing service;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;

  String get providerLabel {
    final name = (providerUser?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    return service.providerId;
  }

  String get providerArea => providerProfile?.serviceArea ?? '';
}

IconData serviceCategoryIcon(String category, String title) {
  final c = '${category.toLowerCase()} ${title.toLowerCase()}';
  if (c.contains('pet') || c.contains('dog') || c.contains('walk')) return Icons.pets_outlined;
  if (c.contains('plumb')) return Icons.plumbing_outlined;
  if (c.contains('clean')) return Icons.cleaning_services_outlined;
  if (c.contains('electric')) return Icons.electrical_services_outlined;
  if (c.contains('paint')) return Icons.format_paint_outlined;
  if (c.contains('garden') || c.contains('lawn')) return Icons.yard_outlined;
  if (c.contains('move')) return Icons.local_shipping_outlined;
  if (c.contains('tutor') || c.contains('teach')) return Icons.school_outlined;
  return Icons.home_repair_service_outlined;
}

class AdminServicesTablePanel extends StatelessWidget {
  const AdminServicesTablePanel({
    super.key,
    required this.rows,
    required this.searchController,
    required this.categoryFilter,
    required this.statusFilter,
    required this.categoryOptions,
    required this.onCategoryFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onExport,
    required this.onHide,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onMenu,
    required this.onOpenDetail,
  });

  final List<AdminServiceTableRow> rows;
  final TextEditingController searchController;
  final String categoryFilter;
  final String statusFilter;
  final List<String> categoryOptions;
  final ValueChanged<String> onCategoryFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final String? selectedId;
  final void Function(AdminServiceTableRow row, bool selected) onSelect;
  final VoidCallback onExport;
  final ValueChanged<AdminServiceTableRow> onHide;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final void Function(AdminServiceTableRow row, String action) onMenu;
  final ValueChanged<AdminServiceTableRow> onOpenDetail;

  static const statusFilters = [
    'All Statuses',
    'Pending review',
    'Approved (live)',
    'Rejected',
    'Draft',
    'Hidden (paused)',
  ];

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, rows.length);
    final pageItems = rows.length <= start
        ? <AdminServiceTableRow>[]
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
                    const Icon(Icons.home_repair_service_outlined, size: 22, color: FigmaColors.gray700),
                    const SizedBox(width: 8),
                    Text(
                      'Services (${rows.length})',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Learn more',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.green),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Review pending listings and manage visibility for approved services.',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
                const SizedBox(height: 16),
                AdminTableFilterToolbar(
                  search: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search services…',
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
                      value: categoryFilter,
                      options: categoryOptions,
                      onChanged: onCategoryFilterChanged,
                    ),
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
                child: Text(
                  'No services match your filters.',
                  style: GoogleFonts.inter(color: FigmaColors.gray500),
                ),
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
                dataRowMaxHeight: 80,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
                dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
                columns: const [
                  DataColumn(label: Text('Service')),
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Created / Updated')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final row in pageItems)
                    DataRow(
                      selected: selectedId == row.service.serviceId,
                      onSelectChanged: (v) => onSelect(row, v ?? false),
                      cells: [
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onOpenDetail(row),
                            child: _ServiceNameCell(row: row),
                          ),
                        ),
                        DataCell(_ProviderCell(row: row)),
                        DataCell(Text(row.service.category.isEmpty ? '—' : row.service.category)),
                        DataCell(Text('₱${row.service.estimatedPrice.toStringAsFixed(0)}')),
                        DataCell(AdminServiceListingStatusChip(service: row.service)),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateFmt.format(row.service.updatedAt.toDate())),
                              Text(
                                timeFmt.format(row.service.updatedAt.toDate()),
                                style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdminTableViewButton(onPressed: () => onOpenDetail(row)),
                              const SizedBox(width: 8),
                              if (row.service.approvalStatus == ServiceApprovalStatus.pending) ...[
                                FilledButton(
                                  onPressed: () => onMenu(row, 'approve'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: FigmaColors.green,
                                    foregroundColor: FigmaColors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Approve', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => onMenu(row, 'reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FigmaColors.red600,
                                    side: const BorderSide(color: FigmaColors.red600),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('Reject', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ] else if (row.service.approvalStatus == ServiceApprovalStatus.approved) ...[
                                OutlinedButton.icon(
                                  onPressed: () => onHide(row),
                                  icon: Icon(
                                    row.service.isActive
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    row.service.isActive ? 'Hide' : 'Show',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        row.service.isActive ? FigmaColors.gray700 : FigmaColors.green,
                                    side: BorderSide(
                                      color: row.service.isActive ? FigmaColors.gray300 : FigmaColors.green,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: FigmaColors.gray600),
                                onSelected: (action) => onMenu(row, action),
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'provider', child: Text('View provider profile')),
                                  if (row.service.approvalStatus == ServiceApprovalStatus.pending) ...[
                                    const PopupMenuItem(value: 'approve', child: Text('Approve listing')),
                                    const PopupMenuItem(value: 'reject', child: Text('Reject listing')),
                                  ],
                                  if (row.service.approvalStatus == ServiceApprovalStatus.approved)
                                    PopupMenuItem(
                                      value: row.service.isActive ? 'hide' : 'show',
                                      child: Text(row.service.isActive ? 'Hide from marketplace' : 'Show on marketplace'),
                                    ),
                                  const PopupMenuItem(value: 'export', child: Text('Export row')),
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
            child: _ServicesPagination(
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

}

class _ServiceNameCell extends StatelessWidget {
  const _ServiceNameCell({required this.row});

  final AdminServiceTableRow row;

  @override
  Widget build(BuildContext context) {
    final icon = serviceCategoryIcon(row.service.category, row.service.serviceTitle);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: FigmaColors.tintGreen,
            borderRadius: BorderRadius.circular(8),
          ),
          child: row.service.serviceImages.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    row.service.serviceImages.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(icon, size: 20, color: FigmaColors.green),
                  ),
                )
              : Icon(icon, size: 20, color: FigmaColors.green),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            row.service.serviceTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ProviderCell extends StatelessWidget {
  const _ProviderCell({required this.row});

  final AdminServiceTableRow row;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.providerLabel,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        if (row.providerArea.isNotEmpty)
          Text(
            row.providerArea,
            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _ServicesPagination extends StatelessWidget {
  const _ServicesPagination({
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
          'Showing $start to $end of $total service${total == 1 ? '' : 's'}',
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

class AdminServiceInsightsPanel extends StatelessWidget {
  const AdminServiceInsightsPanel({
    super.key,
    required this.live,
    required this.pendingReview,
    required this.paused,
    this.rejected = 0,
    required this.topCategory,
    required this.topCategoryCount,
    required this.total,
  });

  final int live;
  final int pendingReview;
  final int paused;
  final int rejected;
  final String topCategory;
  final int topCategoryCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final topPct = total > 0 ? ((topCategoryCount / total) * 100).round() : 0;

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
                Text('Service Insights', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Status Overview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _ServiceStatusDonut(
              live: live,
              pendingReview: pendingReview,
              paused: paused,
              rejected: rejected,
            ),
            const SizedBox(height: 20),
            Text('Top Category', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (topCategory.isEmpty)
              Text('No categories yet', style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: FigmaColors.tintGreen,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FigmaColors.green.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '$topCategory  $topCategoryCount ($topPct%)',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceStatusDonut extends StatelessWidget {
  const _ServiceStatusDonut({
    required this.live,
    required this.pendingReview,
    required this.paused,
    required this.rejected,
  });

  final int live;
  final int pendingReview;
  final int paused;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    final chartTotal = live + pendingReview + paused + rejected;
    if (chartTotal == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('No services yet', style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 12)),
      );
    }

    final sections = <PieChartSectionData>[
      if (live > 0)
        PieChartSectionData(value: live.toDouble(), color: FigmaColors.green, radius: 40, showTitle: false),
      if (pendingReview > 0)
        PieChartSectionData(
          value: pendingReview.toDouble(),
          color: FigmaColors.orange600,
          radius: 40,
          showTitle: false,
        ),
      if (paused > 0)
        PieChartSectionData(value: paused.toDouble(), color: FigmaColors.navy, radius: 40, showTitle: false),
      if (rejected > 0)
        PieChartSectionData(value: rejected.toDouble(), color: FigmaColors.red600, radius: 40, showTitle: false),
    ];
    String pct(int n) => '${((n / chartTotal) * 100).toStringAsFixed(0)}%';

    return Column(
      children: [
        SizedBox(
          height: 140,
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
                  Text('$chartTotal', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Total', style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ServiceDonutLegend(color: FigmaColors.green, label: 'Live', count: live, percent: pct(live)),
        if (pendingReview > 0)
          _ServiceDonutLegend(
            color: FigmaColors.orange600,
            label: 'Pending review',
            count: pendingReview,
            percent: pct(pendingReview),
          ),
        if (paused > 0)
          _ServiceDonutLegend(
            color: FigmaColors.navy,
            label: 'Approved, hidden',
            count: paused,
            percent: pct(paused),
          ),
        if (rejected > 0)
          _ServiceDonutLegend(
            color: FigmaColors.red600,
            label: 'Rejected',
            count: rejected,
            percent: pct(rejected),
          ),
      ],
    );
  }
}

class _ServiceDonutLegend extends StatelessWidget {
  const _ServiceDonutLegend({
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
          Flexible(
            child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600), overflow: TextOverflow.ellipsis),
          ),
          Text('$count ($percent)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

bool serviceMatchesStatusFilter(ServiceListing s, String filter) {
  return switch (filter) {
    'Pending review' => s.approvalStatus == ServiceApprovalStatus.pending,
    'Approved (live)' => s.isMarketplaceVisible,
    'Rejected' => s.approvalStatus == ServiceApprovalStatus.rejected,
    'Draft' => s.approvalStatus == ServiceApprovalStatus.draft,
    'Hidden (paused)' =>
      s.approvalStatus == ServiceApprovalStatus.approved && !s.isActive,
    _ => true,
  };
}

String computeTopCategory(List<ServiceListing> services) {
  if (services.isEmpty) return '';
  final counts = <String, int>{};
  for (final s in services) {
    final cat = s.category.trim().isEmpty ? 'Uncategorized' : s.category.trim();
    counts[cat] = (counts[cat] ?? 0) + 1;
  }
  var best = '';
  var bestCount = 0;
  counts.forEach((cat, n) {
    if (n > bestCount) {
      best = cat;
      bestCount = n;
    }
  });
  return best;
}

int countForCategory(List<ServiceListing> services, String category) {
  if (category.isEmpty) return 0;
  return services.where((s) {
    final cat = s.category.trim().isEmpty ? 'Uncategorized' : s.category.trim();
    return cat == category;
  }).length;
}
