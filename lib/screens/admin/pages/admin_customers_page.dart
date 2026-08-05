import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/account_status.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_customers_widgets.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  final _searchController = TextEditingController();
  String _search = '';
  String _statusFilter = 'All Status';
  int _page = 1;
  int _pageSize = 10;
  String? _selectedId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filterCustomers(List<AppUser> users) {
    var list = users.where((u) => u.role == UserRole.customer).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_statusFilter != 'All Status') {
      list = list.where((u) => u.accountStatus.firestoreValue == _statusFilter).toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q),
          )
          .toList();
    }

    return list;
  }

  void _onMenu(AppUser user, String action, FirestoreService firestore) async {
    switch (action) {
      case 'bookings':
        widget.onNavigateToTab?.call(7);
      case 'suspend':
        await firestore.adminSetUserAccountStatus(
          userId: user.userId,
          status: AccountStatus.suspended,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.fullName} suspended.')),
          );
        }
      case 'deactivate':
        await firestore.adminSetUserAccountStatus(
          userId: user.userId,
          status: AccountStatus.deactivated,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.fullName} deactivated.')),
          );
        }
      case 'notify':
        widget.onNavigateToTab?.call(10);
      case 'active':
        await firestore.adminSetUserAccountStatus(
          userId: user.userId,
          status: AccountStatus.active,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.fullName} is active again.')),
          );
        }
      case 'suspended':
        await firestore.adminSetUserAccountStatus(
          userId: user.userId,
          status: AccountStatus.suspended,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Manage Customers',
        subtitle: 'Review customer accounts and account status.',
        child: const AdminErrorBox(message: 'Firebase admin required.'),
      );
    }

    final firestore = FirestoreService();

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder<List<AppUser>>(
        stream: firestore.allUsersStream(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const AdminLoadingBox(message: 'Loading customers…');
          }

          return StreamBuilder<List<Booking>>(
            stream: firestore.allBookingsStream(),
            builder: (context, bookingSnap) {
              final allCustomers = userSnap.data ?? [];
              final customers = userSnap.data != null ? _filterCustomers(allCustomers) : <AppUser>[];
              final bookings = bookingSnap.data ?? [];

              final bookingCounts = <String, int>{};
              for (final b in bookings) {
                bookingCounts[b.customerId] = (bookingCounts[b.customerId] ?? 0) + 1;
              }

              final totalCustomers = allCustomers.where((u) => u.role == UserRole.customer).length;
              var active = 0;
              var suspended = 0;
              for (final u in allCustomers) {
                if (u.role != UserRole.customer) continue;
                if (u.accountStatus == AccountStatus.active) active++;
                if (u.accountStatus == AccountStatus.suspended) suspended++;
              }
              final totalBookings = bookings.length;
              final activePct = totalCustomers > 0 ? ((active / totalCustomers) * 100).round() : 0;
              final suspendedPct = totalCustomers > 0 ? ((suspended / totalCustomers) * 100).round() : 0;

              final totalPages = customers.isEmpty ? 1 : (customers.length / _pageSize).ceil();
              final page = _page.clamp(1, totalPages);

              AppUser? selected;
              if (_selectedId != null) {
                for (final u in customers) {
                  if (u.userId == _selectedId) {
                    selected = u;
                    break;
                  }
                }
              }

              final selectedBookings = selected == null
                  ? <Booking>[]
                  : bookings.where((b) => b.customerId == selected!.userId).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminDashboardHeader(
                    title: 'Manage Customers',
                    subtitle: 'Review customer accounts, status, and booking activity.',
                  ),
                  const SizedBox(height: 24),
                  AdminMetricGrid(
                    children: [
                        AdminMetricCard(
                          label: 'Total Customers',
                          value: '$totalCustomers',
                          hint: '— 0% vs last 30 days',
                          icon: Icons.people_outline,
                          iconBg: FigmaColors.tintGreen,
                          iconColor: FigmaColors.green,
                        ),
                        AdminMetricCard(
                          label: 'Active Accounts',
                          value: '$active',
                          hint: 'Registered and active',
                          icon: Icons.verified_user_outlined,
                          iconBg: FigmaColors.tintGreen2,
                          iconColor: FigmaColors.green,
                          trendLabel: '$activePct% of total',
                        ),
                        AdminMetricCard(
                          label: 'Suspended Accounts',
                          value: '$suspended',
                          hint: 'Temporarily restricted',
                          icon: Icons.person_off_outlined,
                          iconBg: FigmaColors.red50,
                          iconColor: FigmaColors.red600,
                          trendLabel: '$suspendedPct% of total',
                        ),
                        AdminMetricCard(
                          label: 'Total Bookings',
                          value: '$totalBookings',
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
                    main: AdminCustomersTablePanel(
                        customers: customers,
                        bookingCounts: bookingCounts,
                        searchController: _searchController,
                        statusFilter: _statusFilter,
                        onStatusFilterChanged: (v) => setState(() {
                          _statusFilter = v;
                          _page = 1;
                        }),
                        onSearchChanged: (v) => setState(() {
                          _search = v;
                          _page = 1;
                        }),
                        selectedId: _selectedId,
                        onSelect: (u, selected) => setState(
                          () => _selectedId = selected ? u.userId : null,
                        ),
                        onExport: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export customers — coming soon.')),
                          );
                        },
                        page: page,
                        pageSize: _pageSize,
                        onPageChanged: (p) => setState(() => _page = p),
                        onPageSizeChanged: (s) => setState(() {
                          _pageSize = s;
                          _page = 1;
                        }),
                        onStatusMenu: (u, action) => _onMenu(u, action, firestore),
                        onOpenDetail: (u) => showAdminCustomerDetail(
                          context,
                          user: u,
                          bookingCount: bookingCounts[u.userId] ?? 0,
                          onAction: (action) => _onMenu(u, action, firestore),
                        ),
                      ),
                    side: Column(
                      children: [
                        AdminCustomerInsightsPanel(
                          customer: selected,
                          bookings: selectedBookings,
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
