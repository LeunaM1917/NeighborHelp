import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';
import '../figma_layout.dart';
import '../marketing_category_dialogs.dart';
import '../marketing_featured_services.dart';
import '../marketing_service_catalog.dart';
import '../widgets/figma_network_image.dart';

class FigmaHomePage extends StatefulWidget {
  const FigmaHomePage({super.key});

  @override
  State<FigmaHomePage> createState() => _FigmaHomePageState();
}

class _FigmaHomePageState extends State<FigmaHomePage> {
  bool _serviceMode = true;

  static const _heroImage =
      'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=800&q=80';

  static const _steps = <_StepData>[
    _StepData(Icons.search, 'Browse Services', 'Search or explore categories to find the service you need'),
    _StepData(Icons.person_search_outlined, 'Choose a Provider', 'Compare profiles, ratings, and pricing'),
    _StepData(Icons.event_available_outlined, 'Send Booking Request', 'Request a date and confirm with your provider'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigmaHeroGradientBackground(
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _HeroLeft(serviceMode: _serviceMode, onMode: (v) => setState(() => _serviceMode = v))),
                        const SizedBox(width: 48),
                        Expanded(child: _HeroRight(heroImage: _heroImage)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroLeft(serviceMode: _serviceMode, onMode: (v) => setState(() => _serviceMode = v)),
                        const SizedBox(height: 48),
                        _HeroRight(heroImage: _heroImage),
                      ],
                    ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.white,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text('Browse by Category', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text(
                    'Find the perfect service provider for your needs',
                    style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600),
                  ),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1024 ? 5 : (c.maxWidth >= 768 ? 4 : 2);
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: cols,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: cols >= 5 ? 1.15 : (cols >= 4 ? 1.22 : 1.02),
                        children: MarketingServiceCatalog.categories
                            .map((e) => _CategoryTile(category: e))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.gray50,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Text('How NeighborHelp Works', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 12),
                  Text('Get started in three simple steps', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth >= 768) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < _steps.length; i++) ...[
                              if (i > 0) const SizedBox(width: 32),
                              Expanded(child: _StepCard(data: _steps[i])),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: _steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 24), child: _StepCard(data: s))).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        ColoredBox(
          color: FigmaColors.white,
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Popular Services Near You', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 8),
                  Text('Top-rated providers in your area', style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600)),
                  const SizedBox(height: 48),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 768 ? 3 : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          mainAxisExtent: cols == 1 ? 300 : 320,
                        ),
                        itemCount: MarketingFeaturedServices.all.length,
                        itemBuilder: (_, i) => _ServiceCard(data: MarketingFeaturedServices.all[i]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepData {
  const _StepData(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;
}

class _HeroLeft extends StatelessWidget {
  const _HeroLeft({required this.serviceMode, required this.onMode});

  final bool serviceMode;
  final ValueChanged<bool> onMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Find trusted local services in your community',
          style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: FigmaColors.gray900, height: 1.1),
        ),
        const SizedBox(height: 16),
        Text(
          'Browse services, choose a trusted provider, and send a booking request. All providers are vetted and reviewed by your neighbors.',
          style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600, height: 1.45),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: FigmaColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _ModeChip(label: 'Service Needed', selected: serviceMode, onTap: () => onMode(true)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: FigmaColors.gray50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 22, color: FigmaColors.gray400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: serviceMode ? 'What service do you need?' : 'Search for service providers...',
                                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 16),
                              ),
                              style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: FigmaColors.navy,
                      foregroundColor: FigmaColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.search, size: 22),
                    label: Text('Search', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _trustRow('Trusted Providers'),
            _trustRow('Secure Payment'),
            _trustRow('Verified Services'),
          ],
        ),
      ],
    );
  }

  static Widget _trustRow(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline, size: 22, color: FigmaColors.green),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700)),
      ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.navy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: selected ? FigmaColors.white : FigmaColors.gray600,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _HeroRight extends StatelessWidget {
  const _HeroRight({required this.heroImage});

  final String heroImage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: FigmaColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 32, offset: const Offset(0, 12)),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 384,
              width: double.infinity,
              child: FigmaNetworkImage(url: heroImage, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          right: -16,
          bottom: -16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FigmaColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 72,
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(4, (i) {
                      return Positioned(
                        left: i * 14.0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6B9BD1), Color(0xFF9333EA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: FigmaColors.white, width: 2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 40),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('4.9★', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                    Text('20k+ Providers', style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.category});

  final MarketingServiceCategory category;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hover ? FigmaColors.navy : FigmaColors.gray100, width: 2),
          boxShadow: _hover ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))] : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: InkWell(
          onTap: () => showMarketingCategoryServices(context, widget.category),
          borderRadius: BorderRadius.circular(12),
          child: Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: _hover ? 1.08 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: widget.category.bg, borderRadius: BorderRadius.circular(8)),
                    child: Icon(widget.category.icon, size: 24, color: widget.category.fg),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.category.serviceCount} services',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.data});

  final _StepData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: FigmaColors.navy, shape: BoxShape.circle),
            child: Icon(data.icon, size: 30, color: FigmaColors.white),
          ),
          const SizedBox(height: 16),
          Text(data.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
          const SizedBox(height: 8),
          Text(data.description, style: GoogleFonts.inter(fontSize: 16, color: FigmaColors.gray600, height: 1.45)),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  const _ServiceCard({required this.data});

  final MarketingFeaturedService data;

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hover ? FigmaColors.navy : FigmaColors.gray100, width: 2),
          boxShadow: _hover ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openMarketingFeaturedService(context, widget.data),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 192,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [FigmaColors.tintBlue, FigmaColors.purple100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    FigmaNetworkImage(url: widget.data.imageUrl, fit: BoxFit.cover),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: FigmaColors.white, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 18, color: FigmaColors.yellow500),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.data.rating}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.data.title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.thumb_up_outlined, size: 18, color: FigmaColors.gray500),
                              const SizedBox(width: 4),
                              Text('${widget.data.reviews} reviews', style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500)),
                            ],
                          ),
                        ),
                        Text(
                          'From ₱${widget.data.pricePhp}/hr',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.navy),
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
    );
  }
}
