import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../figma_ui/marketing_service_images.dart';
import '../../../figma_ui/widgets/figma_empty_state.dart';
import '../../../figma_ui/widgets/figma_network_image.dart';
import '../../../figma_ui/widgets/figma_status_chip.dart';
import '../../../models/account_status.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/user_role.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../models/service_approval_status.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/mobile_layout.dart';
import '../../../theme/role_theme.dart';
import '../../../ui/app_ui_kit.dart';
import '../../../widgets/app_footer.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stream_snapshot.dart';
import '../../shared/help_support_popover.dart';
import '../../shared/messages_hub.dart';
import '../customer_booking_detail_screen.dart';

enum _BookingFilter { all, upcoming, inProgress, completed, cancelled }

enum _BookingSort { latest, oldest, serviceName }

class CustomerBookingsTab extends StatefulWidget {
  const CustomerBookingsTab({
    super.key,
    required this.appUser,
    this.scrollController,
  });

  final AppUser appUser;
  final ScrollController? scrollController;

  @override
  State<CustomerBookingsTab> createState() => _CustomerBookingsTabState();
}

class _CustomerBookingsTabState extends State<CustomerBookingsTab> {
  final _searchController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  _BookingFilter _filter = _BookingFilter.all;
  _BookingSort _sort = _BookingSort.latest;
  String _query = '';

  Map<String, ServiceListing?> _services = {};
  Map<String, AppUser?> _providers = {};
  Map<String, ServiceProviderProfile?> _profiles = {};
  String? _hydratedKey;

