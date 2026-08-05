import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../figma_ui/figma_layout.dart';
import '../../../figma_ui/marketing_category_dialogs.dart';
import '../../../figma_ui/marketing_service_catalog.dart';
import '../../../figma_ui/widgets/figma_empty_state.dart';
import '../../../figma_ui/widgets/figma_network_image.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/geo_location.dart';
import '../../../utils/haversine.dart';
import '../../../theme/role_theme.dart';
import '../../../ui/app_ui_kit.dart';
import '../../../widgets/app_footer.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stream_snapshot.dart';
import '../customer_demo_catalog.dart';
import '../customer_service_detail_screen.dart';

enum _BrowseListFilter { all, topRated, nearest, mostBooked, newest }

enum _BrowseSort { recommended, priceLow, priceHigh, rating }

class CustomerBrowseTab extends StatefulWidget {
  const CustomerBrowseTab({super.key, required this.appUser, this.scrollController});

  final AppUser appUser;
  final ScrollController? scrollController;

  @override
  State<CustomerBrowseTab> createState() => _CustomerBrowseTabState();
}

class _CustomerBrowseTabState extends State<CustomerBrowseTab> {
  final _searchController = TextEditingController();

  String _query = '';
  String? _categoryFilter;
  String _location = 'Panabo City';
  String? _priceFilter;
  String? _ratingFilter;
  String? _availabilityFilter;
  _BrowseListFilter _listFilter = _BrowseListFilter.all;
  _BrowseSort _sort = _BrowseSort.recommended;
  int _page = 0;
  final Set<String> _saved = {};

  static const _pageSize = 12;
  static const _sidebarWidth = 300.0;
  static const _columnGap = 28.0;
  static const _twoColumnMinWidth = 960.0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _straightLineKm(GeoPoint origin, CustomerBrowseServiceItem item) {
    final loc = geoPointOrNull(item.providerLocation);
    if (loc == null) return double.infinity;
    if (isDefaultSignupLocation(loc)) return double.infinity;
    return haversineDistanceKmFromGeoPoints(origin, loc);
  }

