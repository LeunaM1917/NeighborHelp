import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/mobile_layout.dart';
import '../../../utils/review_sentiment.dart';
import '../../../widgets/app_footer.dart';
import '../../../widgets/provider_profile_builder.dart';
import '../provider_availability_screen.dart';
import '../provider_booking_detail_screen.dart';
import '../provider_booking_request_review.dart';
import '../provider_profile_completion.dart';
import '../provider_service_form_screen.dart';
import '../widgets/provider_dashboard_widgets.dart';

class ProviderDashboardTab extends StatefulWidget {
  const ProviderDashboardTab({
    super.key,
    required this.appUser,
    this.scrollController,
    this.onNavigateToTab,
  });

  final AppUser appUser;
  final ScrollController? scrollController;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
  final _firestore = FirestoreService();
  Map<String, AppUser?> _customers = {};
  Map<String, ServiceListing?> _services = {};
  String? _hydratedKey;
  int _reviewCount = 0;
  double _displayRating = 0;
  bool _reviewsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadReviewCount();
  }

  Future<void> _loadReviewCount() async {
    final profile = await _firestore.getProviderProfile(widget.appUser.userId);
    final providerId = profile?.providerId ?? widget.appUser.userId;
    final reviews = await _firestore.reviewsForProvider(providerId);
    if (!mounted) return;
    setState(() {
      _reviewCount = reviews.length;
      // Live review mean for display; profile.averageRating is Bayesian (ranking only).
      _displayRating = effectiveProviderRating(
        profileAverage: profile?.averageRating ?? 0,
        reviews: reviews,
      );
      _reviewsLoaded = true;
    });
  }

  Future<void> _hydrateRecent(List<Booking> bookings) async {
    final recent = _recentBookings(bookings).take(3).toList();
    final key = recent.map((b) => b.bookingId).join(',');
    if (_hydratedKey == key) return;
    if (recent.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hydratedKey = '';
        _customers = {};
        _services = {};
      });
      return;
    }
    final customers = <String, AppUser?>{};
    final services = <String, ServiceListing?>{};
    for (final b in recent) {
      customers[b.customerId] ??= await _firestore.getUser(b.customerId);
      services[b.serviceId] ??= await _firestore.getService(b.serviceId);
    }
    if (!mounted) return;
    setState(() {
      _hydratedKey = key;
      _customers = customers;
      _services = services;
    });
  }

  List<Booking> _recentBookings(List<Booking> bookings) {
    final copy = List<Booking>.from(bookings);
    copy.sort((a, b) {
      final ap = a.status.toLowerCase() == 'pending';
      final bp = b.status.toLowerCase() == 'pending';
      if (ap != bp) return ap ? -1 : 1;
      return b.scheduledDate.compareTo(a.scheduledDate);
    });
    return copy;
  }

  int _completedThisMonth(List<Booking> bookings) {
    final now = DateTime.now();
    return bookings.where((b) {
      if (b.status.toLowerCase() != 'completed') return false;
      final d = b.updatedAt.toDate();
      return d.year == now.year && d.month == now.month;
    }).length;
  }

  int _completedLastMonth(List<Booking> bookings) {
    final lm = DateTime(DateTime.now().year, DateTime.now().month - 1);
    return bookings.where((b) {
      if (b.status.toLowerCase() != 'completed') return false;
      final d = b.updatedAt.toDate();
      return d.year == lm.year && d.month == lm.month;
    }).length;
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : 'there';
  }

  void _openBooking(Booking booking) {
    if (booking.isPending) {
      showProviderBookingRequestReview(context, appUser: widget.appUser, booking: booking);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProviderBookingDetailScreen(appUser: widget.appUser, booking: booking),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FigmaColors.gray50,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProviderDashboardHero(
              firstName: _firstName(widget.appUser.fullName),
            ),
            FigmaWideContainer(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 32),
                child: ProviderProfileBuilder(
                  userId: widget.appUser.userId,
                  builder: (context, profile) {
                    return StreamBuilder<List<Booking>>(
                      initialData: const [],
                      stream: _firestore.bookingsForProviderUser(widget.appUser.userId),
                      builder: (context, bookingSnap) {
                        final bookings = bookingSnap.data ?? [];
                        return StreamBuilder<List<ServiceListing>>(
                          initialData: const [],
                          stream: _firestore.servicesForProviderUser(widget.appUser.userId),
                          builder: (context, serviceSnap) {
                            final services = serviceSnap.data ?? [];
                            final activeServices = services.where((s) => s.isActive).length;
                            final pending = bookings.where((b) => b.status.toLowerCase() == 'pending').length;
                            final completedJobs = profile?.completedBookings ??
                                bookings.where((b) => b.status.toLowerCase() == 'completed').length;
                            final thisMonth = _completedThisMonth(bookings);
                            final lastMonth = _completedLastMonth(bookings);
                            final delta = thisMonth - lastMonth;
                            final trendLabel = delta > 0
                                ? '+$delta this month'
                                : delta < 0
                                    ? '$delta this month'
                                    : 'No change this month';

                            final recent = _recentBookings(bookings).take(3).toList();
                            if (_hydratedKey != recent.map((b) => b.bookingId).join(',')) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) unawaited(_hydrateRecent(bookings));
                              });
                            }

                            final rows = [
                              for (final b in recent)
                                ProviderRecentJobRow(
                                  booking: b,
                                  customerName: _customers[b.customerId]?.fullName ?? 'Customer',
                                  serviceTitle: _services[b.serviceId]?.serviceTitle ?? 'Service',
                                ),
                            ];

                            final rating = _reviewsLoaded ? _displayRating : (profile?.averageRating ?? 0);
                            final reviewCount = _reviewsLoaded ? _reviewCount : 0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ProviderDashboardStatsRow(
                                  rating: rating,
                                  reviewCount: reviewCount,
                                  completedJobs: completedJobs,
                                  completedTrendLabel: trendLabel,
                                  pendingRequests: pending,
                                  activeServices: activeServices,
                                ),
                                const SizedBox(height: 28),
                                LayoutBuilder(
                                  builder: (context, c) {
                                    final wide = c.maxWidth >= 1000;
                                    final main = Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        ProviderRecentJobRequestsPanel(
                                          rows: rows,
                                          onViewAll: () => widget.onNavigateToTab?.call(2),
                                          onRespond: _openBooking,
                                          onView: _openBooking,
                                        ),
                                        const SizedBox(height: 20),
                                        ProviderPerformanceOverviewPanel(bookings: bookings),
                                      ],
                                    );
                                    final side = Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        ProviderProfileProgressPanel(
                                          appUser: widget.appUser,
                                          profile: profile,
                                          services: services,
                                          reviewCount: reviewCount,
                                          onRequirementTap: (id) => navigateToProviderProfileRequirement(
                                            context,
                                            id: id,
                                            appUser: widget.appUser,
                                            profile: profile,
                                            onNavigateToTab: widget.onNavigateToTab,
                                          ),
                                        ),
                                        if (!MobileLayout.isNativeApp(context)) ...[
                                          const SizedBox(height: 20),
                                          ProviderQuickActionsPanel(
                                            onAddService: () {
                                              widget.onNavigateToTab?.call(1);
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                if (!context.mounted) return;
                                                ProviderServiceFormScreen.open(
                                                  context,
                                                  appUser: widget.appUser,
                                                );
                                              });
                                            },
                                            onManageServices: () => widget.onNavigateToTab?.call(1),
                                            onViewMessages: () => widget.onNavigateToTab?.call(3),
                                            onUpdateAvailability: () {
                                              ProviderAvailabilityScreen.open(context, appUser: widget.appUser);
                                            },
                                          ),
                                        ],
                                      ],
                                    );

                                    if (!wide) {
                                      return Column(
                                        children: [main, const SizedBox(height: 20), side],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: main),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 2, child: side),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const CachedAppFooter.provider(),
          ],
        ),
      ),
    );
  }
}
