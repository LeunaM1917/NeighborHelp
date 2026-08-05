import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../theme/role_theme.dart';
import '../figma_ui/marketing_category_dialogs.dart';
import '../figma_ui/marketing_service_catalog.dart';

/// Compact category grid for customer browse / home.
class CategoryBrowseGrid extends StatelessWidget {
  const CategoryBrowseGrid({super.key, this.appUser});

  final AppUser? appUser;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 600 ? 4 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: cols >= 4 ? 1.22 : (cols >= 3 ? 1.1 : 1.0),
          ),
          itemCount: MarketingServiceCatalog.categories.length,
          itemBuilder: (context, i) {
            final cat = MarketingServiceCatalog.categories[i];
            return _CategoryChip(
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
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final MarketingServiceCategory category;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hover ? context.roleColors.primary : FigmaColors.gray200,
                width: _hover ? 2 : 1,
              ),
              boxShadow: _hover
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: widget.category.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(widget.category.icon, color: widget.category.fg, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray900, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.category.serviceCount} services',
                  style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
