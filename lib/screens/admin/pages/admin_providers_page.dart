import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/account_status.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../widgets/stream_snapshot.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_providers_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminProvidersPage extends StatefulWidget {
  const AdminProvidersPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminProvidersPage> createState() => _AdminProvidersPageState();
}

class _AdminProvidersPageState extends State<AdminProvidersPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String _verificationFilter = 'All Verification';
  int _page = 1;
  int _pageSize = 10;
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminProviderTableRow> _filterRows(List<AdminProviderTableRow> rows) {
    var list = List<AdminProviderTableRow>.from(rows);
    list.sort((a, b) => b.profile.createdAt.compareTo(a.profile.createdAt));

    if (_verificationFilter != 'All Verification') {
      list = list
          .where((r) => providerMatchesVerificationFilter(r.profile, _verificationFilter))
          .toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((r) {
            final name = r.user?.fullName.toLowerCase() ?? '';
            final email = r.user?.email.toLowerCase() ?? '';
            final area = r.profile.serviceArea.toLowerCase();
            final label = r.topServiceLabel.toLowerCase();
            return name.contains(q) ||
                email.contains(q) ||
                area.contains(q) ||
                label.contains(q);
          })
          .toList();
    }

    return list;
  }

  Future<void> _onMenu(
    AdminProviderTableRow row,
    String action,
    FirestoreService firestore,
  ) async {
    switch (action) {
      case 'verify':
        widget.onNavigateToTab?.call(4);
      case 'services':
        widget.onNavigateToTab?.call(6);
      case 'notify':
        widget.onNavigateToTab?.call(10);
      case 'suspend':
      case 'deactivate':
      case 'active':
        final userId = row.user?.userId ?? row.profile.providerId;
        if (userId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No linked user profile for this provider.')),
            );
          }
          return;
        }
        final status = switch (action) {
          'active' => AccountStatus.active,
          'deactivate' => AccountStatus.deactivated,
          _ => AccountStatus.suspended,
        };
        await firestore.adminSetUserAccountStatus(userId: userId, status: status);
        if (!mounted) return;
        final label = (row.user?.fullName ?? '').trim().isNotEmpty
            ? row.user!.fullName
            : 'Provider';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              switch (status) {
                AccountStatus.active => '$label is active again.',
                AccountStatus.deactivated => '$label deactivated.',
                _ => '$label suspended.',
              },
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Manage Providers',
        subtitle: 'Monitor provider profiles, ratings, services, and verification status.',
        child: const AdminErrorBox(message: 'Firebase admin required.'),
      );
    }

    final firestore = FirestoreService();

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder<List<ServiceProviderProfile>>(
        stream: firestore.serviceProvidersStream(),
        builder: (context, providerSnap) {
          if (isStreamWaiting(providerSnap)) {
            return const AdminLoadingBox(message: 'Loading providers…');
          }
          if (providerSnap.hasError) {
            return AdminLoadingBox(message: 'Could not load providers: ${providerSnap.error}');
          }

          return StreamBuilder<List<AppUser>>(
            stream: firestore.allUsersStream(),
            builder: (context, userSnap) {
              return StreamBuilder<List<ServiceListing>>(
                stream: firestore.allServicesStream(),
                builder: (context, serviceSnap) {
                  final providers = providerSnap.data ?? [];
                  final usersById = <String, AppUser>{
                    for (final u in userSnap.data ?? []) u.userId: u,
                  };
                  final services = serviceSnap.data ?? [];

                  final serviceCounts = <String, int>{};
                  final topServiceLabels = <String, String>{};
                  for (final s in services) {
                    final pid = s.providerId;
                    if (pid.isEmpty) continue;
                    serviceCounts[pid] = (serviceCounts[pid] ?? 0) + 1;
                    topServiceLabels.putIfAbsent(
                      pid,
                      () => s.category.isNotEmpty ? s.category : s.serviceTitle,
                    );
                  }

                  final allRows = buildProviderRows(
                    providers: providers,
                    usersById: usersById,
                    serviceCounts: serviceCounts,
                    topServiceLabels: topServiceLabels,
                  );
                  final rows = _filterRows(allRows);

                  var approved = 0;
                  var pending = 0;
                  var rejected = 0;
                  var completedBookings = 0;
                  var ratingSum = 0.0;
                  var ratedCount = 0;

                  for (final p in providers) {
                    completedBookings += p.completedBookings;
                    final bucket = providerVerificationBucket(p.verificationStatus, p.isVerified);
                    switch (bucket) {
                      case 0:
                        approved++;
                      case 1:
                        pending++;
                      case 2:
                        rejected++;
                    }
                    if (p.averageRating > 0) {
                      ratingSum += p.averageRating;
                      ratedCount++;
                    }
                  }

                  final total = providers.length;
                  final approvedPct = total > 0 ? ((approved / total) * 100).round() : 0;
                  final pendingPct = total > 0 ? ((pending / total) * 100).round() : 0;
                  final avgRating = ratedCount > 0 ? ratingSum / ratedCount : 0.0;

                  final totalPages = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
                  final page = _page.clamp(1, totalPages);

                  AdminProviderTableRow? selected;
                  if (_selectedId != null) {
                    for (final r in rows) {
                      if (r.profile.providerId == _selectedId) {
                        selected = r;
                        break;
                      }
                    }
                  }

                  AdminProviderTableRow? topSnapshot = selected;
                  if (topSnapshot == null && allRows.isNotEmpty) {
                    allRows.sort((a, b) {
                      final cmp = b.profile.completedBookings.compareTo(a.profile.completedBookings);
                      if (cmp != 0) return cmp;
                      return b.profile.averageRating.compareTo(a.profile.averageRating);
                    });
                    topSnapshot = allRows.first;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AdminDashboardHeader(
                        title: 'Manage Providers',
                        subtitle:
                            'Monitor provider profiles, ratings, services, and verification status.',
                      ),
                      const SizedBox(height: 24),
                      AdminMetricGrid(
                        children: [
                          AdminMetricCard(
                            label: 'Total Providers',
                            value: '$total',
                            hint: '— 0% vs last 30 days',
                            icon: Icons.groups_outlined,
                            iconBg: FigmaColors.tintGreen,
                            iconColor: FigmaColors.green,
                          ),
                          AdminMetricCard(
                            label: 'Approved Providers',
                            value: '$approved',
                            hint: 'Verified and active',
                            icon: Icons.verified_user_outlined,
                            iconBg: FigmaColors.tintGreen2,
                            iconColor: FigmaColors.green,
                            trendLabel: '$approvedPct% of total',
                          ),
                          AdminMetricCard(
                            label: 'Pending Verification',
                            value: '$pending',
                            hint: 'Awaiting document review',
                            icon: Icons.schedule_outlined,
                            iconBg: FigmaColors.orange50,
                            iconColor: FigmaColors.orange600,
                            trendLabel: '$pendingPct% of total',
                          ),
                          AdminMetricCard(
                            label: 'Completed Bookings',
                            value: '$completedBookings',
                            hint: '— 0% vs last 30 days',
                            icon: Icons.event_note_outlined,
                            iconBg: FigmaColors.tintBlue,
                            iconColor: FigmaColors.navy,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AdminSplitSection(
                        breakpoint: 720,
                        main: AdminProvidersTablePanel(
                          rows: rows,
                          searchController: _searchController,
                          verificationFilter: _verificationFilter,
                          onVerificationFilterChanged: (v) => setState(() {
                            _verificationFilter = v;
                            _page = 1;
                          }),
                          onSearchChanged: (v) => setState(() {
                            _search = v;
                            _page = 1;
                          }),
                          selectedId: _selectedId,
                          onSelect: (r, selected) => setState(
                            () => _selectedId = selected ? r.profile.providerId : null,
                          ),
                          onExport: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Export providers — coming soon.')),
                            );
                          },
                          page: page,
                          pageSize: _pageSize,
                          onPageChanged: (p) => setState(() => _page = p),
                          onPageSizeChanged: (s) => setState(() {
                            _pageSize = s;
                            _page = 1;
                          }),
                          onMenu: (row, action) => _onMenu(row, action, firestore),
                          onOpenDetail: (row) => showAdminProviderDetail(
                            context,
                            row: row,
                            onAction: (action) => _onMenu(row, action, firestore),
                          ),
                        ),
                        side: Column(
                          children: [
                            AdminProviderInsightsPanel(
                              approved: approved,
                              pending: pending,
                              rejected: rejected,
                              averageRating: avgRating,
                              ratedCount: ratedCount,
                            ),
                            const SizedBox(height: 16),
                            AdminTopProviderSnapshot(row: topSnapshot),
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
