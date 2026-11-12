import '../../../services/export_service.dart';
import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../figma_ui/widgets/figma_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
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
      list = list.where((r) {
        final cat = r.service.category.trim().isEmpty
            ? 'Uncategorized'
            : r.service.category.trim();
        return cat == _categoryFilter;
      }).toList();
    }

    if (_statusFilter != 'All Statuses') {
      list = list
          .where((r) => serviceMatchesStatusFilter(r.service, _statusFilter))
          .toList();
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
      final cat = s.category.trim().isEmpty
          ? 'Uncategorized'
          : s.category.trim();
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
          SnackBar(
            content: Text(
              active
                  ? 'Service is now active'
                  : 'Service hidden from marketplace',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update service. Check admin permissions.'),
          ),
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
      final profile = await firestore.getProviderProfileForListing(
        service.providerId,
      );
      if (!context.mounted) return;
      final cert = profile?.certificationHistory
          .where((c) => c.id == service.certificationEntryId)
          .firstOrNull;
      var notes = '';
      var confirmed = false;
      final review = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: const Text('Review service and certificate alignment'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${service.category} · ${service.serviceTitle}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(service.description),
                    const SizedBox(height: 12),
                    Text(
                      cert == null
                          ? 'No selected certificate. Ask the provider to complete and resubmit the listing.'
                          : '${cert.name}\nIssuer: ${cert.provider}\nCertificate: ${cert.certificationId}\nStatus: ${cert.status.firestoreValue}\nValid until: ${cert.expirationDate}',
                    ),
                    if (cert != null)
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View selected certificate'),
                        onPressed: () async {
                          try {
                            final url = await StorageService().readableUrl(
                              cert.url,
                            );
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Certificate unavailable. Check access and try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final url in service.serviceImages)
                          SizedBox(
                            width: 140,
                            height: 110,
                            child: FigmaNetworkImage(
                              url: url,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      onChanged: (v) => refresh(() => confirmed = v ?? false),
                      title: const Text(
                        'I confirm this credential covers the service scope and category, and the photos meet listing requirements.',
                      ),
                    ),
                    TextField(
                      maxLength: 3000,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (v) => refresh(() => notes = v),
                      decoration: const InputDecoration(
                        labelText: 'Alignment review notes (required)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    cert != null && confirmed && notes.trim().length >= 10
                    ? () => Navigator.pop(ctx, notes.trim())
                    : null,
                child: const Text('Approve listing'),
              ),
            ],
          ),
        ),
      );
      if (review == null || !context.mounted) return;
      await firestore.adminSetServiceApproval(
        serviceId: service.serviceId,
        status: ServiceApprovalStatus.approved,
        alignmentConfirmed: true,
        notes: review,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${service.serviceTitle} is now live on the marketplace.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not approve listing.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    FirestoreService firestore,
    ServiceListing service,
  ) async {
    var enteredReason = '';
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject listing'),
        content: TextField(
          onChanged: (v) => enteredReason = v,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason (required, at least 10 characters)',
            hintText: 'Tell the provider what to fix before resubmitting',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (enteredReason.trim().length >= 10) {
                Navigator.pop(dialogContext, enteredReason.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || !context.mounted) return;

    try {
      await firestore.adminSetServiceApproval(
        serviceId: service.serviceId,
        status: ServiceApprovalStatus.rejected,
        rejectionReason: reason.isEmpty
            ? 'Does not meet listing guidelines.'
            : reason,
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
        ExportService.exportCollection(context, 'services');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Manage Services',
        subtitle:
            'Review new listings before they go live; hide approved services when needed.',
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
                            profilesByUser[s.providerId] ??
                            profilesById[s.providerId],
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
                    } else if (s.approvalStatus ==
                        ServiceApprovalStatus.pending) {
                      pending++;
                    } else if (s.approvalStatus ==
                        ServiceApprovalStatus.rejected) {
                      rejected++;
                    } else if (s.approvalStatus ==
                            ServiceApprovalStatus.approved &&
                        !s.isActive) {
                      paused++;
                    }
                  }
                  final livePct = total > 0
                      ? ((live / total) * 100).round()
                      : 0;
                  final pausedPct = total > 0
                      ? ((paused / total) * 100).round()
                      : 0;

                  final topCategory = computeTopCategory(services);
                  final topCategoryCount = countForCategory(
                    services,
                    topCategory,
                  );

                  final totalPages = rows.isEmpty
                      ? 1
                      : (rows.length / _pageSize).ceil();
                  final page = _page.clamp(1, totalPages);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AdminDashboardHeader(
                        title: 'Manage Services',
                        subtitle:
                            'Review new listings before they go live; hide approved services when needed.',
                      ),
                      const SizedBox(height: 24),
                      AdminMetricGrid(
                        children: [
                          AdminMetricCard(
                            label: 'Total Services',
                            value: '$total',
                            hint: 'All listing statuses',
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
                            trendLabel: pending > 0
                                ? 'Needs action'
                                : 'All caught up',
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
                            trendLabel: '$pausedPct% of total',
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
                            () => _selectedId = selected
                                ? r.service.serviceId
                                : null,
                          ),
                          onExport: () {
                            ExportService.exportCollection(context, 'services');
                          },
                          onHide: (r) => _toggleActive(
                            context,
                            firestore,
                            r.service,
                            !r.service.isActive,
                          ),
                          page: page,
                          pageSize: _pageSize,
                          onPageChanged: (p) => setState(() => _page = p),
                          onPageSizeChanged: (s) => setState(() {
                            _pageSize = s;
                            _page = 1;
                          }),
                          onMenu: (r, action) =>
                              _onMenu(context, firestore, r, action),
                          onOpenDetail: (r) => showAdminServiceDetail(
                            context,
                            row: r,
                            onAction: (action) =>
                                _onMenu(context, firestore, r, action),
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