  static const _sidebarWidth = 320.0;
  static const _columnGap = 28.0;
  static const _twoColumnMinWidth = 1000.0;

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
        _services = {};
        _providers = {};
        _profiles = {};
      });
      return;
    }
    final services = <String, ServiceListing?>{};
    final providers = <String, AppUser?>{};
    final profiles = <String, ServiceProviderProfile?>{};
    for (final b in bookings) {
      if (b.bookingId.startsWith('demo-')) continue;
      services[b.serviceId] ??= await _firestore.getService(b.serviceId);
      providers[b.providerId] ??= await _firestore.getUser(b.providerId);
      profiles[b.providerId] ??= await _firestore.getProviderProfile(b.providerId);
    }
    if (!mounted) return;
    setState(() {
      _hydratedKey = key;
      _services = services;
      _providers = providers;
      _profiles = profiles;
    });
  }

  _BookingBucket _bucket(Booking b) {
    final s = b.status.toLowerCase();
    if (s == 'cancelled' || s == 'canceled') return _BookingBucket.cancelled;
    if (s == 'completed' || s == 'milestone complete') return _BookingBucket.completed;
    if (s == 'in progress') return _BookingBucket.inProgress;
    return _BookingBucket.upcoming;
  }

  bool _matchesFilter(Booking b, _BookingFilter f) {
    if (f == _BookingFilter.all) return true;
    return _bucket(b) == switch (f) {
      _BookingFilter.upcoming => _BookingBucket.upcoming,
      _BookingFilter.inProgress => _BookingBucket.inProgress,
      _BookingFilter.completed => _BookingBucket.completed,
      _BookingFilter.cancelled => _BookingBucket.cancelled,
      _BookingFilter.all => _BookingBucket.upcoming,
    };
  }

  List<Booking> _sorted(List<Booking> list) {
    final copy = [...list];
    copy.sort((a, b) {
      switch (_sort) {
        case _BookingSort.oldest:
          return a.scheduledDate.compareTo(b.scheduledDate);
        case _BookingSort.serviceName:
          final ta = _services[a.serviceId]?.serviceTitle ?? '';
          final tb = _services[b.serviceId]?.serviceTitle ?? '';
          return ta.compareTo(tb);
        case _BookingSort.latest:
          return b.scheduledDate.compareTo(a.scheduledDate);
      }
    });
    return copy;
  }

  List<Booking> _visible(List<Booking> all) {
    var list = all.where((b) => _matchesFilter(b, _filter)).toList();
    if (_query.isNotEmpty) {
      list = list.where((b) {
        final service = _services[b.serviceId]?.serviceTitle ?? '';
        final provider = _providers[b.providerId]?.fullName ?? '';
        final id = b.bookingId.toLowerCase();
        return id.contains(_query) ||
            service.toLowerCase().contains(_query) ||
            provider.toLowerCase().contains(_query);
      }).toList();
    }
    return _sorted(list);
  }

  Map<_BookingBucket, int> _counts(List<Booking> all) {
    return {
      for (final bucket in _BookingBucket.values)
        bucket: all.where((b) => _bucket(b) == bucket).length,
    };
  }

  void _openDetail(Booking booking) {
    if (booking.bookingId.startsWith('demo-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is a preview booking.')),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBookingDetailScreen(
          appUser: widget.appUser,
          booking: booking,
        ),
      ),
    );
  }

  void _messageProvider(Booking booking) {
    if (booking.bookingId.startsWith('demo-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging is available for real bookings.')),
      );
      return;
    }
    MessagesHub.openConversation(
      context,
      appUser: widget.appUser,
      booking: booking,
      asCustomer: true,
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
            FigmaWideContainer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  MobileLayout.isNativeApp(context) ? 16 : 32,
                  0,
                  MobileLayout.pageBottomPadding(context),
                ),
                child: StreamBuilder<List<Booking>>(
                  stream: _firestore.bookingsForUser(widget.appUser.userId, asCustomer: true),
                  builder: (context, snap) {
                    if (isStreamWaiting(snap)) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: LoadingIndicator(message: 'Loading bookings…'),
                      );
                    }

                    var bookings = snap.data ?? [];
                    if (bookings.isEmpty) {
                      bookings = _demoBookings(widget.appUser.userId);
                    }

                    return FutureBuilder<void>(
                      future: _hydrate(bookings),
                      builder: (context, hydrateSnap) {
                        if (hydrateSnap.connectionState != ConnectionState.done && bookings.isNotEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: LoadingIndicator(message: 'Loading booking details…'),
                          );
                        }

                        final counts = _counts(bookings);
                        final visible = _visible(bookings);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'My bookings',
                              style: GoogleFonts.inter(
                                fontSize: MobileLayout.isNativeApp(context) ? 24 : 32,
                                fontWeight: FontWeight.w700,
                                color: FigmaColors.gray900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Track your scheduled, active, and completed services.',
                              style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45),
                            ),
                            const SizedBox(height: 24),
                            _SummaryCardsRow(counts: counts),
                            const SizedBox(height: 28),
                            LayoutBuilder(
                              builder: (context, c) {
                                final twoColumn = c.maxWidth >= _twoColumnMinWidth;
                                final main = _BookingsMainColumn(
                                  filter: _filter,
                                  sort: _sort,
                                  searchController: _searchController,
                                  visible: visible,
                                  totalForFilter: bookings.where((b) => _matchesFilter(b, _filter)).length,
                                  services: _services,
                                  providers: _providers,
                                  profiles: _profiles,
                                  onFilter: (f) => setState(() => _filter = f),
                                  onSort: (s) => setState(() => _sort = s),
                                  onSearch: () => setState(() => _query = _searchController.text.trim().toLowerCase()),
                                  onOpenDetail: _openDetail,
                                  onMessage: _messageProvider,
                                );
                                final sidebar = _BookingsSidebar(
                                  counts: counts,
                                  onSupport: () => HelpSupportPopover.show(context, roleLabel: 'Customer'),
                                  onViewHistory: () => setState(() => _filter = _BookingFilter.completed),
                                );

                                if (twoColumn) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: main),
                                      const SizedBox(width: _columnGap),
                                      SizedBox(width: _sidebarWidth, child: sidebar),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    main,
                                    const SizedBox(height: 28),
                                    sidebar,
                                  ],
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const CachedAppFooter.customer(),
          ],
        ),
      ),
    );
  }
}

enum _BookingBucket { upcoming, inProgress, completed, cancelled }

// --- Demo data (UI preview when Firestore has no bookings) ---

