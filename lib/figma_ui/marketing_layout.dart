import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'davao_locations.dart';
import 'figma_colors.dart';
import 'figma_layout.dart';
import 'figma_marketing_assets.dart';
import '../theme/adaptive_breakpoints.dart';
import 'marketing_route.dart';
import '../widgets/app_scroll_chrome.dart';
import 'widgets/figma_brand_row.dart';

typedef MarketingNavigate = void Function(MarketingRoute route);

class MarketingLayout extends StatefulWidget {
  const MarketingLayout({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.onLogin,
    required this.onSignUp,
    required this.child,
  });

  final MarketingRoute currentRoute;
  final MarketingNavigate onNavigate;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final Widget child;

  @override
  State<MarketingLayout> createState() => _MarketingLayoutState();
}

class _MarketingLayoutState extends State<MarketingLayout> {
  String _selectedLocation = 'Panabo City';
  final GlobalKey _locationButtonKey = GlobalKey();
  final ScrollController _pageScrollController = ScrollController();
  OverlayEntry? _locationOverlay;

  @override
  void dispose() {
    _pageScrollController.dispose();
    _removeLocationOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(MarketingLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
      });
    }
  }

  void _removeLocationOverlay() {
    _locationOverlay?.remove();
    _locationOverlay = null;
  }

  void _toggleLocationOverlay() {
    if (_locationOverlay != null) {
      _removeLocationOverlay();
      setState(() {});
      return;
    }
    final ctx = _locationButtonKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    final overlayState = Overlay.of(context);
    if (box == null || !box.hasSize) return;

    final size = box.size;
    final origin = box.localToGlobal(Offset.zero);
    final media = MediaQuery.sizeOf(context);
    var left = origin.dx;
    const panelW = 288.0;
    if (left + panelW > media.width - 8) left = media.width - panelW - 8;
    if (left < 8) left = 8;

    _locationOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _removeLocationOverlay();
                setState(() {});
              },
              child: const ColoredBox(color: Color(0x33000000)),
            ),
          ),
          Positioned(
            left: left,
            top: origin.dy + size.height + 8,
            width: panelW,
            child: Material(
              elevation: 12,
              color: FigmaColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: FigmaColors.gray200, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 384),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < kDavaoRegionLocations.length; i++) ...[
                        if (i > 0) const Divider(height: 24, color: FigmaColors.gray200),
                        _ProvinceBlock(
                          data: kDavaoRegionLocations[i],
                          selectedLocation: _selectedLocation,
                          onSelect: (loc) {
                            setState(() => _selectedLocation = loc);
                            _removeLocationOverlay();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlayState.insert(_locationOverlay!);
    setState(() {});
  }

  bool _isActive(MarketingRoute r) => widget.currentRoute == r;

  /// Compact "{City}, PH" for the header (~same visual length as "Panabo City, PH").
  /// Full place name stays in the tooltip and location picker.
  String _locationChipText() {
    const tail = ', PH';
    const maxTotal = 22;
    final city = _selectedLocation.trim();
    final full = '$city$tail';
    if (full.length <= maxTotal) return full;
    const ellipsis = '…';
    final budget = maxTotal - tail.length - ellipsis.length;
    if (budget < 2) return '$ellipsis$tail';
    final prefix = Characters(city).take(budget).toString();
    return '$prefix$ellipsis$tail';
  }

  Widget _headerLocationChip({required double maxLabelWidth}) {
    return Tooltip(
      message: '$_selectedLocation, Philippines',
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        key: _locationButtonKey,
        onTap: _toggleLocationOverlay,
        borderRadius: BorderRadius.circular(8),
        hoverColor: FigmaColors.gray100.withValues(alpha: 0.85),
        splashColor: FigmaColors.tintBlue.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined, size: 18, color: FigmaColors.gray700),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxLabelWidth),
                child: Text(
                  _locationChipText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _locationOverlay != null ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: FigmaColors.gray700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdaptiveBreakpoints.marketingNav;

    return ColoredBox(
      color: FigmaColors.white,
      child: Column(
        children: [
          Material(
            color: FigmaColors.white,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: FigmaColors.white,
                border: Border(bottom: BorderSide(color: FigmaColors.gray200)),
              ),
              child: FigmaWideContainer(
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      FigmaBrandRow(
                        logoHeight: 52,
                        titleFontSize: 19,
                        logoAssetPath: FigmaMarketingAssets.navLogo,
                        onTap: () => widget.onNavigate(MarketingRoute.home),
                      ),
                      if (wide) ...[
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _HeaderNavLink(
                                    label: 'Home',
                                    route: MarketingRoute.home,
                                    active: _isActive(MarketingRoute.home),
                                    onNavigate: widget.onNavigate,
                                  ),
                                  const SizedBox(width: 16),
                                  _HeaderNavLink(
                                    label: 'Browse Services',
                                    route: MarketingRoute.browseServices,
                                    active: _isActive(MarketingRoute.browseServices),
                                    onNavigate: widget.onNavigate,
                                  ),
                                  const SizedBox(width: 16),
                                  _HeaderNavLink(
                                    label: 'How It Works',
                                    route: MarketingRoute.howItWorks,
                                    active: _isActive(MarketingRoute.howItWorks),
                                    onNavigate: widget.onNavigate,
                                  ),
                                  const SizedBox(width: 16),
                                  _HeaderNavLink(
                                    label: 'For Providers',
                                    route: MarketingRoute.forProviders,
                                    active: _isActive(MarketingRoute.forProviders),
                                    onNavigate: widget.onNavigate,
                                  ),
                                  const SizedBox(width: 16),
                                  _HeaderNavLink(
                                    label: 'About Us',
                                    route: MarketingRoute.aboutUs,
                                    active: _isActive(MarketingRoute.aboutUs),
                                    onNavigate: widget.onNavigate,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _headerLocationChip(maxLabelWidth: 200),
                            TextButton(
                              onPressed: widget.onLogin,
                              style: TextButton.styleFrom(
                                foregroundColor: FigmaColors.gray700,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ).copyWith(
                                overlayColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return FigmaColors.gray100.withValues(alpha: 0.9);
                                  }
                                  if (states.contains(WidgetState.pressed)) {
                                    return FigmaColors.tintBlue.withValues(alpha: 0.25);
                                  }
                                  return null;
                                }),
                              ),
                              child: Text('Log In', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400)),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: widget.onSignUp,
                              style: FilledButton.styleFrom(
                                backgroundColor: FigmaColors.navy,
                                foregroundColor: FigmaColors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ).copyWith(
                                overlayColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.hovered)) {
                                    return Colors.white.withValues(alpha: 0.12);
                                  }
                                  if (states.contains(WidgetState.pressed)) {
                                    return Colors.black.withValues(alpha: 0.12);
                                  }
                                  return null;
                                }),
                              ),
                              child: Text('Sign Up', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400)),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, color: FigmaColors.gray700),
                          onPressed: () => _openMobileDrawer(context),
                        ),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _headerLocationChip(maxLabelWidth: 120),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onLogin,
                          style: TextButton.styleFrom(
                            foregroundColor: FigmaColors.gray700,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ).copyWith(
                            overlayColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.hovered)) {
                                return FigmaColors.gray100.withValues(alpha: 0.9);
                              }
                              if (states.contains(WidgetState.pressed)) {
                                return FigmaColors.tintBlue.withValues(alpha: 0.25);
                              }
                              return null;
                            }),
                          ),
                          child: Text('Log In', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400)),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: widget.onSignUp,
                          style: FilledButton.styleFrom(
                            backgroundColor: FigmaColors.navy,
                            foregroundColor: FigmaColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ).copyWith(
                            overlayColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.hovered)) {
                                return Colors.white.withValues(alpha: 0.12);
                              }
                              if (states.contains(WidgetState.pressed)) {
                                return Colors.black.withValues(alpha: 0.12);
                              }
                              return null;
                            }),
                          ),
                          child: Text('Sign Up', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AppScrollChrome(
              scrollController: _pageScrollController,
              accentColor: FigmaColors.green,
              bottomInset: 28,
              footerClearance: 320,
              child: SingleChildScrollView(
                controller: _pageScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.child,
                    _MarketingFooter(onNavigate: widget.onNavigate),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMobileDrawer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FigmaColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in MarketingRoute.values)
                ListTile(
                  title: Text(
                    r.label,
                    style: GoogleFonts.inter(
                      fontWeight: _isActive(r) ? FontWeight.w600 : FontWeight.w400,
                      color: _isActive(r) ? FigmaColors.navy : FigmaColors.gray700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onNavigate(r);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop header nav: even line metrics for active vs inactive, gap under text before underline, hover tint.
class _HeaderNavLink extends StatefulWidget {
  const _HeaderNavLink({
    required this.label,
    required this.route,
    required this.active,
    required this.onNavigate,
  });

  final String label;
  final MarketingRoute route;
  final bool active;
  final MarketingNavigate onNavigate;

  @override
  State<_HeaderNavLink> createState() => _HeaderNavLinkState();
}

class _HeaderNavLinkState extends State<_HeaderNavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.active;
    final hovered = _hover && !on;
    final fg = on ? FigmaColors.navy : (hovered ? FigmaColors.navy : FigmaColors.gray700);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onNavigate(widget.route),
          borderRadius: BorderRadius.circular(8),
          hoverColor: FigmaColors.gray100.withValues(alpha: 0.75),
          splashColor: FigmaColors.tintBlue.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    strutStyle: const StrutStyle(
                      fontSize: 15,
                      height: 1.2,
                      leadingDistribution: TextLeadingDistribution.even,
                      forceStrutHeight: true,
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 3,
                    child: on
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: FigmaColors.navy,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProvinceBlock extends StatelessWidget {
  const _ProvinceBlock({
    required this.data,
    required this.selectedLocation,
    required this.onSelect,
  });

  final DavaoProvinceData data;
  final String selectedLocation;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            data.province.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FigmaColors.navy,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (data.cities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Text('Cities', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray500)),
          ),
          for (final city in data.cities)
            _LocationTile(label: city, selected: selectedLocation == city, onTap: () => onSelect(city)),
        ],
        if (data.municipalities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('Municipalities', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray500)),
          ),
          for (final m in data.municipalities)
            _LocationTile(label: m, selected: selectedLocation == m, onTap: () => onSelect(m)),
        ],
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: selected ? FigmaColors.tintBlue.withValues(alpha: 0.75) : FigmaColors.gray50.withValues(alpha: 0.95),
      splashColor: FigmaColors.tintBlue.withValues(alpha: 0.25),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.tintBlue : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? FigmaColors.navy : FigmaColors.gray700,
          ),
        ),
      ),
    );
  }
}

