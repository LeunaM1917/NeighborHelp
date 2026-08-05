import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_bookings_widgets.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminBookingsPage extends StatefulWidget {
  const AdminBookingsPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String _statusFilter = 'All Statuses';
  String _dateFilter = 'All Dates';
  int _page = 1;
  int _pageSize = 10;
  String? _selectedId;

  static const _statusOptions = [
    'Pending',
    'Accepted',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminBookingTableRow> _filterRows(List<AdminBookingTableRow> rows) {
    var list = List<AdminBookingTableRow>.from(rows);
    list.sort((a, b) => b.booking.updatedAt.compareTo(a.booking.updatedAt));

    if (_statusFilter != 'All Statuses') {
      list = list.where((r) => bookingMatchesStatusFilter(r.booking, _statusFilter)).toList();
    }

    if (_dateFilter != 'All Dates') {
      list = list.where((r) => bookingMatchesDateFilter(r.booking, _dateFilter)).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((r) {
        return r.booking.bookingId.toLowerCase().contains(q) ||
            r.customerLabel.toLowerCase().contains(q) ||
            r.providerLabel.toLowerCase().contains(q) ||
            r.booking.status.toLowerCase().contains(q) ||
            r.booking.customerId.toLowerCase().contains(q) ||
            r.booking.providerId.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  void _copyId(BuildContext context, String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking ID copied to clipboard')),
    );
  }

  void _showBookingDetail(BuildContext context, FirestoreService firestore, AdminBookingTableRow row) {
    showAdminBookingDetail(
      context,
      row: row,
      onAction: (action) => _onMenu(context, firestore, row, action),
    );
  }

  Future<void> _showStatusDialog(
    BuildContext context,
    FirestoreService firestore,
    Booking booking,
  ) async {
    var selected = booking.status;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Update status', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: DropdownButtonFormField<String>(
            value: _statusOptions.contains(selected) ? selected : _statusOptions.first,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final s in _statusOptions)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              if (v != null) setLocal(() => selected = v);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: FigmaColors.green),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await firestore.adminSetBookingStatus(booking.bookingId, selected);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking status updated to $selected')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status. Check admin permissions.')),
        );
      }
    }
  }

  void _onMenu(
    BuildContext context,
    FirestoreService firestore,
    AdminBookingTableRow row,
    String action,
  ) {
    switch (action) {
      case 'status':
        _showStatusDialog(context, firestore, row.booking);
      case 'customer':
        widget.onNavigateToTab?.call(1);
      case 'provider':
        widget.onNavigateToTab?.call(2);
      case 'copy':
        _copyId(context, row.booking.bookingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Monitor Bookings',
        subtitle: 'View and update booking status across customers and providers.',
        child: const AdminErrorBox(message: 'Firebase admin required.'),
      );
    }

    final firestore = FirestoreService();

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder<List<Booking>>(
        stream: firestore.allBookingsStream(),
        builder: (context, bookingSnap) {
          if (bookingSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoadingBox(message: 'Loading bookings…');
          }

          return StreamBuilder<List<AppUser>>(
            stream: firestore.allUsersStream(),
            builder: (context, userSnap) {
              final bookings = bookingSnap.data ?? [];
              final usersById = <String, AppUser>{
                for (final u in userSnap.data ?? []) u.userId: u,
              };

              final allRows = [
                for (final b in bookings)
                  AdminBookingTableRow(
                    booking: b,
                    customer: usersById[b.customerId],
                    provider: usersById[b.providerId],
                  ),
              ];
              final rows = _filterRows(allRows);

              var completed = 0;
              var inProgress = 0;
              var cancelled = 0;
              for (final b in bookings) {
                switch (bookingStatusBucket(b.status)) {
                  case 0:
                    completed++;
                  case 1:
                    inProgress++;
                  case 2:
                    cancelled++;
                }
              }

              final total = bookings.length;
              final completedPct = total > 0 ? ((completed / total) * 100).round() : 0;
              final inProgressPct = total > 0 ? ((inProgress / total) * 100).round() : 0;
              final cancelledPct = total > 0 ? ((cancelled / total) * 100).round() : 0;

              final totalPages = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
              final page = _page.clamp(1, totalPages);

              final recentActivity = [...bookings]
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminDashboardHeader(
                    title: 'Monitor Bookings',
                    subtitle: 'View and update booking status across customers and providers.',
                  ),
                  const SizedBox(height: 24),
                  AdminMetricGrid(
                    children: [
                      AdminMetricCard(
                        label: 'Total Bookings',
                        value: '$total',
                        hint: '↗ 0% vs last 30 days',
                        icon: Icons.work_outline,
                        iconBg: FigmaColors.tintGreen,
                        iconColor: FigmaColors.green,
                      ),
                      AdminMetricCard(
                        label: 'Completed',
                        value: '$completed',
                        hint: 'Successfully finished',
                        icon: Icons.check_circle_outline,
                        iconBg: FigmaColors.tintGreen2,
                        iconColor: FigmaColors.green,
                        trendLabel: '$completedPct% of total',
                      ),
                      AdminMetricCard(
                        label: 'In Progress',
                        value: '$inProgress',
                        hint: 'Active or accepted',
                        icon: Icons.autorenew,
                        iconBg: FigmaColors.orange50,
                        iconColor: FigmaColors.orange600,
                        trendLabel: '$inProgressPct% of total',
                      ),
                      AdminMetricCard(
                        label: 'Cancelled / Disputed',
                        value: '$cancelled',
                        hint: 'No longer active',
                        icon: Icons.flag_outlined,
                        iconBg: FigmaColors.red50,
                        iconColor: FigmaColors.red600,
                        trendLabel: '$cancelledPct% of total',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AdminSplitSection(
                    breakpoint: 720,
                    main: AdminBookingsTablePanel(
                      rows: rows,
                      searchController: _searchController,
                      statusFilter: _statusFilter,
                      dateFilter: _dateFilter,
                      onStatusFilterChanged: (v) => setState(() {
                        _statusFilter = v;
                        _page = 1;
                      }),
                      onDateFilterChanged: (v) => setState(() {
                        _dateFilter = v;
                        _page = 1;
                      }),
                      onSearchChanged: (v) => setState(() {
                        _search = v;
                        _page = 1;
                      }),
                      selectedId: _selectedId,
                      onSelect: (r, selected) => setState(
                        () => _selectedId = selected ? r.booking.bookingId : null,
                      ),
                      onExport: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export bookings — coming soon.')),
                        );
                      },
                      onView: (r) => _showBookingDetail(context, firestore, r),
                      onCopyId: (id) => _copyId(context, id),
                      page: page,
                      pageSize: _pageSize,
                      onPageChanged: (p) => setState(() => _page = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _page = 1;
                      }),
                      onMenu: (r, action) => _onMenu(context, firestore, r, action),
                    ),
                    side: Column(
                      children: [
                        AdminBookingInsightsPanel(
                          completed: completed,
                          inProgress: inProgress,
                          cancelled: cancelled,
                        ),
                        const SizedBox(height: 16),
                        AdminBookingLatestActivity(
                          bookings: recentActivity.take(3).toList(),
                          onViewAll: () => widget.onNavigateToTab?.call(9),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
