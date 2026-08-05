import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import 'admin_customers_widgets.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

class AdminProviderVerificationChip extends StatelessWidget {
  const AdminProviderVerificationChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;
    String label;
    if (lower == 'approved' || lower == 'verified') {
      bg = FigmaColors.tintGreen;
      fg = FigmaColors.green;
      label = 'Approved';
    } else if (lower == 'rejected') {
      bg = FigmaColors.red50;
      fg = FigmaColors.red600;
      label = 'Rejected';
    } else {
      bg = FigmaColors.orange50;
      fg = FigmaColors.orange600;
      label = 'Pending';
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

class AdminProviderTableRow {
  const AdminProviderTableRow({
    required this.profile,
    required this.user,
    required this.serviceCount,
    required this.topServiceLabel,
  });

  final ServiceProviderProfile profile;
  final AppUser? user;
  final int serviceCount;
  final String topServiceLabel;
}

class AdminProvidersTablePanel extends StatelessWidget {
  const AdminProvidersTablePanel({
    super.key,
    required this.rows,
    required this.searchController,
    required this.verificationFilter,
    required this.onVerificationFilterChanged,
    required this.onSearchChanged,
    required this.selectedId,
    required this.onSelect,
    required this.onExport,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onMenu,
    required this.onOpenDetail,
  });

  final List<AdminProviderTableRow> rows;
  final TextEditingController searchController;
  final String verificationFilter;
  final ValueChanged<String> onVerificationFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final String? selectedId;
  final void Function(AdminProviderTableRow row, bool selected) onSelect;
  final VoidCallback onExport;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final void Function(AdminProviderTableRow row, String action) onMenu;
  final ValueChanged<AdminProviderTableRow> onOpenDetail;

  static const verificationFilters = [
    'All Verification',
    'Approved',
    'Pending',
    'Rejected',
  ];

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, rows.length);
    final pageItems = rows.length <= start
        ? <AdminProviderTableRow>[]
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
                    const Icon(Icons.engineering_outlined, size: 22, color: FigmaColors.gray700),
                    const SizedBox(width: 8),
                    Text(
                      'Providers (${rows.length})',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AdminTableFilterToolbar(
                  search: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search providers…',
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
                      value: verificationFilter,
                      options: verificationFilters,
                      onChanged: onVerificationFilterChanged,
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
                  'No providers match your filters.',
                  style: GoogleFonts.inter(color: FigmaColors.gray500),
                ),
              ),
            )
          else
            AdminHorizontalScrollTable(
              minTableWidth: 1280,
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 44,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 80,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
                dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
                columns: const [
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('Area')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Verification')),
                  DataColumn(label: Text('Services')),
                  DataColumn(label: Text('Completed')),
                  DataColumn(label: Text('Joined')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final row in pageItems)
                    DataRow(
                      selected: selectedId == row.profile.providerId,
                      onSelectChanged: (v) => onSelect(row, v ?? false),
                      cells: [
                        DataCell(
                          AdminTableDetailTap(
                            onOpen: () => onOpenDetail(row),
                            child: _ProviderNameCell(row: row),
                          ),
                        ),
                        DataCell(
                          row.user != null
                              ? AdminCustomerStatusChip(status: row.user!.accountStatus)
                              : Text('—', style: GoogleFonts.inter(color: FigmaColors.gray500)),
                        ),
                        DataCell(Text(row.profile.serviceArea.isEmpty ? '—' : row.profile.serviceArea)),
                        DataCell(_RatingCell(rating: row.profile.averageRating, completed: row.profile.completedBookings)),
                        DataCell(AdminProviderVerificationChip(status: row.profile.verificationStatus)),
                        DataCell(Text('${row.serviceCount}')),
                        DataCell(Text('${row.profile.completedBookings}')),
                        DataCell(Text(dateFmt.format(row.profile.createdAt.toDate()))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AdminTableViewButton(onPressed: () => onOpenDetail(row)),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: FigmaColors.gray600),
                                onSelected: (action) => onMenu(row, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'verify', child: Text('Review verification')),
                              PopupMenuItem(value: 'services', child: Text('View services')),
                              PopupMenuItem(value: 'suspend', child: Text('Suspend account')),
                              PopupMenuItem(value: 'deactivate', child: Text('Deactivate account')),
                              PopupMenuItem(value: 'notify', child: Text('Send notification')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'active', child: Text('Set Active')),
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
            child: _ProvidersPagination(
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

class _ProviderNameCell extends StatelessWidget {
  const _ProviderNameCell({required this.row});

  final AdminProviderTableRow row;

  @override
  Widget build(BuildContext context) {
    final user = row.user;
    final name = (user?.fullName ?? '').trim().isNotEmpty ? user!.fullName : 'Provider';
    final subtitle = row.topServiceLabel;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: FigmaColors.tintGreen,
          backgroundImage: user?.profilePhotoUrl != null ? NetworkImage(user!.profilePhotoUrl!) : null,
          child: user?.profilePhotoUrl == null
              ? Text(
                  adminInitials(name),
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.green),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                  overflow: TextOverflow.ellipsis,
                ),
              if (user != null && user.accountStatus.isBlocked) ...[
                const SizedBox(height: 4),
                AdminCustomerStatusChip(status: user.accountStatus),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RatingCell extends StatelessWidget {
  const _RatingCell({required this.rating, required this.completed});

  final double rating;
  final int completed;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text('—', style: GoogleFonts.inter(color: FigmaColors.gray500));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
        if (completed > 0) ...[
          const SizedBox(width: 4),
          Text('($completed)', style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
        ],
      ],
    );
  }
}

class _ProvidersPagination extends StatelessWidget {
  const _ProvidersPagination({
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
          'Showing $start to $end of $total provider${total == 1 ? '' : 's'}',
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

class AdminProviderInsightsPanel extends StatelessWidget {
  const AdminProviderInsightsPanel({
    super.key,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.averageRating,
    required this.ratedCount,
  });

  final int approved;
  final int pending;
  final int rejected;
  final double averageRating;
  final int ratedCount;

  @override
  Widget build(BuildContext context) {
    final ratingFraction = averageRating > 0 ? (averageRating / 5).clamp(0.0, 1.0) : 0.0;

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
                Text('Provider Insights', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Verification Overview', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            AdminVerificationDonut(
              approved: approved,
              pending: pending,
              rejected: rejected,
            ),
            const SizedBox(height: 8),
            Text('Ratings Distribution', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (ratingFraction > 0)
                      Expanded(
                        flex: (ratingFraction * 100).round().clamp(1, 100),
                        child: const ColoredBox(color: Color(0xFFF59E0B)),
                      ),
                    Expanded(
                      flex: ((1 - ratingFraction) * 100).round().clamp(1, 100),
                      child: const ColoredBox(color: FigmaColors.gray200),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ratedCount > 0
                  ? 'Average rating ${averageRating.toStringAsFixed(1)} / 5.0'
                  : 'No ratings yet',
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminTopProviderSnapshot extends StatelessWidget {
  const AdminTopProviderSnapshot({
    super.key,
    required this.row,
  });

  final AdminProviderTableRow? row;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: '',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, size: 20, color: FigmaColors.gray700),
                const SizedBox(width: 8),
                Text('Top Provider Snapshot', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            if (row == null) ...[
              const SizedBox(height: 24),
              Text(
                'Select a provider to view details.',
                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: FigmaColors.tintGreen,
                    backgroundImage: row!.user?.profilePhotoUrl != null
                        ? NetworkImage(row!.user!.profilePhotoUrl!)
                        : null,
                    child: row!.user?.profilePhotoUrl == null
                        ? Text(
                            adminInitials(
                              (row!.user?.fullName ?? '').trim().isNotEmpty
                                  ? row!.user!.fullName
                                  : 'Provider',
                            ),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.green),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (row!.user?.fullName ?? '').trim().isNotEmpty
                              ? row!.user!.fullName
                              : 'Provider',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        if (row!.topServiceLabel.isNotEmpty)
                          Text(
                            row!.topServiceLabel,
                            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                          ),
                        if (row!.profile.serviceArea.isNotEmpty)
                          Text(
                            row!.profile.serviceArea,
                            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                          ),
                        const SizedBox(height: 8),
                        AdminProviderVerificationChip(status: row!.profile.verificationStatus),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _SnapshotStat(
                    icon: Icons.event_note_outlined,
                    label: '${row!.profile.completedBookings} Completed Booking${row!.profile.completedBookings == 1 ? '' : 's'}',
                  ),
                  const SizedBox(width: 16),
                  _SnapshotStat(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    label: row!.profile.averageRating > 0
                        ? '${row!.profile.averageRating.toStringAsFixed(1)} Rating'
                        : 'No rating',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SnapshotStat extends StatelessWidget {
  const _SnapshotStat({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor ?? FigmaColors.green),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds table row models from Firestore data.
List<AdminProviderTableRow> buildProviderRows({
  required List<ServiceProviderProfile> providers,
  required Map<String, AppUser> usersById,
  required Map<String, int> serviceCounts,
  required Map<String, String> topServiceLabels,
}) {
  return [
    for (final p in providers)
      AdminProviderTableRow(
        profile: p,
        user: usersById[p.userId],
        serviceCount: serviceCounts[p.providerId] ?? serviceCounts[p.userId] ?? 0,
        topServiceLabel: topServiceLabels[p.providerId] ?? topServiceLabels[p.userId] ?? '',
      ),
  ];
}

int providerVerificationBucket(String status, bool isVerified) {
  final lower = status.toLowerCase();
  if (isVerified || lower == 'approved' || lower == 'verified') return 0;
  if (lower == 'rejected') return 2;
  return 1;
}

bool providerMatchesVerificationFilter(ServiceProviderProfile p, String filter) {
  if (filter == 'All Verification') return true;
  final bucket = providerVerificationBucket(p.verificationStatus, p.isVerified);
  return switch (filter) {
    'Approved' => bucket == 0,
    'Pending' => bucket == 1,
    'Rejected' => bucket == 2,
    _ => true,
  };
}