List<Booking> _demoBookings(String customerId) {
  final now = DateTime.now();
  Booking mk({
    required String id,
    required String status,
    required DateTime when,
    required String location,
    required String serviceId,
    double? fee,
  }) {
    return Booking(
      bookingId: id,
      customerId: customerId,
      providerId: 'demo-provider',
      serviceId: serviceId,
      serviceLocation: location,
      location: const GeoPoint(7.3083, 125.6842),
      scheduledDate: Timestamp.fromDate(when),
      status: status,
      totalFee: fee,
      createdAt: Timestamp.fromDate(now.subtract(const Duration(days: 2))),
      updatedAt: Timestamp.now(),
    );
  }

  return [
    mk(id: 'demo-1', status: 'Completed', when: now.subtract(const Duration(days: 3)), location: 'Isabela Homes, Panabo City', serviceId: 'demo-dog', fee: 200),
    mk(id: 'demo-2', status: 'Completed', when: now.subtract(const Duration(days: 10)), location: 'Gredu, Panabo City', serviceId: 'demo-clean', fee: 400),
    mk(id: 'demo-3', status: 'In Progress', when: now.add(const Duration(hours: 4)), location: 'San Francisco, Panabo City', serviceId: 'demo-moving', fee: 600),
    mk(id: 'demo-4', status: 'Pending', when: now.add(const Duration(days: 2)), location: 'New Pandan, Panabo City', serviceId: 'demo-tutor', fee: 350),
    mk(id: 'demo-5', status: 'Accepted', when: now.add(const Duration(days: 5)), location: 'J.P. Laurel, Panabo City', serviceId: 'demo-clean2', fee: 450),
    mk(id: 'demo-6', status: 'Cancelled', when: now.subtract(const Duration(days: 1)), location: 'Gredu, Panabo City', serviceId: 'demo-repair', fee: 500),
  ];
}

/// Hydration fallbacks for demo rows.
ServiceListing? _demoService(String serviceId) {
  return switch (serviceId) {
    'demo-dog' => ServiceListing(
      serviceId: serviceId,
      providerId: 'demo',
      serviceTitle: 'Dog Walking',
      category: 'Pet Care',
      description: '',
      estimatedPrice: 200,
      priceType: 'fixed',
      estimatedDuration: '1 hr',
      availability: {},
      serviceImages: [MarketingServiceImages.urlFor(serviceName: 'Dog Walking', categoryId: 'pet_care')],
      isActive: true,
      approvalStatus: ServiceApprovalStatus.approved,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    ),
    'demo-clean' || 'demo-clean2' => ServiceListing(
      serviceId: serviceId,
      providerId: 'demo',
      serviceTitle: 'House Cleaning',
      category: 'Cleaning',
      description: '',
      estimatedPrice: 400,
      priceType: 'fixed',
      estimatedDuration: '2 hrs',
      availability: {},
      serviceImages: [MarketingServiceImages.urlFor(serviceName: 'House Cleaning', categoryId: 'cleaning')],
      isActive: true,
      approvalStatus: ServiceApprovalStatus.approved,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    ),
    'demo-moving' => ServiceListing(
      serviceId: serviceId,
      providerId: 'demo',
      serviceTitle: 'Moving Help',
      category: 'Moving and Errands',
      description: '',
      estimatedPrice: 600,
      priceType: 'fixed',
      estimatedDuration: '3 hrs',
      availability: {},
      serviceImages: [MarketingServiceImages.urlFor(serviceName: 'Moving Help', categoryId: 'moving_errands')],
      isActive: true,
      approvalStatus: ServiceApprovalStatus.approved,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    ),
    'demo-tutor' => ServiceListing(
      serviceId: serviceId,
      providerId: 'demo',
      serviceTitle: 'Math Tutoring',
      category: 'Tutoring and Lessons',
      description: '',
      estimatedPrice: 350,
      priceType: 'hourly',
      estimatedDuration: '1 hr',
      availability: {},
      serviceImages: [MarketingServiceImages.urlFor(serviceName: 'Math Tutoring', categoryId: 'tutoring')],
      isActive: true,
      approvalStatus: ServiceApprovalStatus.approved,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    ),
    'demo-repair' => ServiceListing(
      serviceId: serviceId,
      providerId: 'demo',
      serviceTitle: 'Home Repairs',
      category: 'Handyman',
      description: '',
      estimatedPrice: 500,
      priceType: 'fixed',
      estimatedDuration: '2 hrs',
      availability: {},
      serviceImages: [MarketingServiceImages.urlFor(serviceName: 'Home Repairs', categoryId: 'handyman')],
      isActive: true,
      approvalStatus: ServiceApprovalStatus.approved,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    ),
    _ => null,
  };
}

