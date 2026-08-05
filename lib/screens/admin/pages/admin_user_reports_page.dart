import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/account_status.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/booking_user_report.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/stream_snapshot.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_detail_dialog.dart';
import '../widgets/admin_widgets.dart';

class AdminUserReportsPage extends StatefulWidget {
  const AdminUserReportsPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminUserReportsPage> createState() => _AdminUserReportsPageState();
}

class _AdminUserReportsPageState extends State<AdminUserReportsPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String _statusFilter = 'All';
  int _page = 1;
  int _pageSize = 10;
  String? _selectedReportId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookingUserReport> _applyFilters(List<BookingUserReport> reports) {
    var list = [...reports];
    if (_statusFilter != 'All') {
      final status = _statusFilter.toLowerCase();
      list = list.where((r) => r.status.toLowerCase() == status).toList();
    }

    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        return r.bookingId.toLowerCase().contains(q) ||
            r.reason.toLowerCase().contains(q) ||
            r.reporterId.toLowerCase().contains(q) ||
            r.reportedUserId.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  String _displayUser(AppUser? u, String fallback) {
    final name = (u?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    return fallback;
  }

  Future<void> _showReportDetail(
    BuildContext context, {
    required BookingUserReport report,
    required Booking? booking,
    required AppUser? reporter,
    required AppUser? reported,
  }) async {
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');
    final notesController = TextEditingController();

    String? chosenAction;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(
                'Report detail',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
                        children: [
                          const TextSpan(text: 'Booking ID: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: report.bookingId),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800),
                        children: [
                          const TextSpan(text: 'Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: report.status),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    adminDetailLine('Submitted', '${dateFmt.format(report.createdAt.toDate())} ${timeFmt.format(report.createdAt.toDate())}'),
                    adminDetailLine(
                      'Reporter',
                      '${reporter?.fullName.isNotEmpty == true ? reporter!.fullName : report.reporterId} (${report.reporterRole})',
                    ),
                    adminDetailLine(
                      'Reported user',
                      '${reported?.fullName.isNotEmpty == true ? reported!.fullName : report.reportedUserId} (${report.reportedRole})',
                    ),
                    const SizedBox(height: 8),
                    adminDetailLine('Reason', report.reason),
                    if (report.details.isNotEmpty) adminDetailLine('Details', report.details),
                    if (booking != null) adminDetailLine('Booking status', booking.status),
                    if (report.adminNotes.isNotEmpty) adminDetailLine('Admin notes', report.adminNotes),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Admin notes (optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setLocal(() => chosenAction = chosenAction);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FigmaColors.red600,
                    side: const BorderSide(color: FigmaColors.red600),
                  ),
                  onPressed: () async {
                    chosenAction = 'dismiss';
                    Navigator.pop(ctx);
                  },
                  child: const Text('Dismiss'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: FigmaColors.green),
                  onPressed: () async {
                    chosenAction = 'resolve';
                    Navigator.pop(ctx);
                  },
                  child: const Text('Resolve'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!context.mounted) return;

    // If dialog closed without action, do nothing.
    if (chosenAction == null) return;

    try {
      await FirestoreService().adminSetBookingUserReportStatus(
        reportId: report.reportId,
        status: chosenAction == 'resolve' ? BookingUserReport.statusResolved : BookingUserReport.statusDismissed,
        adminNotes: notesController.text,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chosenAction == 'resolve' ? 'Report resolved.' : 'Report dismissed.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is StateError ? e.message : 'Could not update report.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'User Reports',
        subtitle: 'Moderation queue for customer/provider reports per booking.',
        child: const AdminErrorBox(message: 'Firebase admin required.'),
      );
    }

    final firestore = FirestoreService();
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder<List<BookingUserReport>>(
        stream: firestore.allBookingUserReportsStream(),
        builder: (context, reportSnap) {
          if (reportSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoadingBox(message: 'Loading user reports…');
          }

          final reportsRaw = reportSnap.data ?? [];
          final reports = _applyFilters(reportsRaw);
          final total = reports.length;
          final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
          final page = _page.clamp(1, totalPages);
          if (_page != page && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _page = page));
          }

          final start = (page - 1) * _pageSize;
          final end = (start + _pageSize).clamp(0, total);
          final pageReports = total == 0 ? <BookingUserReport>[] : reports.sublist(start, end);

          return StreamBuilder<List<Booking>>(
            stream: firestore.allBookingsStream(),
            builder: (context, bookingSnap) {
              if (bookingSnap.connectionState == ConnectionState.waiting) {
                return const AdminLoadingBox(message: 'Loading bookings…');
              }

              return StreamBuilder<List<AppUser>>(
                stream: firestore.allUsersStream(),
                builder: (context, userSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const AdminLoadingBox(message: 'Loading users…');
                  }

                  final bookings = bookingSnap.data ?? [];
                  final users = userSnap.data ?? [];
                  final bookingsById = {for (final b in bookings) b.bookingId: b};
                  final usersById = {for (final u in users) u.userId: u};

                  // Metrics
                  var open = 0, resolved = 0, dismissed = 0;
                  for (final r in reportsRaw) {
                    if (r.status == BookingUserReport.statusResolved) resolved++;
                    else if (r.status == BookingUserReport.statusDismissed) dismissed++;
                    else open++;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AdminDashboardHeader(
                        title: 'User Reports (per booking)',
                        subtitle: 'Customers/providers report the other party. Admin can resolve or dismiss.',
                      ),
                      const SizedBox(height: 24),
                      AdminMetricGrid(
                        children: [
                          AdminMetricCard(
                            label: 'Open reports',
                            value: '$open',
                            icon: Icons.flag_outlined,
                            iconBg: FigmaColors.orange50,
                            iconColor: FigmaColors.orange600,
                            hint: 'Pending moderation',
                          ),
                          AdminMetricCard(
                            label: 'Resolved',
                            value: '$resolved',
                            icon: Icons.check_circle_outline,
                            iconBg: FigmaColors.tintGreen,
                            iconColor: FigmaColors.green,
                            hint: 'Handled by admin',
                          ),
                          AdminMetricCard(
                            label: 'Dismissed',
                            value: '$dismissed',
                            icon: Icons.cancel_outlined,
                            iconBg: FigmaColors.red50,
                            iconColor: FigmaColors.red600,
                            hint: 'No further action',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AdminSplitSection(
                        breakpoint: 720,
                        main: AdminPanelCard(
                          title: '',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                                child: AdminTableFilterToolbar(
                                  search: TextField(
                                    controller: _searchController,
                                    onChanged: (v) => setState(() => _search = v),
                                    decoration: InputDecoration(
                                      hintText: 'Search booking ID / reason / users…',
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
                                      value: _statusFilter,
                                      options: const ['All', 'Open', 'Resolved', 'Dismissed'],
                                      onChanged: (v) => setState(() {
                                        _statusFilter = v;
                                        _page = 1;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: FigmaColors.gray200),
                              if (pageReports.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Center(
                                    child: Text(
                                      'No reports match your filters.',
                                      style: TextStyle(color: FigmaColors.gray500),
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
                                    dataRowMaxHeight: 84,
                                    headingTextStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: FigmaColors.gray600,
                                    ),
                                    dataTextStyle: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray800),
                                    columns: const [
                                      DataColumn(label: Text('Booking ID')),
                                      DataColumn(label: Text('Reported user')),
                                      DataColumn(label: Text('Reporter')),
                                      DataColumn(label: Text('Reason')),
                                      DataColumn(label: Text('Submitted')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: [
                                      for (final r in pageReports)
                                        DataRow(
                                          selected: _selectedReportId == r.reportId,
                                          onSelectChanged: (v) => setState(() => _selectedReportId = v == true ? r.reportId : null),
                                          cells: [
                                            DataCell(
                                              AdminTableDetailTap(
                                                onOpen: () => _showReportDetail(
                                                  context,
                                                  report: r,
                                                  booking: bookingsById[r.bookingId],
                                                  reporter: usersById[r.reporterId],
                                                  reported: usersById[r.reportedUserId],
                                                ),
                                                child: Text(r.bookingId, style: GoogleFonts.inter(color: FigmaColors.navy)),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _displayUser(usersById[r.reportedUserId], r.reportedUserId),
                                                softWrap: false,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _displayUser(usersById[r.reporterId], r.reporterId),
                                                softWrap: false,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                r.reason,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                '${dateFmt.format(r.createdAt.toDate())} ${timeFmt.format(r.createdAt.toDate())}',
                                                softWrap: false,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                r.status,
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w700,
                                                  color: r.status == BookingUserReport.statusResolved
                                                      ? FigmaColors.green
                                                      : r.status == BookingUserReport.statusDismissed
                                                          ? FigmaColors.red600
                                                          : FigmaColors.orange600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  OutlinedButton(
                                                    onPressed: () => _showReportDetail(
                                                      context,
                                                      report: r,
                                                      booking: bookingsById[r.bookingId],
                                                      reporter: usersById[r.reporterId],
                                                      reported: usersById[r.reportedUserId],
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: FigmaColors.gray800,
                                                      side: const BorderSide(color: FigmaColors.gray300),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    child: Text(
                                                      'View',
                                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    tooltip: 'Copy report id',
                                                    icon: const Icon(Icons.copy_outlined, size: 18, color: FigmaColors.gray500),
                                                    onPressed: () {
                                                      Clipboard.setData(ClipboardData(text: r.reportId));
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Report ID copied')),
                                                      );
                                                    },
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
                                child: _UserReportsPagination(
                                  total: total,
                                  page: page,
                                  pageSize: _pageSize,
                                  onPageChanged: (p) => setState(() => _page = p),
                                  onPageSizeChanged: (s) => setState(() {
                                    _pageSize = s;
                                    _page = 1;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        side: const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _UserReportsPagination extends StatelessWidget {
  const _UserReportsPagination({
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
          'Showing $start to $end of $total',
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
                color: FigmaColors.white,
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

        return AdminTablePaginationBar(
          info: info,
          controls: controls,
        );
      },
    );
  }
}

