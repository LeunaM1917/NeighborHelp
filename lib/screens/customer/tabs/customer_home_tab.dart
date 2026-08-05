import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/marketing_category_dialogs.dart';
import '../../../figma_ui/marketing_service_catalog.dart';
import '../../../figma_ui/marketing_service_images.dart';
import '../../../theme/role_theme.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../theme/mobile_layout.dart';
import '../../../figma_ui/widgets/figma_empty_state.dart';
import '../../../figma_ui/widgets/figma_network_image.dart';
import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../models/provider.dart';
import '../../../models/review.dart';
import '../../../models/service.dart';
import '../../../services/firestore_service.dart';
import '../../../ui/app_ui_kit.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stream_snapshot.dart';
import '../../../widgets/app_footer.dart';
import '../../../services/provider_recommendation_service.dart';
import '../../../widgets/provider_proximity_label.dart';
import '../../../widgets/your_area_map.dart';
import '../../../utils/listing_rating.dart';
import '../../../utils/review_sentiment.dart';
import '../../../widgets/customer_provider_profile_dialog.dart';
import '../customer_providers_list_screen.dart';
import '../customer_service_detail_screen.dart';
import '../widgets/your_requests_section.dart';

/// Provider ids this customer has already hired (accepted / in progress / completed).
Set<String> _hiredProviderIdsFromBookings(List<Booking> bookings) {
  final ids = <String>{};
  for (final b in bookings) {
    if (b.isCancelled || b.isPending) continue;
    if (b.isAccepted || b.isInProgress || b.isMilestoneComplete) {
      final id = b.providerId.trim();
      if (id.isNotEmpty) ids.add(id);
    }
  }
  return ids;
}

bool _providerWasHired(ServiceProviderProfile profile, Set<String> hiredIds) {
  return hiredIds.contains(profile.providerId) || hiredIds.contains(profile.userId);
}

/// Demo cards for the home "Available Services" carousel (UI preview).
const _demoHomeServices = [
  _DemoHomeService(
    title: 'House Cleaning',
    category: 'Cleaning',
    categoryId: 'cleaning',
    providerName: 'Maria Santos',
    rating: 4.9,
    reviews: 18,
    pricePhp: 400,
    providerInitial: 'M',
    providerAvatarColor: Color(0xFF16A34A),
  ),
  _DemoHomeService(
    title: 'Aircon Cleaning',
    category: 'Repair and Technical Services',
    categoryId: 'repair_technical',
    providerName: 'Kent Repair Services',
    rating: 5.0,
    reviews: 20,
    pricePhp: 350,
    providerPhotoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=100&q=80',
  ),
  _DemoHomeService(
    title: 'Laundry Assistance',
    category: 'Cleaning',
    categoryId: 'cleaning',
    providerName: 'Care Assist PH',
    rating: 4.8,
    reviews: 14,
    pricePhp: 240,
    providerInitial: 'C',
    providerAvatarColor: Color(0xFF16A34A),
  ),
  _DemoHomeService(
    title: 'Moving Help',
    category: 'Moving and Errands',
    categoryId: 'moving_errands',
    providerName: 'Juan Dela Cruz',
    rating: 4.8,
    reviews: 15,
    pricePhp: 600,
    providerInitial: 'J',
    providerAvatarColor: Color(0xFF86EFAC),
  ),
  _DemoHomeService(
    title: 'Math Tutoring',
    category: 'Tutoring and Lessons',
    categoryId: 'tutoring',
    providerName: 'Teacher Ana',
    rating: 5.0,
    reviews: 9,
    pricePhp: 350,
    providerPhotoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
  ),
];

class _DemoHomeService {
  const _DemoHomeService({
    required this.title,
    required this.category,
    required this.categoryId,
    required this.providerName,
    required this.rating,
    required this.reviews,
    required this.pricePhp,
    this.providerPhotoUrl,
    this.providerInitial,
    this.providerAvatarColor,
  });

  final String title;
  final String category;
  final String categoryId;
  final String providerName;
  final double rating;
  final int reviews;
  final int pricePhp;
  final String? providerPhotoUrl;
  final String? providerInitial;
  final Color? providerAvatarColor;

  String get imageUrl => MarketingServiceImages.urlFor(
        serviceName: title,
        categoryId: categoryId,
      );
}

/// Display model for live + demo carousel entries.
class _CarouselServiceDisplay {
  const _CarouselServiceDisplay({
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.providerName,
    required this.price,
    required this.rating,
    required this.reviews,
    this.providerPhotoUrl,
    this.providerInitial,
    this.providerAvatarColor,
    this.listing,
    this.isDemo = false,
    this.profileAverage = 0,
    this.profileReviewCount = 0,
  });

