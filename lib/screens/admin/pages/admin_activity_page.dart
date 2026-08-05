import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_activity_widgets.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminActivityPage extends StatefulWidget {
  const AdminActivityPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminActivityPage> createState() => _AdminActivityPageState();
}

class _AdminActivityPageState extends State<AdminActivityPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String _typeFilter = 'All Activity Types';
  String _statusFilter = 'All Statuses';
  String _dateFilter = 'All Dates';
  int _page = 1;
  int _pageSize = 10;
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminActivityEntry> _filterEntries(List<AdminActivityEntry> all) {
    var list = List<AdminActivityEntry>.from(all);

    if (_typeFilter != 'All Activity Types') {
      list = list.where((e) => activityMatchesTypeFilter(e, _typeFilter)).toList();
    }
    if (_statusFilter != 'All Statuses') {
      list = list.where((e) => activityMatchesStatusFilter(e, _statusFilter)).toList();
    }
    if (_dateFilter != 'All Dates') {
      list = list.where((e) => activityMatchesDateFilter(e, _dateFilter)).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where(
            (e) =>
                e.eventTitle.toLowerCase().contains(q) ||
                e.actorId.toLowerCase().contains(q) ||
                e.status.toLowerCase().contains(q) ||
                (e.referenceId?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    return list;
  }

  void _showDetail(BuildContext context, AdminActivityEntry entry) {
    showAdminActivityDetail(
      context,
      entry: entry,
      onAction: (action) {
        if (action == 'copy') {
          Clipboard.setData(ClipboardData(text: entry.actorId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Actor ID copied')),
          );
        }
      },
    );
  }

  AdminActivityEntry? _highlightEntry(List<AdminActivityEntry> all) {
    for (final e in all) {
      if (e.eventTitle.toLowerCase().contains('booking completed')) return e;
    }
    return all.isNotEmpty ? all.first : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Activity Logs',
        subtitle: 'Derived from recent bookings, services, and provider updates.',
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
            return const AdminLoadingBox(message: 'Loading activity…');
          }

          return StreamBuilder<List<ServiceListing>>(
            stream: firestore.allServicesStream(),
            builder: (context, serviceSnap) {
              return StreamBuilder<List<ServiceProviderProfile>>(
                stream: firestore.serviceProvidersStream(),
                builder: (context, providerSnap) {
                  final all = buildActivityLog(
                    bookings: bookingSnap.data ?? [],
                    services: serviceSnap.data ?? [],
                    providers: providerSnap.data ?? [],
                  );
                  final entries = _filterEntries(all);

                  final total = all.length;
                  var bookingEvents = 0;
                  var providerUpdates = 0;
                  var serviceChanges = 0;
                  for (final e in all) {
                    switch (e.type) {
                      case ActivityLogType.booking:
                        bookingEvents++;
                      case ActivityLogType.provider:
                        providerUpdates++;
                      case ActivityLogType.service:
                        serviceChanges++;
                      case ActivityLogType.other:
                        break;
                    }
                  }

                  final bookingPct = total > 0 ? ((bookingEvents / total) * 100).round() : 0;
                  final providerPct = total > 0 ? ((providerUpdates / total) * 100).round() : 0;
                  final servicePct = total > 0 ? ((serviceChanges / total) * 100).round() : 0;

                  final statusCounts = <String, int>{};
                  for (final e in all) {
                    statusCounts[e.status] = (statusCounts[e.status] ?? 0) + 1;
                  }

                  final totalPages = entries.isEmpty ? 1 : (entries.length / _pageSize).ceil();
                  final page = _page.clamp(1, totalPages);
                  final highlight = _highlightEntry(all);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AdminDashboardHeader(
                        title: 'Activity Logs',
                        subtitle: 'Derived from recent bookings, services, and provider updates.',
                      ),
                      const SizedBox(height: 24),
                      AdminMetricGrid(
                        children: [
                          AdminMetricCard(
                            label: 'Total Activities',
                            value: '$total',
                            hint: total > 0 ? '↑ vs last 30 days' : '— 0% vs last 30 days',
                            icon: Icons.history,
                            iconBg: FigmaColors.tintGreen,
                            iconColor: FigmaColors.green,
                          ),
                          AdminMetricCard(
                            label: 'Booking Events',
                            value: '$bookingEvents',
                            hint: 'Customer & provider bookings',
                            icon: Icons.event_note_outlined,
                            iconBg: FigmaColors.tintBlue,
                            iconColor: FigmaColors.navy,
                            trendLabel: '$bookingPct% of total',
                          ),
                          AdminMetricCard(
                            label: 'Provider Updates',
                            value: '$providerUpdates',
                            hint: 'Verification & profile changes',
                            icon: Icons.groups_outlined,
                            iconBg: FigmaColors.tintGreen2,
                            iconColor: FigmaColors.green,
                            trendLabel: '$providerPct% of total',
                          ),
                          AdminMetricCard(
                            label: 'Service Changes',
                            value: '$serviceChanges',
                            hint: 'Listings added or hidden',
                            icon: Icons.settings_outlined,
                            iconBg: FigmaColors.orange50,
                            iconColor: FigmaColors.orange600,
                            trendLabel: '$servicePct% of total',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AdminSplitSection(
                        breakpoint: 720,
                        main: AdminActivityTablePanel(
                          entries: entries,
                          searchController: _searchController,
                          typeFilter: _typeFilter,
                          statusFilter: _statusFilter,
                          dateFilter: _dateFilter,
                          onTypeFilterChanged: (v) => setState(() {
                            _typeFilter = v;
                            _page = 1;
                          }),
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
                          onSelect: (e, selected) => setState(() => _selectedId = selected ? e.id : null),
                          onExport: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Export activity logs — coming soon.')),
                            );
                          },
                          onView: (e) => _showDetail(context, e),
                          page: page,
                          pageSize: _pageSize,
                          onPageChanged: (p) => setState(() => _page = p),
                          onPageSizeChanged: (s) => setState(() {
                            _pageSize = s;
                            _page = 1;
                          }),
                          onMenu: (e, action) {
                            switch (action) {
                              case 'view':
                                _showDetail(context, e);
                              case 'copy':
                                Clipboard.setData(ClipboardData(text: e.actorId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Actor ID copied')),
                                );
                            }
                          },
                        ),
                        side: Column(
                          children: [
                            AdminActivityInsightsPanel(statusCounts: statusCounts),
                            const SizedBox(height: 16),
                            AdminActivityHighlightCard(entry: highlight),
                            const SizedBox(height: 16),
                            AdminActivityQuickActions(
                              onViewBookings: () => widget.onNavigateToTab?.call(7),
                              onViewProviders: () => widget.onNavigateToTab?.call(2),
                              onExportLogs: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Export logs — coming soon.')),
                                );
                              },
                              onReviewServices: () => widget.onNavigateToTab?.call(6),
                            ),
                          ],
                        ),
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