  void _applyFilters() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
      _page = 0;
    });
  }

  List<CustomerBrowseServiceItem> _filterAndSort(List<CustomerBrowseServiceItem> items) {
    var list = [...items];

    if (_query.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.title.toLowerCase().contains(_query) ||
                s.category.toLowerCase().contains(_query) ||
                s.providerName.toLowerCase().contains(_query),
          )
          .toList();
    }

    if (_categoryFilter != null) {
      list = list.where((s) => s.categoryId == _categoryFilter).toList();
    }

    switch (_listFilter) {
      case _BrowseListFilter.topRated:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _BrowseListFilter.mostBooked:
        list.sort((a, b) => b.reviews.compareTo(a.reviews));
        break;
      case _BrowseListFilter.newest:
        list.sort((a, b) => b.sortKey.compareTo(a.sortKey));
        break;
      case _BrowseListFilter.nearest:
        final origin = geoPointOrNull(widget.appUser.location);
        if (origin != null) {
          list.sort((a, b) {
            final da = _straightLineKm(origin, a);
            final db = _straightLineKm(origin, b);
            final cmp = da.compareTo(db);
            if (cmp != 0) return cmp;
            return b.rating.compareTo(a.rating);
          });
        }
        break;
      case _BrowseListFilter.all:
        break;
    }

    switch (_sort) {
      case _BrowseSort.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _BrowseSort.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _BrowseSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _BrowseSort.recommended:
        if (_listFilter == _BrowseListFilter.all) {
          list.sort((a, b) {
            final r = b.rating.compareTo(a.rating);
            if (r != 0) return r;
            return b.reviews.compareTo(a.reviews);
          });
        }
        break;
    }

    return list;
  }

  void _openService(BuildContext context, CustomerBrowseServiceItem item) {
    if (item.isDemo || item.listing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} is a preview listing.')),
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CustomerServiceDetailScreen(
          appUser: widget.appUser,
          listing: item.listing!,
        ),
      ),
    );
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
                padding: const EdgeInsets.fromLTRB(0, 32, 0, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BrowseHero(
                      searchController: _searchController,
                      onSubmitted: (_) => _applyFilters(),
                    ),
                    const SizedBox(height: 36),
                    LayoutBuilder(
                      builder: (context, c) {
                        final twoColumn = c.maxWidth >= _twoColumnMinWidth;
                        final categories = _BrowseCategoriesBlock(
                          appUser: widget.appUser,
                          onViewAll: () {},
                        );
                        const sidebar = _BrowseInsightSidebar();

                        if (twoColumn) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: categories),
                              const SizedBox(width: _columnGap),
                              const SizedBox(width: _sidebarWidth, child: sidebar),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            categories,
                            const SizedBox(height: 24),
                            sidebar,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    _BrowseFilterBar(
                      category: _categoryFilter,
                      location: _location,
                      price: _priceFilter,
                      rating: _ratingFilter,
                      availability: _availabilityFilter,
                      onCategory: (v) => setState(() => _categoryFilter = v),
                      onLocation: (v) => setState(() => _location = v ?? 'Panabo City'),
                      onClearLocation: () => setState(() => _location = 'Panabo City'),
                      onPrice: (v) => setState(() => _priceFilter = v),
                      onRating: (v) => setState(() => _ratingFilter = v),
                      onAvailability: (v) => setState(() => _availabilityFilter = v),
                      onApply: _applyFilters,
                    ),
                    const SizedBox(height: 32),
                    StreamBuilder<List<ServiceListing>>(
                      stream: firestore.activeServicesStream(),
                      builder: (context, serviceSnap) {
                        if (isStreamWaiting(serviceSnap)) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
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

                        return StreamBuilder<List<ServiceProviderProfile>>(
                          stream: firestore.serviceProvidersStream(),
                          builder: (context, providerSnap) {
                            return StreamBuilder<List<AppUser>>(
                              stream: firestore.allUsersStream(),
                              builder: (context, userSnap) {
                                final Map<String, AppUser> users = {
                                  for (final u in userSnap.data ?? []) u.userId: u,
                                };
                                final allItems = buildCustomerBrowseServices(
                                  live: serviceSnap.data ?? [],
                                  profiles: providerSnap.data ?? [],
                                  users: users,
                                );
                                final filtered = _filterAndSort(allItems);
                                final totalPages = filtered.isEmpty
                                    ? 1
                                    : (filtered.length / _pageSize).ceil();
                                final safePage = _page.clamp(0, totalPages - 1);
                                final pageItems = filtered.isEmpty
                                    ? <CustomerBrowseServiceItem>[]
                                    : filtered.skip(safePage * _pageSize).take(_pageSize).toList();

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _AllServicesHeader(
                                      total: filtered.length,
                                      listFilter: _listFilter,
                                      sort: _sort,
                                      onFilter: (f) => setState(() {
                                        _listFilter = f;
                                        _page = 0;
                                      }),
                                      onSort: (s) => setState(() => _sort = s),
                                    ),
                                    const SizedBox(height: 20),
                                    if (pageItems.isEmpty)
                                      FigmaEmptyState(
                                        icon: Icons.search_off_outlined,
                                        title: _query.isEmpty ? 'No services yet' : 'No matches',
                                        message: _query.isEmpty
                                            ? 'Providers are adding listings — check back soon.'
                                            : 'Try different filters or search terms.',
                                      )
                                    else
                                      LayoutBuilder(
                                        builder: (context, gridC) {
                                          final cols = gridC.maxWidth >= 1100
                                              ? 4
                                              : gridC.maxWidth >= 820
                                                  ? 3
                                                  : gridC.maxWidth >= 520
                                                      ? 2
                                                      : 1;
                                          return GridView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: cols,
                                              mainAxisSpacing: 20,
                                              crossAxisSpacing: 20,
                                              mainAxisExtent: 340,
                                            ),
                                            itemCount: pageItems.length,
                                            itemBuilder: (context, i) {
                                              final item = pageItems[i];
                                              final saved = _saved.contains(item.title);
                                              return _BrowseServiceCard(
                                                item: item,
                                                saved: saved,
                                                onToggleSave: () {
                                                  setState(() {
                                                    if (saved) {
                                                      _saved.remove(item.title);
                                                    } else {
                                                      _saved.add(item.title);
                                                    }
                                                  });
                                                },
                                                onTap: () => _openService(context, item),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    if (filtered.isNotEmpty) ...[
                                      const SizedBox(height: 32),
                                      _BrowsePagination(
                                        page: safePage,
                                        totalPages: totalPages,
                                        onPage: (p) => setState(() => _page = p),
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
              ),
            ),
            const CachedAppFooter.customer(),
          ],
        ),
      ),
    );
  }
}

// --- Hero & filters ---

class _BrowseHero extends StatelessWidget {
  const _BrowseHero({required this.searchController, this.onSubmitted});

  final TextEditingController searchController;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

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
                  colors: [rc.tint, FigmaColors.tintGreen2.withValues(alpha: 0.55)],
                ),
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: -6,
            width: 300,
            height: 180,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  painter: _BrowseHousesPainter(accent: rc.primary),
                  size: const Size(300, 180),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse services',
                  style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: FigmaColors.gray900, height: 1.1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search by category, service, or provider near you.',
                  style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45),
                ),
                const SizedBox(height: 24),
                AppSearchField(
                  controller: searchController,
                  hint: 'Search for services, providers, or keywords…',
                  onSubmitted: onSubmitted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseHousesPainter extends CustomPainter {
  _BrowseHousesPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final tree = Paint()..color = accent.withValues(alpha: 0.35);
    final house = Paint()..color = FigmaColors.white.withValues(alpha: 0.85);
    final roof = Paint()..color = accent.withValues(alpha: 0.45);

    void drawHouse(double x, double w, double h) {
      final base = Rect.fromLTWH(x, size.height - h, w, h * 0.65);
      canvas.drawRRect(RRect.fromRectAndRadius(base, const Radius.circular(4)), house);
      final path = Path()
        ..moveTo(x - 5, base.top)
        ..lineTo(x + w / 2, base.top - h * 0.32)
        ..lineTo(x + w + 5, base.top)
        ..close();
      canvas.drawPath(path, roof);
    }

    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(36.0 + i * 52, size.height - 24), 12, tree);
    }
    drawHouse(size.width * 0.38, 64, 72);
    drawHouse(size.width * 0.58, 80, 88);
  }

  @override
  bool shouldRepaint(covariant _BrowseHousesPainter old) => old.accent != accent;
}

class _BrowseFilterBar extends StatelessWidget {
  const _BrowseFilterBar({
    required this.category,
    required this.location,
    required this.price,
    required this.rating,
    required this.availability,
    required this.onCategory,
    required this.onLocation,
    required this.onClearLocation,
    required this.onPrice,
    required this.onRating,
    required this.onAvailability,
    required this.onApply,
  });

  final String? category;
  final String location;
  final String? price;
  final String? rating;
  final String? availability;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onLocation;
  final VoidCallback onClearLocation;
  final ValueChanged<String?> onPrice;
  final ValueChanged<String?> onRating;
  final ValueChanged<String?> onAvailability;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final categories = MarketingServiceCatalog.categories;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FilterChipDropdown(
          label: () {
            if (category == null) return 'Category';
            for (final c in categories) {
              if (c.id == category) return c.name;
            }
            return 'Category';
          }(),
          items: ['All categories', ...categories.map((c) => c.name)],
          onSelected: (v) {
            if (v == 'All categories') {
              onCategory(null);
            } else {
              final cat = categories.firstWhere((c) => c.name == v);
              onCategory(cat.id);
            }
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterChipDropdown(
              label: 'Location: $location',
              items: const ['Panabo City', 'Tagum City', 'Davao City', 'Digos City'],
              onSelected: (v) => onLocation(v),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onClearLocation,
              icon: const Icon(Icons.close, size: 18, color: FigmaColors.gray500),
              tooltip: 'Reset location',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: FigmaColors.white,
                side: const BorderSide(color: FigmaColors.gray200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        _FilterChipDropdown(
          label: price ?? 'Price Range',
          items: const ['Any price', 'Under ₱300', '₱300 – ₱500', '₱500+'],
          onSelected: (v) => onPrice(v == 'Any price' ? null : v),
        ),
        _FilterChipDropdown(
          label: rating ?? 'Rating',
          items: const ['Any rating', '4.5+ stars', '4.8+ stars', '5.0 stars'],
          onSelected: (v) => onRating(v == 'Any rating' ? null : v),
        ),
        _FilterChipDropdown(
          label: availability ?? 'Availability',
          items: const ['Any time', 'Today', 'This week', 'Weekends'],
          onSelected: (v) => onAvailability(v == 'Any time' ? null : v),
        ),
        FilledButton(
          onPressed: onApply,
          style: FilledButton.styleFrom(
            backgroundColor: rc.primary,
            foregroundColor: rc.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: Text('Apply Filters', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _FilterChipDropdown extends StatelessWidget {
  const _FilterChipDropdown({
    required this.label,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final List<String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem(value: item, child: Text(item, style: GoogleFonts.inter(fontSize: 14))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FigmaColors.gray200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: FigmaColors.gray500),
          ],
        ),
      ),
    );
  }
}

// --- Categories + sidebar ---

class _BrowseCategoriesBlock extends StatelessWidget {
  const _BrowseCategoriesBlock({required this.appUser, required this.onViewAll});

  final AppUser appUser;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final categories = MarketingServiceCatalog.categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Browse by category',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all categories',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: rc.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 700 ? 5 : (c.maxWidth >= 480 ? 4 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols >= 5 ? 1.05 : 1.12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final cat = categories[i];
                return _BrowseCategoryTile(
                  category: cat,
                  onTap: () => showMarketingCategoryServices(
                    context,
                    cat,
                    browseContext: MarketingBrowseContext(appUser: appUser),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _BrowseCategoryTile extends StatefulWidget {
  const _BrowseCategoryTile({required this.category, required this.onTap});

  final MarketingServiceCategory category;
  final VoidCallback onTap;

  @override
  State<_BrowseCategoryTile> createState() => _BrowseCategoryTileState();
}

class _BrowseCategoryTileState extends State<_BrowseCategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final border = _hover ? context.roleColors.primary : FigmaColors.gray200;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: _hover ? 2 : 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.06 : 0.03), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: widget.category.bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(widget.category.icon, size: 24, color: widget.category.fg),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.category.serviceCount} services',
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowseInsightSidebar extends StatelessWidget {
  const _BrowseInsightSidebar();

  static const _cards = [
    (Icons.verified_outlined, 'Verified providers', 'Every provider is reviewed and background-checked.'),
    (Icons.payments_outlined, 'Clear pricing', 'See rates upfront before you send a booking request.'),
    (Icons.lock_outline, 'Secure bookings', 'Book and message safely through NeighborHelp.'),
    (Icons.favorite_outline, 'Support your neighborhood', 'Help local providers grow their business nearby.'),
  ];

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Column(
      children: [
        for (var i = 0; i < _cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          AppSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: rc.tint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(_cards[i].$1, size: 22, color: rc.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cards[i].$2,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cards[i].$3,
                        style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// --- All services ---

class _AllServicesHeader extends StatelessWidget {
  const _AllServicesHeader({
    required this.total,
    required this.listFilter,
    required this.sort,
    required this.onFilter,
    required this.onSort,
  });

  final int total;
  final _BrowseListFilter listFilter;
  final _BrowseSort sort;
  final ValueChanged<_BrowseListFilter> onFilter;
  final ValueChanged<_BrowseSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'All services',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final chips = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ListFilterChip(
                  label: 'All ($total)',
                  selected: listFilter == _BrowseListFilter.all,
                  onTap: () => onFilter(_BrowseListFilter.all),
                ),
                _ListFilterChip(
                  label: 'Top Rated',
                  selected: listFilter == _BrowseListFilter.topRated,
                  onTap: () => onFilter(_BrowseListFilter.topRated),
                ),
                _ListFilterChip(
                  label: 'Nearest',
                  selected: listFilter == _BrowseListFilter.nearest,
                  onTap: () => onFilter(_BrowseListFilter.nearest),
                ),
                _ListFilterChip(
                  label: 'Most Booked',
                  selected: listFilter == _BrowseListFilter.mostBooked,
                  onTap: () => onFilter(_BrowseListFilter.mostBooked),
                ),
                _ListFilterChip(
                  label: 'New',
                  selected: listFilter == _BrowseListFilter.newest,
                  onTap: () => onFilter(_BrowseListFilter.newest),
                ),
              ],
            );

            final sortControl = _SortDropdown(sort: sort, onSort: onSort);

            if (c.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: chips),
                  sortControl,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [chips, const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: sortControl)],
            );
          },
        ),
      ],
    );
  }
}

class _ListFilterChip extends StatelessWidget {
  const _ListFilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Material(
      color: selected ? rc.primary : FigmaColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? rc.primary : FigmaColors.gray200),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? rc.onPrimary : FigmaColors.gray700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.sort, required this.onSort});

  final _BrowseSort sort;
  final ValueChanged<_BrowseSort> onSort;

  String get _label => switch (sort) {
        _BrowseSort.recommended => 'Recommended',
        _BrowseSort.priceLow => 'Price: Low to High',
        _BrowseSort.priceHigh => 'Price: High to Low',
        _BrowseSort.rating => 'Highest Rated',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BrowseSort>(
      onSelected: onSort,
      offset: const Offset(0, 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort by: ', style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600)),
          Text(_label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900)),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: FigmaColors.gray600),
        ],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: _BrowseSort.recommended, child: Text('Recommended')),
        const PopupMenuItem(value: _BrowseSort.priceLow, child: Text('Price: Low to High')),
        const PopupMenuItem(value: _BrowseSort.priceHigh, child: Text('Price: High to Low')),
        const PopupMenuItem(value: _BrowseSort.rating, child: Text('Highest Rated')),
      ],
    );
  }
}