  final String title;
  final String category;
  final String imageUrl;
  final String providerName;
  final double price;
  final double rating;
  final int reviews;
  final String? providerPhotoUrl;
  final String? providerInitial;
  final Color? providerAvatarColor;
  final ServiceListing? listing;
  final bool isDemo;
  final double profileAverage;
  final int profileReviewCount;

  factory _CarouselServiceDisplay.fromListing({
    required ServiceListing listing,
    required String providerName,
    String? providerPhotoUrl,
    double? rating,
    int? reviewCount,
    double profileAverage = 0,
    int profileReviewCount = 0,
  }) {
    final imageUrl = listing.serviceImages.isNotEmpty
        ? listing.serviceImages.first
        : MarketingServiceImages.urlFor(
            serviceName: listing.serviceTitle,
            categoryName: listing.category,
          );
    return _CarouselServiceDisplay(
      title: listing.serviceTitle,
      category: listing.category,
      imageUrl: imageUrl,
      providerName: providerName,
      price: listing.estimatedPrice,
      rating: rating ?? 0,
      reviews: reviewCount ?? 0,
      providerPhotoUrl: providerPhotoUrl,
      listing: listing,
      profileAverage: profileAverage,
      profileReviewCount: profileReviewCount,
    );
  }

  factory _CarouselServiceDisplay.fromDemo(_DemoHomeService demo) {
    return _CarouselServiceDisplay(
      title: demo.title,
      category: demo.category,
      imageUrl: demo.imageUrl,
      providerName: demo.providerName,
      price: demo.pricePhp.toDouble(),
      rating: demo.rating,
      reviews: demo.reviews,
      providerPhotoUrl: demo.providerPhotoUrl,
      providerInitial: demo.providerInitial,
      providerAvatarColor: demo.providerAvatarColor,
      isDemo: true,
    );
  }
}

List<_CarouselServiceDisplay> _buildHomeCarouselServices({
  required List<ServiceListing> live,
  required List<ServiceProviderProfile> profiles,
  required Map<String, AppUser> users,
}) {
  ServiceProviderProfile? profileFor(ServiceListing listing) {
    for (final p in profiles) {
      if (p.providerId == listing.providerId || p.userId == listing.providerId) {
        return p;
      }
    }
    return null;
  }

  AppUser? userFor(ServiceListing listing) {
    final profile = profileFor(listing);
    if (profile != null) return users[profile.userId];
    return users[listing.providerId];
  }

  final items = <_CarouselServiceDisplay>[];
  final usedTitles = <String>{};

  for (final listing in live) {
    final profile = profileFor(listing);
    final user = userFor(listing);
    items.add(
      _CarouselServiceDisplay.fromListing(
        listing: listing,
        providerName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Local provider',
        providerPhotoUrl: user?.profilePhotoUrl,
        // Live service-scoped rating is resolved in the card (not Bayesian profile avg).
        rating: 0,
        reviewCount: 0,
        profileAverage: profile?.averageRating ?? 0,
        profileReviewCount: profile?.reviewCount ?? 0,
      ),
    );
    usedTitles.add(listing.serviceTitle.trim().toLowerCase());
  }

  for (final demo in _demoHomeServices) {
    if (usedTitles.contains(demo.title.trim().toLowerCase())) continue;
    items.add(_CarouselServiceDisplay.fromDemo(demo));
    usedTitles.add(demo.title.trim().toLowerCase());
  }

  return items;
}

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({
    super.key,
    required this.appUser,
    this.scrollController,
    this.onBrowseTap,
    this.onBookingsTap,
  });

  final AppUser appUser;
  final ScrollController? scrollController;
  final VoidCallback? onBrowseTap;
  final VoidCallback? onBookingsTap;

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  bool _serviceMode = true;
  final _searchController = TextEditingController();

  static const _sidebarWidth = 400.0;
  static const _columnGap = 32.0;
  static const _twoColumnMinWidth = 960.0;

  /// Top inset so the sidebar lines up with the white search card inside the green hero.
  static const _sidebarTopInset = 124.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

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
                child: LayoutBuilder(
                  builder: (context, c) {
                    final twoColumn = c.maxWidth >= _twoColumnMinWidth;
                    final nativeMobile = MobileLayout.isNativeApp(context);
                    final main = _HomeMainColumn(
                      appUser: widget.appUser,
                      serviceMode: _serviceMode,
                      searchController: _searchController,
                      onModeChanged: (v) => setState(() => _serviceMode = v),
                      onBrowse: widget.onBrowseTap,
                      onBookings: widget.onBookingsTap,
                      onSearchProviders: () => _openProvidersList(context),
                      firestore: firestore,
                      showNearbyBelowMap: nativeMobile && !twoColumn,
                    );
                    final sidebar = _HomeSidebarColumn(
                      appUser: widget.appUser,
                      firestore: firestore,
                      alignWithSearch: twoColumn,
                      showNearbyCard: !nativeMobile || twoColumn,
                    );
                    final services = _AvailableServicesCarousel(
                      firestore: firestore,
                      onOpenService: (listing) => _openService(context, listing),
                      onViewAll: widget.onBrowseTap,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (twoColumn) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: main),
                              const SizedBox(width: _columnGap),
                              SizedBox(width: _sidebarWidth, child: sidebar),
                            ],
                          ),
                          const SizedBox(height: 32),
                          services,
                        ] else ...[
                          main,
                          const SizedBox(height: 32),
                          services,
                          const SizedBox(height: 24),
                          sidebar,
                        ],
                      ],
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

  void _openProvidersList(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerProvidersListScreen(
          appUser: widget.appUser,
          initialQuery: _searchController.text,
        ),
      ),
    );
  }

  void _openService(BuildContext context, ServiceListing listing) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerServiceDetailScreen(
          appUser: widget.appUser,
          listing: listing,
        ),
      ),
    );
  }
}