class _MarketingFooter extends StatelessWidget {
  const _MarketingFooter({required this.onNavigate});

  final MarketingNavigate onNavigate;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdaptiveBreakpoints.marketingNav;
    return ColoredBox(
      color: FigmaColors.gray900,
      child: FigmaWideContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _FooterBrandColumn()),
                        Expanded(child: _FooterLinksColumn(title: 'For Customers', links: _customerLinks(onNavigate))),
                        Expanded(child: _FooterLinksColumn(title: 'For Providers', links: _providerLinks(onNavigate))),
                        Expanded(child: _FooterLinksColumn(title: 'Company', links: _companyLinks(onNavigate))),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FooterBrandColumn(),
                        const SizedBox(height: 32),
                        _FooterLinksColumn(title: 'For Customers', links: _customerLinks(onNavigate)),
                        const SizedBox(height: 24),
                        _FooterLinksColumn(title: 'For Providers', links: _providerLinks(onNavigate)),
                        const SizedBox(height: 24),
                        _FooterLinksColumn(title: 'Company', links: _companyLinks(onNavigate)),
                      ],
                    ),
              const Divider(color: FigmaColors.gray800, height: 48, thickness: 1),
              Text(
                '© 2026 NeighborHelp. All rights reserved.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _customerLinks(MarketingNavigate onNavigate) => [
      _FooterLink(
        label: 'Browse Services',
        onTap: () => onNavigate(MarketingRoute.browseServices),
      ),
      _FooterLink(
        label: 'How It Works',
        onTap: () => onNavigate(MarketingRoute.howItWorks),
      ),
      _FooterLink(label: 'Safety', onTap: () {}),
    ];

