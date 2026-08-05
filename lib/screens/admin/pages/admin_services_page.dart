import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_services_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminServicesPage extends StatefulWidget {
  const AdminServicesPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminServicesPage> createState() => _AdminServicesPageState();
}

class _AdminServicesPageState extends State<AdminServicesPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String _categoryFilter = 'All Categories';
  String _statusFilter = 'All Statuses';
  int _page = 1;
  int _pageSize = 10;
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminServiceTableRow> _filterRows(List<AdminServiceTableRow> rows) {
    var list = List<AdminServiceTableRow>.from(rows);
    list.sort((a, b) => b.service.updatedAt.compareTo(a.service.updatedAt));

    if (_categoryFilter != 'All Categories') {
      list = list
          .where((r) {
            final cat = r.service.category.trim().isEmpty ? 'Uncategorized' : r.service.category.trim();
            return cat == _categoryFilter;
          })
          .toList();
    }

    if (_statusFilter != 'All Statuses') {
      list = list.where((r) => serviceMatchesStatusFilter(r.service, _statusFilter)).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((r) {
        return r.service.serviceTitle.toLowerCase().contains(q) ||
            r.service.category.toLowerCase().contains(q) ||
            r.providerLabel.toLowerCase().contains(q) ||
            r.providerArea.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  List<String> _categoryOptions(List<ServiceListing> services) {
    final cats = <String>{};
    for (final s in services) {
      final cat = s.category.trim().isEmpty ? 'Uncategorized' : s.category.trim();
      cats.add(cat);
    }
    final list = cats.toList()..sort();
    return ['All Categories', ...list];
  }

  Future<void> _toggleActive(
    BuildContext context,
    FirestoreService firestore,
    ServiceListing service,
    bool active,
  ) async {
    try {
      await firestore.setServiceActive(service.serviceId, active);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(active ? 'Service is now active' : 'Service hidden from marketplace')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update service. Check admin permissions.')),
        );
      }
    }
  }

  Future<void> _approve(
    BuildContext context,
    FirestoreService firestore,
    ServiceListing service,
  ) async {
    try {
      await firestore.adminSetServiceApproval(
        serviceId: service.serviceId,
        status: ServiceApprovalStatus.approved,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${service.serviceTitle} is now live on the marketplace.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not approve listing.')),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    FirestoreService firestore,
    ServiceListing service,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject listing'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Tell the provider what to fix before resubmitting',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !context.mounted) return;

    try {
      await firestore.adminSetServiceApproval(
        serviceId: service.serviceId,
        status: ServiceApprovalStatus.rejected,
        rejectionReason: reason.isEmpty ? 'Does not meet listing guidelines.' : reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${service.serviceTitle} rejected.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reject listing.')),
        );
      }
    }
  }

  void _onMenu(
    BuildContext context,
    FirestoreService firestore,
    AdminServiceTableRow row,
    String action,
  ) {
    switch (action) {
      case 'provider':
        widget.onNavigateToTab?.call(2);
      case 'approve':
        _approve(context, firestore, row.service);
      case 'reject':
        _reject(context, firestore, row.service);
      case 'hide':
      case 'show':
        _toggleActive(context, firestore, row.service, action == 'show');
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export services — coming soon.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Manage Services',
        subtitle: 'Review new listings before they go live; hide approved services when needed.',
        child: const AdminErrorBox(message: 'Firebase admin required.'),
      );
    }

    final firestore = FirestoreService();

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder<List<ServiceListing>>(
        stream: firestore.allServicesStream(),
        builder: (context, serviceSnap) {
          if (serviceSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoadingBox(message: 'Loading services…');
          }

          return StreamBuilder<List<AppUser>>(
            stream: firestore.allUsersStream(),
            builder: (context, userSnap) {
              return StreamBuilder<List<ServiceProviderProfile>>(
                stream: firestore.serviceProvidersStream(),
                builder: (context, providerSnap) {
                  final services = serviceSnap.data ?? [];
                  final usersById = <String, AppUser>{
                    for (final u in userSnap.data ?? []) u.userId: u,
                  };
                  final profilesByUser = <String, ServiceProviderProfile>{
                    for (final p in providerSnap.data ?? []) p.userId: p,
                  };
                  final profilesById = <String, ServiceProviderProfile>{
                    for (final p in providerSnap.data ?? []) p.providerId: p,
                  };

                  final allRows = [
                    for (final s in services)
                      AdminServiceTableRow(
                        service: s,
                        providerUser: usersById[s.providerId],
                        providerProfile:
                            profilesByUser[s.providerId] ?? profilesById[s.providerId],
                      ),
                  ];

                  final categoryOptions = _categoryOptions(services);
                  final rows = _filterRows(allRows);

                  final total = services.length;
                  var pending = 0;
                  var live = 0;
                  var paused = 0;
                  var rejected = 0;
                  for (final s in services) {
                    if (s.isMarketplaceVisible) {
                      live++;
                    } else if (s.approvalStatus == ServiceApprovalStatus.pending) {
                      pending++;
                    } else if (s.approvalStatus == ServiceApprovalStatus.rejected) {
                      rejected++;
                    } else if (s.approvalStatus == ServiceApprovalStatus.approved && !s.isActive) {
                      paused++;
                    }
                  }
                  final livePct = total > 0 ? ((live / total) * 100).round() : 0;
                  final pendingPct = total > 0 ? ((pending / total) * 100).round() : 0;

                  final topCategory = computeTopCategory(services);
                  final topCategoryCount = countForCategory(services, topCategory);

                  final totalPages = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
                  final page = _page.clamp(1, totalPages);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AdminDashboardHeader(
                        title: 'Manage Services',
                        subtitle: 'Review new listings before they go live; hide approved services when needed.',
                      ),
                      const SizedBox(height: 24),
                      AdminMetricGrid(
                        children: [
                          AdminMetricCard(
                            label: 'Total Services',
                            value: '$total',
                            hint: '↗ 0% vs last 30 days',
                            icon: Icons.work_outline,
                            iconBg: FigmaColors.tintGreen,
                            iconColor: FigmaColors.green,
                          ),
                          AdminMetricCard(
                            label: 'Pending Review',
                            value: '$pending',
                            hint: 'Filter: Pending review',
                            icon: Icons.rate_review_outlined,
                            iconBg: FigmaColors.orange50,
                            iconColor: FigmaColors.orange600,
                            trendLabel: pending > 0 ? 'Needs action' : 'All caught up',
                          ),
                          AdminMetricCard(
                            label: 'Live on Marketplace',
                            value: '$live',
                            hint: 'Approved and visible',
                            icon: Icons.check_circle_outline,
                            iconBg: FigmaColors.tintGreen2,
                            iconColor: FigmaColors.green,
                            trendLabel: '$livePct% of total',
                          ),
                          AdminMetricCard(
                            label: 'Approved but Paused',
                            value: '$paused',
                            hint: 'Hidden by admin or provider',
                            icon: Icons.visibility_off_outlined,
                            iconBg: FigmaColors.tintBlue,
                            iconColor: FigmaColors.navy,
                            trendLabel: '$pendingPct% pending',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AdminSplitSection(
                        breakpoint: 720,
                        main: AdminServicesTablePanel(
                          rows: rows,
                          searchController: _searchController,
                          categoryFilter: _categoryFilter,
                          statusFilter: _statusFilter,
                          categoryOptions: categoryOptions,
                          onCategoryFilterChanged: (v) => setState(() {
                            _categoryFilter = v;
                            _page = 1;
                          }),
                          onStatusFilterChanged: (v) => setState(() {
                            _statusFilter = v;
                            _page = 1;
                          }),
                          onSearchChanged: (v) => setState(() {
                            _search = v;
                            _page = 1;
                          }),
                          selectedId: _selectedId,
                          onSelect: (r, selected) => setState(
                            () => _selectedId = selected ? r.service.serviceId : null,
                          ),
                          onExport: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Export services — coming soon.')),
                            );
                          },
                          onHide: (r) => _toggleActive(context, firestore, r.service, !r.service.isActive),
                          page: page,
                          pageSize: _pageSize,
                          onPageChanged: (p) => setState(() => _page = p),
                          onPageSizeChanged: (s) => setState(() {
                            _pageSize = s;
                            _page = 1;
                          }),
                          onMenu: (r, action) => _onMenu(context, firestore, r, action),
                          onOpenDetail: (r) => showAdminServiceDetail(
                            context,
                            row: r,
                            onAction: (action) => _onMenu(context, firestore, r, action),
                          ),
                        ),
                        side: Column(
                          children: [
                            AdminServiceInsightsPanel(
                              live: live,
                              pendingReview: pending,
                              paused: paused,
                              rejected: rejected,
                              topCategory: topCategory,
                              topCategoryCount: topCategoryCount,
                              total: total,
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
