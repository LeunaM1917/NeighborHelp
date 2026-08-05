import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/service.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/mobile_layout.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stream_snapshot.dart';
import '../provider_availability_screen.dart';
import '../provider_booking_detail_screen.dart';
import '../provider_booking_request_review.dart';
import '../widgets/provider_jobs_widgets.dart';

class ProviderJobsTab extends StatefulWidget {
  const ProviderJobsTab({
    super.key,
    required this.appUser,
    this.scrollController,
    this.onNavigateToTab,
  });

  final AppUser appUser;
  final ScrollController? scrollController;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<ProviderJobsTab> createState() => _ProviderJobsTabState();
}

class _ProviderJobsTabState extends State<ProviderJobsTab> {
  final _firestore = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';
  String _status = 'All statuses';
  String _category = 'All categories';
  String _sort = 'Newest first';
  int _page = 1;
  static const _pageSize = 5;

  Map<String, AppUser?> _customers = {};
  Map<String, ServiceListing?> _services = {};
  String? _hydratedKey;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _hydrate(List<Booking> bookings) async {
    final key = bookings.map((b) => b.bookingId).join(',');
    if (_hydratedKey == key) return;
    if (bookings.isEmpty) {
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
    for (final b in bookings) {
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

  Future<void> _respond(Booking booking, bool accept) async {
    try {
      await _firestore.providerRespondToBooking(
        bookingId: booking.bookingId,
        providerId: widget.appUser.userId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accept ? 'Booking accepted' : 'Booking declined')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update booking. Try again.')),
      );
    }
  }

  Future<void> _start(Booking booking) async {
    try {
      await _firestore.providerStartBooking(
        bookingId: booking.bookingId,
        providerId: widget.appUser.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job started')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start job. Try again.')),
      );
    }
  }

  Future<void> _complete(Booking booking) async {
    try {
      await _firestore.providerCompleteBooking(
        bookingId: booking.bookingId,
        providerId: widget.appUser.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as completed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete is only available after the work period ends.')),
      );
    }
  }

  void _openDetails(Booking booking) {
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
        child: FigmaWideContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: StreamBuilder<List<Booking>>(
              initialData: const [],
              stream: _firestore.bookingsForProviderUser(widget.appUser.userId),
              builder: (context, snap) {
                if (isStreamWaiting(snap)) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: LoadingIndicator(message: 'Loading bookings…'),
                  );
                }

                final allBookings = snap.data ?? [];
                if (_hydratedKey != allBookings.map((b) => b.bookingId).join(',')) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) unawaited(_hydrate(allBookings));
                  });
                }

                final serviceCategories = <String, String>{
                  for (final e in _services.entries)
                    if (e.value != null) e.key: e.value!.category,
                };
                final serviceTitles = <String, String>{
                  for (final e in _services.entries)
                    if (e.value != null) e.key: e.value!.serviceTitle,
                };
                final customerNames = <String, String>{
                  for (final e in _customers.entries)
                    e.key: e.value?.fullName ?? 'Customer',
                };

                final buckets = countJobBuckets(allBookings);
                final newRequests = buckets['new'] ?? 0;
                final accepted = buckets['accepted'] ?? 0;
                final inProgress = buckets['inProgress'] ?? 0;
                final completed = buckets['completed'] ?? 0;
                final cancelled = buckets['cancelled'] ?? 0;

                final categories = {
                  for (final c in serviceCategories.values)
                    if (c.isNotEmpty) c,
                }.toList()
                  ..sort();

                final filtered = filterProviderJobs(
                  bookings: allBookings,
                  query: _query,
                  status: _status,
                  category: _category,
                  sort: _sort,
                  serviceCategories: serviceCategories,
                  customerNames: customerNames,
                );

                final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
                final page = _page.clamp(1, totalPages);
                final start = (page - 1) * _pageSize;
                final pageItems = filtered.skip(start).take(_pageSize).toList();

                final rows = [
                  for (final b in pageItems)
                    ProviderJobListRow(
                      booking: b,
                      customerName: customerNames[b.customerId] ?? 'Customer',
                      serviceTitle: serviceTitles[b.serviceId] ?? 'Service',
                      category: serviceCategories[b.serviceId] ?? '',
                    ),
                ];

                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ProviderJobsHeader(),
                    const SizedBox(height: 24),
                    ProviderJobsStatsRow(
                      total: allBookings.length,
                      newRequests: newRequests,
                      inProgress: inProgress,
                      completed: completed,
                    ),
                    const SizedBox(height: 24),
                    ProviderJobsFilterBar(
                      searchController: _searchController,
                      status: _status,
                      category: _category,
                      sort: _sort,
                      categories: categories,
                      onStatusChanged: (v) => setState(() {
                        _status = v;
                        _page = 1;
                      }),
                      onCategoryChanged: (v) => setState(() {
                        _category = v;
                        _page = 1;
                      }),
                      onSortChanged: (v) => setState(() {
                        _sort = v;
                        _page = 1;
                      }),
                    ),
                    const SizedBox(height: 20),
                    ProviderJobsTablePanel(
                      rows: rows,
                      providerId: widget.appUser.userId,
                      hasAnyBookings: allBookings.isNotEmpty,
                      onViewDetails: _openDetails,
                      onRespond: _respond,
                      onStart: _start,
                      onComplete: _complete,
                    ),
                    const SizedBox(height: 20),
                    ProviderJobsPagination(
                      page: page,
                      pageSize: _pageSize,
                      total: filtered.length,
                      onPageChanged: (p) => setState(() => _page = p),
                    ),
                  ],
                );

                final side = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!MobileLayout.isNativeApp(context)) ...[
                      ProviderJobsQuickActionsPanel(
                        onViewMessages: () => widget.onNavigateToTab?.call(3),
                        onUpdateAvailability: () {
                          ProviderAvailabilityScreen.open(context, appUser: widget.appUser);
                        },
                        onManageServices: () => widget.onNavigateToTab?.call(1),
                        onViewEarnings: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Earnings report — coming soon.')),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    ProviderJobsOverviewPanel(
                      newCount: newRequests,
                      acceptedCount: accepted,
                      inProgressCount: inProgress,
                      completedCount: completed,
                      cancelledCount: cancelled,
                    ),
                    const SizedBox(height: 20),
                    const ProviderJobsResponseTipCard(),
                  ],
                );

                return LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth >= 1000) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: main),
                          const SizedBox(width: 24),
                          SizedBox(width: 300, child: side),
                        ],
                      );
                    }
                    return Column(
                      children: [main, const SizedBox(height: 28), side],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