List<Widget> _providerLinks(MarketingNavigate onNavigate) => [
      _FooterLink(
        label: 'Become a Provider',
        onTap: () => onNavigate(MarketingRoute.forProviders),
      ),
      _FooterLink(label: 'Resources', onTap: () {}),
      _FooterLink(label: 'Success Stories', onTap: () {}),
    ];

List<Widget> _companyLinks(MarketingNavigate onNavigate) => [
      _FooterLink(
        label: 'About Us',
        onTap: () => onNavigate(MarketingRoute.aboutUs),
      ),
      _FooterLink(label: 'Contact', onTap: () {}),
      _FooterLink(label: 'Privacy Policy', onTap: () {}),
    ];

class _FooterBrandColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 80,
                width: 80,
                child: Image.asset(
                  FigmaMarketingAssets.footerLogo,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: FigmaColors.gray700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.groups_2_rounded, color: Colors.white54, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text.rich(
              TextSpan(
                style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w700),
                children: const [
                  TextSpan(text: 'Neighbor', style: TextStyle(color: FigmaColors.footerNeighbor)),
                  TextSpan(text: 'Help', style: TextStyle(color: FigmaColors.footerHelp)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Connecting communities with trusted local service providers.',
          style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray400, height: 1.45),
        ),
      ],
    );
  }
}

class _FooterLinksColumn extends StatelessWidget {
  const _FooterLinksColumn({required this.title, required this.links});

  final String title;
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.white)),
        const SizedBox(height: 16),
        ...links.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _hover ? FigmaColors.white : FigmaColors.gray400,
            decoration: _hover ? TextDecoration.underline : TextDecoration.none,
            decorationColor: _hover ? Colors.white70 : FigmaColors.gray400,
          ),
        ),
      ),
    );
  }
}
