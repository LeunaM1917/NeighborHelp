import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/identity_verification_service.dart';
import '../widgets/admin_providers_widgets.dart';
import '../widgets/admin_verification_filters_bar.dart';
import '../widgets/admin_verification_widgets.dart';
import '../widgets/admin_widgets.dart';

class AdminVerificationPage extends StatefulWidget {
  const AdminVerificationPage({
    super.key,
    required this.auth,
    this.forAgency = false,
    this.reviewerUserId,
  });

  final AuthService auth;

  /// When true, UI is branded for the Verification Agency (primary identity reviewer).
  final bool forAgency;

  /// Firebase uid recorded on approve/reject (agency or admin).
  final String? reviewerUserId;

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  final _searchController = TextEditingController();
  final _verificationService = IdentityVerificationService();
  /// Bumps on filter changes so only the list rebuilds — not the [StreamBuilder] tree.
  final _filterRevision = ValueNotifier(0);
  String _search = '';
  late String _statusFilter;
  String _dateSort = 'Newest first';

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.forAgency ? 'Pending' : 'All status';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterRevision.dispose();
    super.dispose();
  }

  void _bumpFilters() => _filterRevision.value++;

  List<AdminVerificationApplication> _buildApplications({
    required List<ServiceProviderProfile> providers,
    required List<AppUser> users,
    required Map<String, AppUser> usersById,
  }) {
    var providerList = providers
        .where((p) => verificationStatusMatchesFilter(p, _statusFilter))
        .toList();

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      providerList = providerList.where((p) {
        final user = usersById[p.userId];
        final name = user?.fullName.toLowerCase() ?? '';
        final email = user?.email.toLowerCase() ?? '';
        final business = p.bio.toLowerCase();
        final area = p.serviceArea.toLowerCase();
        return name.contains(q) || email.contains(q) || business.contains(q) || area.contains(q);
      }).toList();
    }

    var customerList = users
        .where((u) => u.role == UserRole.customer && u.identityVerification.hasStarted)
        .where((u) => customerVerificationMatchesFilter(u, _statusFilter))
        .toList();

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      customerList = customerList.where((u) {
        final name = u.fullName.toLowerCase();
        final email = u.email.toLowerCase();
        final address = (u.address ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || address.contains(q);
      }).toList();
    }

    final apps = <AdminVerificationApplication>[
      for (final p in providerList)
        AdminVerificationApplication.provider(
          profile: p,
          user: usersById[p.userId] ?? usersById[p.providerId],
          businessLabel: p.bio.trim().isNotEmpty
              ? p.bio.trim()
              : (p.serviceArea.isNotEmpty ? p.serviceArea : ''),
        ),
      for (final c in customerList)
        AdminVerificationApplication.customer(
          customer: c,
          businessLabel: c.address?.trim().isNotEmpty == true ? c.address!.trim() : 'NeighborHelp customer',
        ),
    ];

    apps.sort((a, b) {
      final cmp = a.submittedAt.compareTo(b.submittedAt);
      return _dateSort == 'Newest first' ? -cmp : cmp;
    });

    return apps;
  }

  int _countBucketThisMonthProviders(List<ServiceProviderProfile> providers, int bucket) {
    return providers.where((p) {
      if (providerVerificationBucket(p.verificationStatus, p.isVerified) != bucket) return false;
      return isTimestampThisMonth(p.updatedAt.toDate());
    }).length;
  }

  int _countBucketThisMonthCustomers(List<AppUser> users, int bucket) {
    return users.where((u) {
      final v = u.identityVerification;
      if (providerVerificationBucket(v.verificationStatus, v.isVerified) != bucket) return false;
      return isTimestampThisMonth(u.updatedAt.toDate());
    }).length;
  }

  Future<void> _verify(
    BuildContext context,
    FirestoreService firestore,
    AdminVerificationApplication application,
    bool approve,
  ) async {
    if (application.isCustomer) {
      final user = application.customer!;
      if (!user.canAdminReviewVerification) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer must finish Didit verification before you can approve or reject.'),
            ),
          );
        }
        return;
      }
      try {
        await firestore.adminVerifyCustomer(
          userId: user.userId,
          approve: approve,
          reviewedByUserId: widget.reviewerUserId,
          reviewedByRole: widget.forAgency ? 'Verification Agency' : 'Administrator',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? 'Customer verified' : 'Customer verification rejected')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.forAgency
                    ? 'Action failed. Check Verification Agency permissions.'
                    : 'Action failed. Check admin permissions.',
              ),
            ),
          );
        }
      }
      return;
    }

    final profile = application.profile!;
    if (!profile.canAdminReviewVerification) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Provider must finish Didit verification before you can approve or reject.'),
          ),
        );
      }
      return;
    }
    try {
      await firestore.adminVerifyProvider(
        providerId: profile.providerId,
        approve: approve,
        reviewedByUserId: widget.reviewerUserId,
        reviewedByRole: widget.forAgency ? 'Verification Agency' : 'Administrator',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Provider approved' : 'Provider rejected')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.forAgency
                  ? 'Action failed. Check Verification Agency permissions.'
                  : 'Action failed. Check admin permissions.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshDidit(
    BuildContext context,
    AdminVerificationApplication application,
  ) async {
    final subject = application.isCustomer ? VerificationSubject.customer : VerificationSubject.provider;
    // refreshDiditStatus expects the Firebase Auth user id, which is the
    // serviceProviders document id in this app.
    final userId = application.isCustomer ? application.customer!.userId : application.profile!.userId;
    try {
      final status = await _verificationService.refreshDiditStatusForAdmin(
        userId: userId,
        subject: subject,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Didit status refreshed: $status')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh Didit status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly && !widget.forAgency) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Identity verification',
        subtitle: 'Monitor Didit ID checks. Primary approval is by the Verification Agency.',
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
          if (providerSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoadingBox(message: 'Loading verification queue…');
          }

          return StreamBuilder<List<AppUser>>(
            stream: firestore.allUsersStream(),
            builder: (context, userSnap) {
              final providers = providerSnap.data ?? [];
              final usersById = <String, AppUser>{
                for (final u in userSnap.data ?? []) u.userId: u,
              };

              final allUsers = userSnap.data ?? [];
              final customers = allUsers.where((u) => u.role == UserRole.customer).toList();
              final pending = providers.where((p) => p.canAdminReviewVerification).length +
                  customers.where((u) => u.canAdminReviewVerification).length;
              final approvedMonth = _countBucketThisMonthProviders(providers, 0) +
                  _countBucketThisMonthCustomers(customers, 0);
              final rejectedMonth = _countBucketThisMonthProviders(providers, 2) +
                  _countBucketThisMonthCustomers(customers, 2);
              final total = providers.length + customers.where((u) => u.identityVerification.hasStarted).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminVerificationPageHeader(
                    title: widget.forAgency ? 'Verification Agency review' : 'Identity verification',
                    subtitle: widget.forAgency
                        ? 'Review submitted government ID and Didit facial verification. Approve or reject identity requests.'
                        : 'Monitor identity records and handle exceptional cases. Primary approval is by the Verification Agency.',
                  ),
                  const SizedBox(height: 24),
                  AdminMetricGrid(
                    children: [
                      AdminVerificationStatCard(
                        value: '$pending',
                        label: 'Pending verification',
                        hint: 'Didit complete — needs review',
                        hintColor: FigmaColors.orange600,
                        icon: Icons.schedule_outlined,
                        iconBg: FigmaColors.yellow50,
                        iconColor: FigmaColors.orange600,
                      ),
                      AdminVerificationStatCard(
                        value: '$approvedMonth',
                        label: 'Approved',
                        hint: 'This month',
                        hintColor: FigmaColors.green,
                        icon: Icons.check_circle_outline,
                        iconBg: FigmaColors.tintGreen,
                        iconColor: FigmaColors.green,
                      ),
                      AdminVerificationStatCard(
                        value: '$rejectedMonth',
                        label: 'Rejected',
                        hint: 'This month',
                        hintColor: FigmaColors.red600,
                        icon: Icons.cancel_outlined,
                        iconBg: FigmaColors.red50,
                        iconColor: FigmaColors.red600,
                      ),
                      AdminVerificationStatCard(
                        value: '$total',
                        label: 'Total applications',
                        hint: 'Providers + customers',
                        hintColor: FigmaColors.navy,
                        icon: Icons.groups_outlined,
                        iconBg: FigmaColors.tintBlue,
                        iconColor: FigmaColors.navy,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AdminVerificationFiltersBar(
                    searchController: _searchController,
                    onSearchChanged: (v) {
                      _search = v;
                      _bumpFilters();
                    },
                    statusFilter: _statusFilter,
                    onStatusFilterChanged: (v) {
                      _statusFilter = v;
                      _bumpFilters();
                    },
                    dateSort: _dateSort,
                    onDateSortChanged: (v) {
                      _dateSort = v;
                      _bumpFilters();
                    },
                    onFiltersTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Advanced filters — coming soon.')),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<int>(
                    valueListenable: _filterRevision,
                    builder: (context, _, __) {
                      final applications = _buildApplications(
                        providers: providers,
                        users: allUsers,
                        usersById: usersById,
                      );
                      final showPendingEmpty = applications.isEmpty &&
                          _search.trim().isEmpty &&
                          (_statusFilter == 'All status' || _statusFilter == 'Pending');

                      if (applications.isEmpty) {
                        return AdminVerificationEmptyState(
                          showPendingMessage: showPendingEmpty,
                          onNotifyTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You will be notified when new applications are submitted.'),
                              ),
                            );
                          },
                        );
                      }
                      return AdminVerificationApplicationsList(
                        applications: applications,
                        onApprove: (app) => _verify(context, firestore, app, true),
                        onReject: (app) => _verify(context, firestore, app, false),
                        onRefreshDidit: (app) => _refreshDidit(context, app),
                      );
                    },
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