class _BrowseServiceCard extends StatefulWidget {
  const _BrowseServiceCard({
    required this.item,
    required this.saved,
    required this.onToggleSave,
    required this.onTap,
  });

  final CustomerBrowseServiceItem item;
  final bool saved;
  final VoidCallback onToggleSave;
  final VoidCallback onTap;

  @override
  State<_BrowseServiceCard> createState() => _BrowseServiceCardState();
}

class _BrowseServiceCardState extends State<_BrowseServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final item = widget.item;
    final ratingText = item.rating > 0 ? item.rating.toStringAsFixed(1) : '—';
    final avatarBg = item.providerAvatarColor ?? rc.tint;
    final initial = item.providerInitial ?? (item.providerName.isNotEmpty ? item.providerName[0].toUpperCase() : '?');

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _hover ? rc.primary : FigmaColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        child: FigmaNetworkImage(url: item.imageUrl, fit: BoxFit.cover),
                      ),
                      if (item.verified)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rc.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Verified',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: rc.onPrimary),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: FigmaColors.white.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: Icon(
                              widget.saved ? Icons.bookmark : Icons.bookmark_border,
                              color: widget.saved ? rc.primary : FigmaColors.gray600,
                              size: 20,
                            ),
                            onPressed: widget.onToggleSave,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                            radius: 12,
                            backgroundColor: avatarBg,
                            backgroundImage: item.providerPhotoUrl != null ? NetworkImage(item.providerPhotoUrl!) : null,
                            child: item.providerPhotoUrl == null
                                ? Text(initial, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: rc.primary))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: FigmaColors.gray800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFEAB308)),
                          const SizedBox(width: 4),
                          Text(
                            '$ratingText (${item.reviews})',
                            style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600),
                          ),
                          const Spacer(),
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

class _BrowsePagination extends StatelessWidget {
  const _BrowsePagination({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;

    List<int?> pageNumbers() {
      if (totalPages <= 7) return List.generate(totalPages, (i) => i);
      return [0, 1, 2, null, totalPages - 1];
    }

    return Center(
      child: Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _PageArrow(
            icon: Icons.chevron_left,
            enabled: page > 0,
            onTap: () => onPage(page - 1),
          ),
          for (final n in pageNumbers())
            if (n == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('…', style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500)),
              )
            else
              _PageNumber(
                label: '${n + 1}',
                selected: n == page,
                primary: rc.primary,
                onTap: () => onPage(n),
              ),
          _PageArrow(
            icon: Icons.chevron_right,
            enabled: page < totalPages - 1,
            onTap: () => onPage(page + 1),
          ),
        ],
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  const _PageArrow({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, color: enabled ? FigmaColors.gray700 : FigmaColors.gray300),
      style: IconButton.styleFrom(
        backgroundColor: FigmaColors.white,
        side: const BorderSide(color: FigmaColors.gray200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? primary : FigmaColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? primary : FigmaColors.gray200),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? FigmaColors.white : FigmaColors.gray700,
            ),
          ),
        ),
      ),
    );
  }
}