AppUser _demoProvider() => AppUser(
      userId: 'demo-provider',
      email: 'kent@demo.local',
      fullName: 'Kent Ivan M.',
      role: UserRole.provider,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=100&q=80',
      location: const GeoPoint(7.3083, 125.6842),
      accountStatus: AccountStatus.active,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

ServiceProviderProfile _demoProfile() => ServiceProviderProfile(
      providerId: 'demo-provider',
      userId: 'demo-provider',
      bio: '',
      serviceArea: 'Panabo City',
      location: const GeoPoint(7.3083, 125.6842),
      serviceRadiusKm: 10,
      averageRating: 5.0,
      completedBookings: 12,
      acceptedBookings: 12,
      isVerified: true,
      verificationStatus: 'approved',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

// --- Summary cards ---

class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({required this.counts});

  final Map<_BookingBucket, int> counts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 640;
        final children = [
          _SummaryCard(
            label: 'Upcoming',
            count: counts[_BookingBucket.upcoming] ?? 0,
            icon: Icons.event_outlined,
            iconBg: FigmaColors.tintGreen,
            iconFg: FigmaColors.green,
          ),
          _SummaryCard(
            label: 'In Progress',
            count: counts[_BookingBucket.inProgress] ?? 0,
            icon: Icons.timelapse_outlined,
            iconBg: FigmaColors.yellow50,
            iconFg: const Color(0xFFCA8A04),
          ),
          _SummaryCard(
            label: 'Completed',
            count: counts[_BookingBucket.completed] ?? 0,
            icon: Icons.check_circle_outline,
            iconBg: const Color(0xFFDCFCE7),
            iconFg: const Color(0xFF15803D),
          ),
          _SummaryCard(
            label: 'Cancelled',
            count: counts[_BookingBucket.cancelled] ?? 0,
            icon: Icons.cancel_outlined,
            iconBg: FigmaColors.red50,
            iconFg: FigmaColors.red600,
          ),
        ];
        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconFg, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count.toString(), style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
              Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Main column ---

class _BookingsMainColumn extends StatelessWidget {
  const _BookingsMainColumn({
    required this.filter,
    required this.sort,
    required this.searchController,
    required this.visible,
    required this.totalForFilter,
    required this.services,
    required this.providers,
    required this.profiles,
    required this.onFilter,
    required this.onSort,
    required this.onSearch,
    required this.onOpenDetail,
    required this.onMessage,
  });

  final _BookingFilter filter;
  final _BookingSort sort;
  final TextEditingController searchController;
  final List<Booking> visible;
  final int totalForFilter;
  final Map<String, ServiceListing?> services;
  final Map<String, AppUser?> providers;
  final Map<String, ServiceProviderProfile?> profiles;
  final ValueChanged<_BookingFilter> onFilter;
  final ValueChanged<_BookingSort> onSort;
  final VoidCallback onSearch;
  final void Function(Booking) onOpenDetail;
  final void Function(Booking) onMessage;

  @override
  Widget build(BuildContext context) {
    final nativeMobile = MobileLayout.isNativeApp(context);
    final searchField = AppSearchField(
      controller: searchController,
      hint: nativeMobile ? 'Search bookings…' : 'Search by booking ID, service, or provider',
      onSubmitted: (_) => onSearch(),
      onChanged: (_) => onSearch(),
    );
    final sortControl = _BookingSortDropdown(sort: sort, onSort: onSort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BookingFilterChips(selected: filter, onSelected: onFilter),
        const SizedBox(height: 16),
        if (nativeMobile) ...[
          searchField,
          const SizedBox(height: 10),
          sortControl,
        ] else
          Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              sortControl,
            ],
          ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          const FigmaEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No bookings here',
            message: 'Try another tab or search term.',
          )
        else
          Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _BookingListCard(
                  booking: visible[i],
                  service: services[visible[i].serviceId] ?? _demoService(visible[i].serviceId),
                  provider: providers[visible[i].providerId] ?? (visible[i].bookingId.startsWith('demo-') ? _demoProvider() : null),
                  profile: profiles[visible[i].providerId] ?? (visible[i].bookingId.startsWith('demo-') ? _demoProfile() : null),
                  onOpenDetail: () => onOpenDetail(visible[i]),
                  onMessage: () => onMessage(visible[i]),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _BookingFilterChips extends StatelessWidget {
  const _BookingFilterChips({required this.selected, required this.onSelected});

  final _BookingFilter selected;
  final ValueChanged<_BookingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    Widget chip(String label, _BookingFilter f) {
      final active = selected == f;
      return Material(
        color: active ? rc.tint : FigmaColors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onSelected(f),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? rc.primary.withValues(alpha: 0.4) : FigmaColors.gray200),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? rc.primary : FigmaColors.gray700,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('All', _BookingFilter.all),
        chip('Upcoming', _BookingFilter.upcoming),
        chip('In Progress', _BookingFilter.inProgress),
        chip('Completed', _BookingFilter.completed),
        chip('Cancelled', _BookingFilter.cancelled),
      ],
    );
  }
}

class _BookingSortDropdown extends StatelessWidget {
  const _BookingSortDropdown({required this.sort, required this.onSort});

  final _BookingSort sort;
  final ValueChanged<_BookingSort> onSort;

  String get _label => switch (sort) {
        _BookingSort.latest => 'Latest',
        _BookingSort.oldest => 'Oldest',
        _BookingSort.serviceName => 'Service name',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BookingSort>(
      onSelected: onSort,
      offset: const Offset(0, 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FigmaColors.gray200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort by: ', style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600)),
            Text(_label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900)),
            const Icon(Icons.keyboard_arrow_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: _BookingSort.latest, child: Text('Latest')),
        PopupMenuItem(value: _BookingSort.oldest, child: Text('Oldest')),
        PopupMenuItem(value: _BookingSort.serviceName, child: Text('Service name')),
      ],
    );
  }
}

class _BookingListCard extends StatelessWidget {
  const _BookingListCard({
    required this.booking,
    required this.service,
    required this.provider,
    required this.profile,
    required this.onOpenDetail,
    required this.onMessage,
  });

  final Booking booking;
  final ServiceListing? service;
  final AppUser? provider;
  final ServiceProviderProfile? profile;
  final VoidCallback onOpenDetail;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final nativeMobile = MobileLayout.isNativeApp(context);
    final title = service?.serviceTitle ?? 'Service';
    final category = service?.category ?? 'Service';
    final imageUrl = service != null && service!.serviceImages.isNotEmpty
        ? service!.serviceImages.first
        : MarketingServiceImages.urlFor(serviceName: title, categoryName: category);
    final providerName = provider?.fullName.isNotEmpty == true ? provider!.fullName : 'Provider';
    final rating = profile?.averageRating ?? 0;
    final reviewCount = profile?.reviewCount ?? 0;
    final fee = booking.totalFee ?? service?.estimatedPrice;
    final showRating = booking.isMilestoneComplete && rating > 0;
    final thumbSize = nativeMobile ? 72.0 : 88.0;
    final location = booking.serviceLocation.isNotEmpty ? booking.serviceLocation : 'Location not set';

    Widget providerRow({required bool stackCategory}) {
      return Row(
        children: [
          CircleAvatar(
            radius: nativeMobile ? 13 : 14,
            backgroundImage: provider?.profilePhotoUrl != null ? NetworkImage(provider!.profilePhotoUrl!) : null,
            child: provider?.profilePhotoUrl == null
                ? Text(providerName[0].toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: FigmaColors.gray900),
                ),
                if (stackCategory) ...[
                  const SizedBox(height: 4),
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                  ),
                ],
              ],
            ),
          ),
          if (!stackCategory) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FigmaColors.gray100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                ),
              ),
            ),
          ],
        ],
      );
    }

    Widget statusAndPrice() {
      return Row(
        children: [
          FigmaStatusChip(status: _displayStatus(booking.status)),
          if (fee != null) ...[
            const Spacer(),
            Text(
              '₱${fee.toStringAsFixed(0)}',
              style: GoogleFonts.inter(fontSize: nativeMobile ? 15 : 16, fontWeight: FontWeight.w700, color: rc.primary),
            ),
          ],
        ],
      );
    }

    Widget thumbColumn() {
      return SizedBox(
        width: thumbSize,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
              ),
            ),
            if (showRating) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      '${rating.toStringAsFixed(1)} ($reviewCount)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget actions() {
      final messageBtn = TextButton.icon(
        onPressed: onMessage,
        icon: Icon(Icons.chat_bubble_outline, size: 18, color: rc.primary),
        label: Text('Message Provider', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary)),
      );
      final detailsBtn = OutlinedButton.icon(
        onPressed: onOpenDetail,
        icon: const Icon(Icons.chevron_right_rounded, size: 18),
        label: Text('View Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: FigmaColors.gray800,
          side: const BorderSide(color: FigmaColors.gray300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      if (nativeMobile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: double.infinity, child: messageBtn),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: detailsBtn),
          ],
        );
      }

      return Row(
        children: [
          Flexible(child: messageBtn),
          const SizedBox(width: 8),
          detailsBtn,
        ],
      );
    }

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              thumbColumn(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking #${_shortId(booking.bookingId)}',
                      style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: nativeMobile ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.gray900,
                      ),
                    ),
                    if (nativeMobile) ...[
                      const SizedBox(height: 8),
                      statusAndPrice(),
                      const SizedBox(height: 6),
                    ] else
                      const SizedBox(height: 6),
                    Text(
                      booking.scheduledWindowLabel,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: FigmaColors.gray500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    providerRow(stackCategory: nativeMobile),
                  ],
                ),
              ),
              if (!nativeMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FigmaStatusChip(status: _displayStatus(booking.status)),
                    if (fee != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '₱${fee.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: rc.primary),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: FigmaColors.gray200),
          const SizedBox(height: 12),
          actions(),
        ],
      ),
    );
  }
}