/// Left column: hero, map, categories, and your requests (wide layouts pair with sidebar).
class _HomeMainColumn extends StatelessWidget {
  const _HomeMainColumn({
    required this.appUser,
    required this.serviceMode,
    required this.searchController,
    required this.onModeChanged,
    this.onBrowse,
    this.onBookings,
    required this.onSearchProviders,
    required this.firestore,
    this.showNearbyBelowMap = false,
  });

  final AppUser appUser;
  final bool serviceMode;
  final TextEditingController searchController;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onBrowse;
  final VoidCallback? onBookings;
  final VoidCallback onSearchProviders;
  final FirestoreService firestore;
  final bool showNearbyBelowMap;

  @override
  Widget build(BuildContext context) {
    final nativeMobile = MobileLayout.isNativeApp(context);
    final mapHeight = nativeMobile ? 280.0 : 450.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CustomerHomeSearchHero(
          serviceMode: serviceMode,
          searchController: searchController,
          onModeChanged: onModeChanged,
          onBrowse: onBrowse,
          onSearchProviders: onSearchProviders,
        ),
        const SizedBox(height: 28),
        YourAreaMapCard(appUser: appUser, height: mapHeight),
        if (showNearbyBelowMap) ...[
          const SizedBox(height: 20),
          _NearbyProvidersCard(appUser: appUser, firestore: firestore),
        ],
        const SizedBox(height: 28),
        _PopularCategoriesSection(appUser: appUser, onViewAll: onBrowse),
        const SizedBox(height: 32),
        YourRequestsSection(appUser: appUser, onViewAll: onBookings),
      ],
    );
  }
}

/// Green hero block with neighborhood illustration, headline, search, and trust row.
class _CustomerHomeSearchHero extends StatelessWidget {
  const _CustomerHomeSearchHero({
    required this.serviceMode,
    required this.searchController,
    required this.onModeChanged,
    this.onBrowse,
    this.onSearchProviders,
  });

  final bool serviceMode;
  final TextEditingController searchController;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onBrowse;
  final VoidCallback? onSearchProviders;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final nativeMobile = MobileLayout.isNativeApp(context);
    final heroPadding = nativeMobile ? const EdgeInsets.fromLTRB(16, 20, 16, 20) : const EdgeInsets.fromLTRB(28, 28, 28, 24);
    final headlineSize = nativeMobile ? 26.0 : 34.0;
    final subheadSize = nativeMobile ? 14.0 : 16.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [rc.tint, FigmaColors.tintGreen2.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ),
          Positioned(
            right: -12,
            bottom: -8,
            width: 320,
            height: 200,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55,
                child: CustomPaint(
                  painter: _SuburbanHousesPainter(accent: rc.primary),
                  size: const Size(320, 200),
                ),
              ),
            ),
          ),
          Padding(
            padding: heroPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find trusted local services',
                  style: GoogleFonts.inter(fontSize: headlineSize, fontWeight: FontWeight.w700, color: FigmaColors.gray900, height: 1.15),
                ),
                const SizedBox(height: 6),
                Text(
                  'from verified providers in your community.',
                  style: GoogleFonts.inter(fontSize: subheadSize, color: FigmaColors.gray600, height: 1.45),
                ),
                const SizedBox(height: 24),
                _SearchPanel(
                  serviceMode: serviceMode,
                  controller: searchController,
                  onModeChanged: onModeChanged,
                  onBrowse: onBrowse,
                  onSearchProviders: onSearchProviders,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _trustChip(Icons.verified_outlined, 'Verified & trusted providers'),
                    _trustChip(Icons.lock_outline, 'Secure bookings'),
                    _trustChip(Icons.groups_outlined, 'Support your community'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _trustChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: FigmaColors.green),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700)),
      ],
    );
  }
}

