import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/admin_dashboard_stats.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({
    super.key,
    required this.auth,
    this.onNavigateToTab,
  });

  final AuthService auth;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  String _dateRange = 'This month';
  late final Future<AdminDashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = FirestoreService().adminDashboardStats();
  }

  void _go(int tab) => widget.onNavigateToTab?.call(tab);

  String _trendLabel(int count) {
    if (count <= 0) return '0% vs last month';
    return '+100% vs last month';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.isLocalAdminOnly) {
      return AdminPageFrame(
        auth: widget.auth,
        title: 'Dashboard Overview',
        subtitle: 'Connect a Firebase administrator account to load live platform data.',
        child: const AdminErrorBox(
          message: 'Sign in with a Firebase user whose Firestore role is Administrator.',
        ),
      );
    }

    final firestore = FirestoreService();

    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: FutureBuilder(
        future: _statsFuture,
        builder: (context, statsSnap) {
          if (statsSnap.connectionState != ConnectionState.done) {
            return const AdminLoadingBox(message: 'Loading dashboard…');
          }
          if (statsSnap.hasError || !statsSnap.hasData) {
            return const AdminErrorBox(message: 'Could not load dashboard stats.');
          }
          final stats = statsSnap.data!;

          return StreamBuilder<List<Booking>>(
            stream: firestore.allBookingsStream(),
            builder: (context, bookingSnap) {
              return StreamBuilder<List<AppUser>>(
                stream: firestore.allUsersStream(),
                builder: (context, userSnap) {
                  return StreamBuilder<List<ServiceListing>>(
                    stream: firestore.allServicesStream(),
                    builder: (context, serviceSnap) {
                      return StreamBuilder<List<ServiceProviderProfile>>(
                        stream: firestore.serviceProvidersStream(),
                        builder: (context, providerSnap) {
                          final bookings = bookingSnap.data ?? [];
                          final usersById = <String, AppUser>{
                            for (final u in userSnap.data ?? []) u.userId: u,
                          };
                          final servicesById = <String, ServiceListing>{
                            for (final s in serviceSnap.data ?? []) s.serviceId: s,
                          };
                          final providers = providerSnap.data ?? [];

                          var approved = 0;
                          var pendingV = 0;
                          var rejected = 0;
                          for (final p in providers) {
                            final st = p.verificationStatus.toLowerCase();
                            if (st == 'rejected') {
                              rejected++;
                            } else if (!p.isVerified || st == 'pending') {
                              pendingV++;
                            } else {
                              approved++;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AdminDashboardHeader(
                                title: 'Dashboard Overview',
                                subtitle: 'Live counts from Firestore — users, providers, bookings, and services.',
                                dateRange: _dateRange,
                                onDateRangeChanged: (v) => setState(() => _dateRange = v),
                                onExport: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Export report — coming soon.')),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              AdminMetricGrid(
                                children: [
                                    AdminMetricCard(
                                      label: 'Customers',
                                      value: '${stats.customerCount}',
                                      hint: 'Registered customers',
                                      icon: Icons.people_outline,
                                      iconBg: FigmaColors.tintGreen,
                                      iconColor: FigmaColors.green,
                                      trendLabel: _trendLabel(stats.customerCount),
                                    ),
                                    AdminMetricCard(
                                      label: 'Providers',
                                      value: '${stats.providerCount}',
                                      hint: 'Service provider profiles',
                                      icon: Icons.engineering_outlined,
                                      iconBg: FigmaColors.tintGreen2,
                                      iconColor: FigmaColors.green,
                                      trendLabel: _trendLabel(stats.providerCount),
                                    ),
                                    AdminMetricCard(
                                      label: 'Bookings',
                                      value: '${stats.bookingCount}',
                                      hint: 'Bookings (${stats.pendingBookingCount} pending)',
                                      icon: Icons.event_note_outlined,
                                      iconBg: FigmaColors.tintBlue,
                                      iconColor: FigmaColors.navy,
                                      trendLabel: _trendLabel(stats.bookingCount),
                                    ),
                                    AdminMetricCard(
                                      label: 'Verification',
                                      value: '${stats.pendingVerificationCount}',
                                      hint: 'Pending verification (${stats.activeServiceCount} active service)',
                                      icon: Icons.verified_user_outlined,
                                      iconBg: FigmaColors.yellow50,
                                      iconColor: FigmaColors.orange600,
                                      trendLabel: _trendLabel(stats.pendingVerificationCount),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              AdminSplitSection(
                                breakpoint: 720,
                                main: AdminPanelCard(
                                  title: 'Booking Trends',
                                  child: AdminBookingTrendChart(bookings: bookings),
                                ),
                                side: AdminPanelCard(
                                  title: 'Verification Status',
                                  child: AdminVerificationDonut(
                                    approved: approved,
                                    pending: pendingV,
                                    rejected: rejected,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              AdminSplitSection(
                                breakpoint: 720,
                                main: AdminRecentBookingsTable(
                                  bookings: bookings,
                                  usersById: usersById,
                                  servicesById: servicesById,
                                  onViewAll: () => _go(7),
                                  onOpenBooking: (b) => showAdminOverviewBookingDetail(
                                    context,
                                    booking: b,
                                    usersById: usersById,
                                    servicesById: servicesById,
                                    onViewAllBookings: () => _go(7),
                                  ),
                                ),
                                side: AdminPendingVerificationPanel(
                                  providers: providers,
                                  usersById: usersById,
                                  onViewAll: () => _go(4),
                                    onReview: (_) => _go(4),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
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