String _shortId(String id) => id.length <= 8 ? id : id.replaceFirst('demo-', '').substring(0, 6).toUpperCase();

String _displayStatus(String status) {
  final s = status.toLowerCase();
  if (s == 'completed') return 'Completed';
  if (s == 'cancelled' || s == 'canceled') return 'Cancelled';
  if (s == 'in progress') return 'In Progress';
  if (s == 'pending' || s == 'accepted') return 'Upcoming';
  return status;
}

// --- Sidebar ---

class _BookingsSidebar extends StatelessWidget {
  const _BookingsSidebar({
    required this.counts,
    this.onSupport,
    this.onViewHistory,
  });

  final Map<_BookingBucket, int> counts;
  final VoidCallback? onSupport;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Booking overview', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: _BookingOverviewChart(counts: counts),
              ),
              const SizedBox(height: 12),
              _ChartLegend(counts: counts),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onViewHistory,
                  child: Text('View full history', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.support_agent_outlined, color: rc.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Need help?', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Questions about a booking? Our team can help you and your provider.',
                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.45),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSupport,
                  style: FilledButton.styleFrom(
                    backgroundColor: rc.primary,
                    foregroundColor: rc.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Contact Support', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingOverviewChart extends StatelessWidget {
  const _BookingOverviewChart({required this.counts});

  final Map<_BookingBucket, int> counts;

  @override
  Widget build(BuildContext context) {
    final total = (_BookingBucket.values.map((b) => counts[b] ?? 0).fold<int>(0, (a, b) => a + b));
    if (total == 0) {
      return Center(child: Text('No data yet', style: GoogleFonts.inter(color: FigmaColors.gray500)));
    }

    final sections = <PieChartSectionData>[
      if ((counts[_BookingBucket.completed] ?? 0) > 0)
        PieChartSectionData(
          value: (counts[_BookingBucket.completed] ?? 0).toDouble(),
          color: FigmaColors.green,
          radius: 36,
          showTitle: false,
        ),
      if ((counts[_BookingBucket.upcoming] ?? 0) > 0)
        PieChartSectionData(
          value: (counts[_BookingBucket.upcoming] ?? 0).toDouble(),
          color: const Color(0xFF3B82F6),
          radius: 36,
          showTitle: false,
        ),
      if ((counts[_BookingBucket.inProgress] ?? 0) > 0)
        PieChartSectionData(
          value: (counts[_BookingBucket.inProgress] ?? 0).toDouble(),
          color: FigmaColors.yellow500,
          radius: 36,
          showTitle: false,
        ),
      if ((counts[_BookingBucket.cancelled] ?? 0) > 0)
        PieChartSectionData(
          value: (counts[_BookingBucket.cancelled] ?? 0).toDouble(),
          color: FigmaColors.red600,
          radius: 36,
          showTitle: false,
        ),
    ];

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 3,
        centerSpaceRadius: 48,
        startDegreeOffset: -90,
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.counts});

  final Map<_BookingBucket, int> counts;

  @override
  Widget build(BuildContext context) {
    Widget row(Color color, String label, int n) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray700))),
            Text('$n', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      children: [
        row(FigmaColors.green, 'Completed', counts[_BookingBucket.completed] ?? 0),
        row(const Color(0xFF3B82F6), 'Upcoming', counts[_BookingBucket.upcoming] ?? 0),
        row(FigmaColors.yellow500, 'In Progress', counts[_BookingBucket.inProgress] ?? 0),
        row(FigmaColors.red600, 'Cancelled', counts[_BookingBucket.cancelled] ?? 0),
      ],
    );
  }
}
