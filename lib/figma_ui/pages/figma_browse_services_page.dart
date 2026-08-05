import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';
import '../figma_layout.dart';
import '../marketing_category_dialogs.dart';
import '../marketing_featured_services.dart';
import '../marketing_service_catalog.dart';
import '../widgets/figma_network_image.dart';

class FigmaBrowseServicesPage extends StatelessWidget {
  const FigmaBrowseServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigmaHeroGradientBackground(
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browse Services', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 16),
                  Text('Explore all available services in your area', style: GoogleFonts.inter(fontSize: 18, color: FigmaColors.gray600)),
                  const SizedBox(height: 32),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 768),
                    decoration: BoxDecoration(
                      color: FigmaColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
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
                                      hintText: 'Search for services...',
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Service Categories', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: FigmaColors.gray900))),
                      OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FigmaColors.gray900,
                          side: const BorderSide(color: FigmaColors.gray200, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.filter_list, size: 18),
                        label: Text('Filter', style: GoogleFonts.inter(fontSize: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth >= 1024 ? 5 : (c.maxWidth >= 768 ? 4 : 2);
                      final ratio = cols >= 5 ? 1.55 : (cols >= 4 ? 1.62 : 1.38);
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: cols,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: ratio,
                        children: MarketingServiceCatalog.categories
                            .map((e) => _BrowseCategoryTile(category: e))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 64),
                  Text('All Services', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  const SizedBox(height: 32),
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
                        itemBuilder: (_, i) => _BrowseServiceCard(data: MarketingFeaturedServices.all[i]),
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

class _BrowseCategoryTile extends StatefulWidget {
  const _BrowseCategoryTile({required this.category});
  final MarketingServiceCategory category;

  @override
  State<_BrowseCategoryTile> createState() => _BrowseCategoryTileState();
}

class _BrowseCategoryTileState extends State<_BrowseCategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hover ? FigmaColors.navy : FigmaColors.gray200;
    final borderW = _hover ? 2.0 : 1.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: borderW),
          boxShadow: _hover
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: InkWell(
          onTap: () => showMarketingCategoryServices(context, widget.category),
          borderRadius: BorderRadius.circular(8),
          child: Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: widget.category.bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(widget.category.icon, size: 22, color: widget.category.fg),
                ),
                const SizedBox(height: 8),
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

class _BrowseServiceCard extends StatefulWidget {
  const _BrowseServiceCard({required this.data});
  final MarketingFeaturedService data;

  @override
  State<_BrowseServiceCard> createState() => _BrowseServiceCardState();
}

class _BrowseServiceCardState extends State<_BrowseServiceCard> {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 192,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [FigmaColors.tintBlue, FigmaColors.purple100], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                            Text('${widget.data.rating}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: FigmaColors.navy, borderRadius: BorderRadius.circular(999)),
                        child: Text(widget.data.categoryName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: FigmaColors.white)),
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
