import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../figma_ui/figma_layout.dart';
import '../figma_ui/figma_marketing_assets.dart';
import '../screens/shared/help_support_popover.dart';
import '../theme/mobile_layout.dart';
import '../theme/role_theme.dart';

/// Precaches footer assets once per app session (call from shell [initState]).
abstract final class AppFooterCache {
  static bool _logoPrecached = false;

  static Future<void> ensurePrecached(BuildContext context) async {
    if (_logoPrecached) return;
    try {
      await precacheImage(
        const AssetImage(FigmaMarketingAssets.footerLogo),
        context,
      );
      _logoPrecached = true;
    } catch (_) {
      // Asset missing in dev — footer still renders via errorBuilder.
    }
  }
}

/// Footer that builds once per [State] (kept alive in shell [IndexedStack] tabs).
class CachedAppFooter extends StatefulWidget {
  const CachedAppFooter({super.key, this.roleLabel = 'Customer'});

  const CachedAppFooter.customer({super.key}) : roleLabel = 'Customer';
  const CachedAppFooter.provider({super.key}) : roleLabel = 'Provider';

  final String roleLabel;

  @override
  State<CachedAppFooter> createState() => _CachedAppFooterState();
}

class _CachedAppFooterState extends State<CachedAppFooter> {
  Widget? _footer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _footer ??= RepaintBoundary(
      key: ValueKey('cached_footer_${widget.roleLabel}'),
      child: AppFooter(roleLabel: widget.roleLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MobileLayout.hideMarketingFooter(context)) {
      return const SizedBox.shrink();
    }
    return _footer ?? const SizedBox.shrink();
  }
}

/// Site-wide footer for authenticated app shells and scrollable pages.
class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
    this.roleLabel = 'Customer',
  });

  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final rc = context.roleColors;

    return ColoredBox(
      color: FigmaColors.navy,
      child: FigmaWideContainer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final brand = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 40,
                        child: Image.asset(
                          FigmaMarketingAssets.footerLogo,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          cacheWidth: 160,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, height: 1.1),
                          children: const [
                            TextSpan(text: 'Neighbor', style: TextStyle(color: FigmaColors.white)),
                            TextSpan(text: 'Help', style: TextStyle(color: FigmaColors.green)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Trusted local services in your community.',
                    style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray300, height: 1.5),
                  ),
                ],
              );

              final links = _FooterLinkColumn(
                title: 'Explore',
                roleLabel: roleLabel,
                links: const [
                  _FooterLinkData('Help & support', _FooterAction.help),
                  _FooterLinkData('How bookings work', _FooterAction.howBookings),
                ],
              );

              final trust = _FooterLinkColumn(
                title: 'Trust & safety',
                roleLabel: roleLabel,
                links: const [
                  _FooterLinkData('Verified providers', _FooterAction.verified),
                  _FooterLinkData('Privacy', _FooterAction.privacy),
                ],
              );

              final contact = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: FigmaColors.white),
                  ),
                  const SizedBox(height: 12),
                  _FooterContactRow(icon: Icons.mail_outline, label: 'support@neighborhelp.com'),
                  const SizedBox(height: 8),
                  _FooterContactRow(icon: Icons.place_outlined, label: 'Serving Davao del Norte & nearby'),
                ],
              );

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    brand,
                    const SizedBox(height: 28),
                    links,
                    const SizedBox(height: 20),
                    trust,
                    const SizedBox(height: 20),
                    contact,
                    const SizedBox(height: 28),
                    Divider(color: FigmaColors.white.withValues(alpha: 0.12)),
                    const SizedBox(height: 20),
                    _CopyrightRow(year: year, accent: rc.primary),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: brand),
                      const SizedBox(width: 32),
                      Expanded(child: links),
                      const SizedBox(width: 24),
                      Expanded(child: trust),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: contact),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Divider(color: FigmaColors.white.withValues(alpha: 0.12)),
                  const SizedBox(height: 20),
                  _CopyrightRow(year: year, accent: rc.primary),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static void _showFooterInfo(BuildContext context, {required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(body, style: GoogleFonts.inter(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

enum _FooterAction { help, howBookings, verified, privacy }

class _FooterLinkData {
  const _FooterLinkData(this.label, this.action);
  final String label;
  final _FooterAction action;
}

class _FooterLinkColumn extends StatelessWidget {
  const _FooterLinkColumn({
    required this.title,
    required this.roleLabel,
    required this.links,
  });

  final String title;
  final String roleLabel;
  final List<_FooterLinkData> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: FigmaColors.white),
        ),
        const SizedBox(height: 12),
        for (final link in links) ...[
          TextButton(
            onPressed: () => _FooterLinkColumn._onTap(context, roleLabel: roleLabel, action: link.action),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: FigmaColors.gray300,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                link.label,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  static void _onTap(BuildContext context, {required String roleLabel, required _FooterAction action}) {
    switch (action) {
      case _FooterAction.help:
        HelpSupportPopover.show(context, roleLabel: roleLabel);
      case _FooterAction.howBookings:
        AppFooter._showFooterInfo(
          context,
          title: 'How bookings work',
          body:
              'Send a request with your location, schedule, and preferred rate. Providers confirm availability before the job starts.',
        );
      case _FooterAction.verified:
        AppFooter._showFooterInfo(
          context,
          title: 'Verified providers',
          body:
              'Look for the verified badge on provider profiles. Admins review provider applications before approval.',
        );
      case _FooterAction.privacy:
        AppFooter._showFooterInfo(
          context,
          title: 'Privacy',
          body:
              'Your account data is stored securely. Only parties involved in a booking can see related messages and details.',
        );
    }
  }
}

class _FooterContactRow extends StatelessWidget {
  const _FooterContactRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FigmaColors.gray400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray300),
          ),
        ),
      ],
    );
  }
}

class _CopyrightRow extends StatelessWidget {
  const _CopyrightRow({required this.year, required this.accent});

  final int year;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '© $year NeighborHelp. All rights reserved.',
          style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray400),
        ),
        const Spacer(),
        Text(
          'Built for neighbors, by neighbors.',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
        ),
      ],
    );
  }
}