class _SuburbanHousesPainter extends CustomPainter {
  _SuburbanHousesPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final tree = Paint()..color = accent.withValues(alpha: 0.35);
    final house = Paint()..color = FigmaColors.white.withValues(alpha: 0.85);
    final roof = Paint()..color = accent.withValues(alpha: 0.5);

    void drawHouse(double x, double w, double h) {
      final base = Rect.fromLTWH(x, size.height - h, w, h * 0.65);
      canvas.drawRRect(RRect.fromRectAndRadius(base, const Radius.circular(4)), house);
      final path = Path()
        ..moveTo(x - 6, base.top)
        ..lineTo(x + w / 2, base.top - h * 0.35)
        ..lineTo(x + w + 6, base.top)
        ..close();
      canvas.drawPath(path, roof);
    }

    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(40.0 + i * 58, size.height - 28), 14, tree);
    }
    drawHouse(size.width * 0.35, 72, 90);
    drawHouse(size.width * 0.55, 88, 110);
    drawHouse(size.width * 0.72, 64, 80);
  }

  @override
  bool shouldRepaint(covariant _SuburbanHousesPainter oldDelegate) => oldDelegate.accent != accent;
}

class _PopularCategoriesSection extends StatelessWidget {
  const _PopularCategoriesSection({required this.appUser, this.onViewAll});

  final AppUser appUser;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final popular = MarketingServiceCatalog.popularForHome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Popular Categories',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 12.0;
            final nativeMobile = MobileLayout.isNativeApp(context);
            final cardW = (c.maxWidth - gap * 4) / 5;
            final useHorizontalScroll = nativeMobile || cardW < 88;
            if (useHorizontalScroll) {
              return SizedBox(
                height: nativeMobile ? 124 : 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: popular.length,
                  separatorBuilder: (_, __) => const SizedBox(width: gap),
                  itemBuilder: (context, i) {
                    final cat = popular[i];
                    return SizedBox(
                      width: nativeMobile ? 100 : 96,
                      child: _PopularCategoryCard(
                        category: cat,
                        compact: nativeMobile,
                        onTap: () => showMarketingCategoryServices(
                          context,
                          cat,
                          browseContext: MarketingBrowseContext(appUser: appUser),
                        ),
                      ),
                    );
                  },
                ),
              );
            }
            return Row(
              children: [
                for (var i = 0; i < popular.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(
                    child: _PopularCategoryCard(
                      category: popular[i],
                      onTap: () => showMarketingCategoryServices(
                        context,
                        popular[i],
                        browseContext: MarketingBrowseContext(appUser: appUser),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PopularCategoryCard extends StatefulWidget {
  const _PopularCategoryCard({
    required this.category,
    required this.onTap,
    this.compact = false,
  });

  final MarketingServiceCategory category;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_PopularCategoryCard> createState() => _PopularCategoryCardState();
}

class _PopularCategoryCardState extends State<_PopularCategoryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: _hover ? 3 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(
              vertical: widget.compact ? 12 : 16,
              horizontal: widget.compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hover ? context.roleColors.primary : FigmaColors.gray200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: widget.compact ? 40 : 48,
                  height: widget.compact ? 40 : 48,
                  decoration: BoxDecoration(color: widget.category.bg, shape: BoxShape.circle),
                  child: Icon(widget.category.icon, color: widget.category.fg, size: widget.compact ? 20 : 24),
                ),
                SizedBox(height: widget.compact ? 8 : 10),
                Text(
                  widget.category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: widget.compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.gray900,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailableServicesCarousel extends StatefulWidget {
  const _AvailableServicesCarousel({
    required this.firestore,
    required this.onOpenService,
    this.onViewAll,
  });

  final FirestoreService firestore;
  final void Function(ServiceListing listing) onOpenService;
  final VoidCallback? onViewAll;

  @override
  State<_AvailableServicesCarousel> createState() => _AvailableServicesCarouselState();
}

class _AvailableServicesCarouselState extends State<_AvailableServicesCarousel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollNext(double step) {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset + step;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Services',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Book directly from local providers',
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              child: Text(
                'View all services',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ServiceListing>>(
          stream: widget.firestore.activeServicesStream(),
          builder: (context, serviceSnap) {
            if (isStreamWaiting(serviceSnap)) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingIndicator(message: 'Loading services…'),
              );
            }
            if (serviceSnap.hasError) {
              return FigmaEmptyState(
                icon: Icons.error_outline,
                title: 'Could not load services',
                message: serviceSnap.error.toString(),
              );
            }
            final services = serviceSnap.data ?? [];

            return StreamBuilder<List<ServiceProviderProfile>>(
              stream: widget.firestore.serviceProvidersStream(),
              builder: (context, providerSnap) {
                return StreamBuilder<List<AppUser>>(
                  stream: widget.firestore.allUsersStream(),
                  builder: (context, userSnap) {
                    final profiles = providerSnap.data ?? [];
                    final Map<String, AppUser> users = {
                      for (final u in userSnap.data ?? []) u.userId: u,
                    };
                    final items = _buildHomeCarouselServices(
                      live: services,
                      profiles: profiles,
                      users: users,
                    );

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 16.0;
                        const minCardWidth = 200.0;
                        const maxCardWidth = 400.0;
                        const minFillCardWidth = 180.0;
                        const nextReserve = 52.0;
                        const listHeight = 332.0;
                        final count = items.length;

                        if (count == 0) {
                          return const SizedBox.shrink();
                        }

                        final available = constraints.maxWidth;
                        final fillCardWidth = (available - (count - 1) * gap) / count;
                        final useExpandedRow = fillCardWidth >= minFillCardWidth;

                        final cardWidth = useExpandedRow
                            ? fillCardWidth.clamp(minFillCardWidth, maxCardWidth)
                            : (((available - nextReserve) - gap * 2) / 3.2).clamp(minCardWidth, maxCardWidth);

                        void onCardTap(_CarouselServiceDisplay item) {
                          if (item.isDemo || item.listing == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${item.title} is a preview listing.')),
                            );
                            return;
                          }
                          widget.onOpenService(item.listing!);
                        }

                        if (useExpandedRow) {
                          return SizedBox(
                            height: listHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < count; i++) ...[
                                  if (i > 0) const SizedBox(width: gap),
                                  Expanded(
                                    child: _HomeServiceCarouselCard(
                                      item: items[i],
                                      onTap: () => onCardTap(items[i]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              height: listHeight,
                              child: ListView.separated(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(right: nextReserve),
                                itemCount: count,
                                separatorBuilder: (_, __) => const SizedBox(width: gap),
                                itemBuilder: (context, i) {
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _HomeServiceCarouselCard(
                                      item: items[i],
                                      onTap: () => onCardTap(items[i]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: FigmaColors.white,
                                  elevation: 4,
                                  shadowColor: Colors.black.withValues(alpha: 0.12),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    onPressed: () => _scrollNext(cardWidth + gap),
                                    icon: Icon(Icons.chevron_right, color: rc.primary, size: 28),
                                    tooltip: 'Next services',
                                  ),
                                ),
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
        ),
      ],
    );
  }
}

class _HomeServiceCarouselCard extends StatefulWidget {
  const _HomeServiceCarouselCard({
    required this.item,
    required this.onTap,
  });

  final _CarouselServiceDisplay item;
  final VoidCallback onTap;

  @override
  State<_HomeServiceCarouselCard> createState() => _HomeServiceCarouselCardState();
}

class _HomeServiceCarouselCardState extends State<_HomeServiceCarouselCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final item = widget.item;
    final avatarBg = item.providerAvatarColor ?? rc.tint;
    final avatarInitial = item.providerInitial ??
        (item.providerName.isNotEmpty ? item.providerName[0].toUpperCase() : '?');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: _hover ? 4 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hover ? rc.primary : FigmaColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: SizedBox(
                      height: 160,
                      child: FigmaNetworkImage(url: item.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: avatarBg,
                              backgroundImage: item.providerPhotoUrl != null ? NetworkImage(item.providerPhotoUrl!) : null,
                              child: item.providerPhotoUrl == null
                                  ? Text(
                                      avatarInitial,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: item.providerAvatarColor != null ? FigmaColors.white : rc.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.providerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: FigmaColors.gray800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _CarouselRatingLabel(item: item)),
                            Text(
                              '₱${item.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: rc.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

class _CarouselRatingLabel extends StatelessWidget {
  const _CarouselRatingLabel({required this.item});

  final _CarouselServiceDisplay item;

  @override
  Widget build(BuildContext context) {
    final listing = item.listing;
    if (listing == null || item.isDemo) {
      final ratingText = item.rating > 0 ? item.rating.toStringAsFixed(1) : '—';
      return Row(
        children: [
          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$ratingText (${item.reviews})',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final firestore = FirestoreService();
    return StreamBuilder<List<ServiceListing>>(
      stream: firestore.servicesForProvider(listing.providerId),
      builder: (context, servicesSnap) {
        final serviceIds = serviceIdsMatchingListing(
          listing: listing,
          providerListings: servicesSnap.data ?? const <ServiceListing>[],
        );
        return StreamBuilder<List<Review>>(
          stream: firestore.reviewsForProviderStream(listing.providerId),
          builder: (context, reviewSnap) {
            final rating = computeServiceListingRating(
              reviews: reviewSnap.data ?? const <Review>[],
              serviceIds: serviceIds,
              profileAverage: item.profileAverage,
              profileReviewCount: item.profileReviewCount,
            );

            if (rating.hasServiceReviews) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.serviceRating.toStringAsFixed(1)} (${rating.serviceReviewCount})',
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                      ),
                    ],
                  ),
                  if (rating.hasOverallReviews &&
                      rating.overallReviewCount != rating.serviceReviewCount)
                    Text(
                      'Overall ${rating.overallRating.toStringAsFixed(1)}',
                      style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New for this service',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FigmaColors.gray700,
                  ),
                ),
                if (rating.hasOverallReviews)
                  Text(
                    'Overall ${rating.overallRating.toStringAsFixed(1)} (${rating.overallReviewCount})',
                    style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Right column on wide home: nearby providers + quick links.
class _HomeSidebarColumn extends StatelessWidget {
  const _HomeSidebarColumn({
    required this.appUser,
    required this.firestore,
    this.alignWithSearch = false,
    this.showNearbyCard = true,
  });

  final AppUser appUser;
  final FirestoreService firestore;
  final bool alignWithSearch;
  final bool showNearbyCard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: alignWithSearch ? _CustomerHomeTabState._sidebarTopInset : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showNearbyCard) ...[
            _NearbyProvidersCard(appUser: appUser, firestore: firestore),
            const SizedBox(height: 16),
          ],
          const _SidebarInsightCard(
            icon: Icons.verified_user_outlined,
            title: 'Book with confidence',
            body: 'Verified providers, clear pricing, and messaging built in — all in your neighborhood.',
          ),
          const SizedBox(height: 12),
          const _SidebarInsightCard(
            icon: Icons.favorite_outline,
            title: 'Support your neighborhood',
            body: 'Every booking helps local providers grow their business and serve families nearby.',
          ),
          const SizedBox(height: 12),
          const _SidebarInsightCard(
            icon: Icons.support_agent_outlined,
            title: "We're here to help",
            body: 'Questions about a booking? Our support team is ready to help you and your provider.',
          ),
        ],
      ),
    );
  }
}

class _SidebarInsightCard extends StatelessWidget {
  const _SidebarInsightCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 22, color: rc.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyProvidersCard extends StatelessWidget {
  const _NearbyProvidersCard({
    required this.appUser,
    required this.firestore,
  });

  final AppUser appUser;
  final FirestoreService firestore;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.near_me_outlined, size: 22, color: rc.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nearby providers',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerProvidersListScreen(appUser: appUser),
                      ),
                    );
                  },
                  child: Text(
                    'View all',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ranked by recommendation score · past hires appear below',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<ServiceProviderProfile>>(
              stream: firestore.serviceProvidersStream(),
              builder: (context, providerSnap) {
                if (isStreamWaiting(providerSnap)) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: LoadingIndicator(message: 'Loading providers…'),
                  );
                }
                return StreamBuilder<List<AppUser>>(
                  stream: firestore.allUsersStream(),
                  builder: (context, userSnap) {
                    return StreamBuilder<List<Booking>>(
                      stream: firestore.bookingsForUser(appUser.userId, asCustomer: true),
                      builder: (context, bookingSnap) {
                        final Map<String, AppUser> users = {
                          for (final u in userSnap.data ?? []) u.userId: u,
                        };
                        final allProviders = providerSnap.data ?? const <ServiceProviderProfile>[];
                        final hiredIds = _hiredProviderIdsFromBookings(bookingSnap.data ?? const []);

                        final ranked = rankProvidersByRecommendation(
                          providers: allProviders,
                          customerOrigin: appUser.location,
                        );

                        final discovery = <RankedProvider>[];
                        final hired = <RankedProvider>[];
                        for (final r in ranked) {
                          if (_providerWasHired(r.profile, hiredIds)) {
                            hired.add(r);
                          } else {
                            discovery.add(r);
                          }
                        }

                        // Re-number discovery ranks after excluding past hires.
                        final discoveryRanked = [
                          for (var i = 0; i < discovery.length; i++)
                            RankedProvider(
                              profile: discovery[i].profile,
                              recommendationScore: discovery[i].recommendationScore,
                              distanceKm: discovery[i].distanceKm,
                              rank: i + 1,
                              isAvailable: discovery[i].isAvailable,
                              isNewProvider: discovery[i].isNewProvider,
                            ),
                        ];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NearbyProvidersList(
                              appUser: appUser,
                              ranked: discoveryRanked,
                              users: users,
                              customer: appUser,
                            ),
                            if (hired.isNotEmpty) ...[
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Icon(Icons.history, size: 20, color: rc.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Hired before',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: FigmaColors.gray900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Providers you have booked before',
                                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                              ),
                              const SizedBox(height: 16),
                              _HiredBeforeProvidersList(
                                appUser: appUser,
                                ranked: hired,
                                users: users,
                                customer: appUser,
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
    );
  }

}

class _NearbyProvidersList extends StatefulWidget {
  const _NearbyProvidersList({
    required this.appUser,
    required this.ranked,
    required this.users,
    required this.customer,
  });

  final AppUser appUser;
  final List<RankedProvider> ranked;
  final Map<String, AppUser> users;
  final AppUser customer;

  @override
  State<_NearbyProvidersList> createState() => _NearbyProvidersListState();
}

class _NearbyProvidersListState extends State<_NearbyProvidersList> {
  Map<String, String>? _proximityLabels;
  bool _loadingLabels = true;

  List<ServiceProviderProfile> get _topProfiles =>
      widget.ranked.take(5).map((r) => r.profile).toList();

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void didUpdateWidget(covariant _NearbyProvidersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ranked != widget.ranked ||
        oldWidget.customer.location != widget.customer.location) {
      _loadLabels();
    }
  }

  Future<void> _loadLabels() async {
    setState(() => _loadingLabels = true);
    final labels = await resolveProviderProximityLabels(
      customer: widget.customer,
      profiles: _topProfiles,
    );
    if (!mounted) return;
    setState(() {
      _proximityLabels = labels;
      _loadingLabels = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final ranked in widget.ranked.take(5)) {
      final p = ranked.profile;
      final user = widget.users[p.userId];
      final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Provider';
      final subtitle = _loadingLabels ? '…' : (_proximityLabels?[p.providerId] ?? 'Nearby');
      rows.add(
        _NearbyProviderRowLive(
          providerId: p.providerId,
          name: name,
          subtitle: subtitle,
          profileAverage: p.averageRating,
          profileReviewCount: p.reviewCount,
          photoUrl: user?.profilePhotoUrl,
          verified: p.isVerifiedProvider,
          isAvailableNow: ranked.isAvailable,
          isNewProvider: ranked.isNewProvider,
          rank: ranked.rank,
          onTap: () {
            showCustomerProviderProfileDialog(
              context,
              appUser: widget.appUser,
              providerId: p.providerId,
              providerUser: user,
              providerProfile: p,
            );
          },
        ),
      );
    }

    if (rows.isEmpty) {
      return Text(
        'No verified providers in your area yet.',
        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, height: 1.4),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }
}

class _HiredBeforeProvidersList extends StatefulWidget {
  const _HiredBeforeProvidersList({
    required this.appUser,
    required this.ranked,
    required this.users,
    required this.customer,
  });

  final AppUser appUser;
  final List<RankedProvider> ranked;
  final Map<String, AppUser> users;
  final AppUser customer;

  @override
  State<_HiredBeforeProvidersList> createState() => _HiredBeforeProvidersListState();
}

class _HiredBeforeProvidersListState extends State<_HiredBeforeProvidersList> {
  Map<String, String>? _proximityLabels;
  bool _loadingLabels = true;

  List<ServiceProviderProfile> get _profiles =>
      widget.ranked.take(5).map((r) => r.profile).toList();

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void didUpdateWidget(covariant _HiredBeforeProvidersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ranked != widget.ranked ||
        oldWidget.customer.location != widget.customer.location) {
      _loadLabels();
    }
  }

  Future<void> _loadLabels() async {
    setState(() => _loadingLabels = true);
    final labels = await resolveProviderProximityLabels(
      customer: widget.customer,
      profiles: _profiles,
    );
    if (!mounted) return;
    setState(() {
      _proximityLabels = labels;
      _loadingLabels = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final ranked in widget.ranked.take(5)) {
      final p = ranked.profile;
      final user = widget.users[p.userId];
      final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Provider';
      final subtitle = _loadingLabels ? '…' : (_proximityLabels?[p.providerId] ?? 'Nearby');
      rows.add(
        _NearbyProviderRowLive(
          providerId: p.providerId,
          name: name,
          subtitle: subtitle,
          profileAverage: p.averageRating,
          profileReviewCount: p.reviewCount,
          photoUrl: user?.profilePhotoUrl,
          verified: p.isVerifiedProvider,
          isAvailableNow: ranked.isAvailable,
          isNewProvider: ranked.isNewProvider,
          hiredBefore: true,
          onTap: () {
            showCustomerProviderProfileDialog(
              context,
              appUser: widget.appUser,
              providerId: p.providerId,
              providerUser: user,
              providerProfile: p,
            );
          },
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }
}

class _NearbyProviderRowLive extends StatelessWidget {
  const _NearbyProviderRowLive({
    required this.providerId,
    required this.name,
    required this.subtitle,
    required this.profileAverage,
    required this.profileReviewCount,
    required this.onTap,
    this.photoUrl,
    this.verified = false,
    this.isAvailableNow,
    this.isNewProvider,
    this.hiredBefore = false,
    this.rank,
  });

  final String providerId;
  final String name;
  final String subtitle;
  final double profileAverage;
  final int profileReviewCount;
  final String? photoUrl;
  final bool verified;
  final bool? isAvailableNow;
  final bool? isNewProvider;
  final bool hiredBefore;
  final int? rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: FirestoreService().reviewsForProviderStream(providerId),
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        final rating = effectiveProviderRating(profileAverage: profileAverage, reviews: reviews);
        final reviewCount = reviews.isNotEmpty ? reviews.length : profileReviewCount;
        return _NearbyProviderRow(
          name: name,
          subtitle: subtitle,
          rating: rating,
          reviewCount: reviewCount,
          photoUrl: photoUrl,
          verified: verified,
          isAvailableNow: isAvailableNow,
          isNewProvider: isNewProvider,
          hiredBefore: hiredBefore,
          rank: rank,
          onTap: onTap,
        );
      },
    );
  }
}

String _nearbyProviderRatingSubtitle({
  required double rating,
  required int reviewCount,
  required String location,
}) {
  if (reviewCount > 0 && rating > 0) {
    return '★ ${rating.toStringAsFixed(1)} · $location';
  }
  return '★ New · $location';
}

class _NearbyProviderRow extends StatelessWidget {
  const _NearbyProviderRow({
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.onTap,
    this.reviewCount = 0,
    this.photoUrl,
    this.verified = false,
    this.isAvailableNow,
    this.isNewProvider,
    this.hiredBefore = false,
    this.rank,
  });

  final String name;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final String? photoUrl;
  final bool verified;
  final bool? isAvailableNow;
  final bool? isNewProvider;
  final bool hiredBefore;
  final int? rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    return Material(
      color: FigmaColors.gray50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (rank != null && rank! <= 12) ...[
                SizedBox(
                  width: 28,
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rc.primary,
                    ),
                  ),
                ),
              ],
              CircleAvatar(
                radius: 24,
                backgroundColor: rc.tint,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                child: photoUrl == null
                    ? Text(name[0].toUpperCase(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: rc.primary))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 16, color: FigmaColors.green),
                        ],
                        if (hiredBefore) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: rc.tint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Hired before',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: rc.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _nearbyProviderRatingSubtitle(rating: rating, reviewCount: reviewCount, location: subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                    ),
                    if (isNewProvider == true || isAvailableNow != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: rc.primary,
                          ),
                          children: [
                            if (isNewProvider == true)
                              TextSpan(
                                text: 'New',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: rc.primary,
                                ),
                              ),
                            if (isNewProvider == true && isAvailableNow != null)
                              TextSpan(
                                text: ' · ',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: FigmaColors.gray400,
                                ),
                              ),
                            if (isAvailableNow != null)
                              TextSpan(
                                text: isAvailableNow! ? 'Available now' : 'Unavailable',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isAvailableNow! ? FigmaColors.green : FigmaColors.gray500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: FigmaColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.serviceMode,
    required this.controller,
    required this.onModeChanged,
    this.onBrowse,
    this.onSearchProviders,
  });

  final bool serviceMode;
  final TextEditingController controller;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onBrowse;
  final VoidCallback? onSearchProviders;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final nativeMobile = MobileLayout.isNativeApp(context);

    final searchField = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: FigmaColors.gray50, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.search, size: 22, color: FigmaColors.gray400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: serviceMode ? 'What service do you need?' : 'Search providers…',
                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 15),
              ),
              style: GoogleFonts.inter(fontSize: 15, color: FigmaColors.gray900),
            ),
          ),
        ],
      ),
    );

    final searchButton = FilledButton.icon(
      onPressed: serviceMode ? onBrowse : onSearchProviders,
      style: FilledButton.styleFrom(
        backgroundColor: rc.primary,
        foregroundColor: rc.onPrimary,
        padding: EdgeInsets.symmetric(horizontal: nativeMobile ? 16 : 24, vertical: nativeMobile ? 14 : 16),
        minimumSize: nativeMobile ? const Size(double.infinity, 48) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: const Icon(Icons.search, size: 20),
      label: Text('Search', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ModeChip(label: 'Services', selected: serviceMode, onTap: () => onModeChanged(true)),
              const SizedBox(width: 8),
              _ModeChip(label: 'Providers', selected: !serviceMode, onTap: () => onModeChanged(false)),
            ],
          ),
          const SizedBox(height: 10),
          if (nativeMobile) ...[
            searchField,
            const SizedBox(height: 10),
            searchButton,
          ] else
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                searchButton,
              ],
            ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Expanded(
      child: Material(
        color: selected ? rc.primary : FigmaColors.gray100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? rc.onPrimary : FigmaColors.gray700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
