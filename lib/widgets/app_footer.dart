import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_layout.dart';
import '../figma_ui/figma_marketing_assets.dart';
import '../screens/shared/help_support_popover.dart';
import '../theme/mobile_layout.dart';
import '../theme/adaptive_breakpoints.dart';

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
    if (MobileLayout.hideMarketingFooter(context) ||
        AdaptiveBreakpoints.isExpanded(context)) {
      return const SizedBox.shrink();
    }
    return _footer ?? const SizedBox.shrink();
  }
}

/// A quiet, shared app footer with NeighborHelp's existing support details.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.roleLabel = 'Customer'});

  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: FigmaWideContainer(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outline)),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                '© ${DateTime.now().year} NeighborHelp. All rights reserved.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
              _link(
                context,
                'How bookings work',
                () => _showInfo(
                  context,
                  title: 'How bookings work',
                  body:
                      'Send a request with your location, schedule, and preferred rate. Providers confirm availability before the job starts.',
                ),
              ),
              _link(
                context,
                'Trust & safety',
                () => _showInfo(
                  context,
                  title: 'Verified providers',
                  body:
                      'Look for the verified badge on provider profiles. Admins review provider applications before approval.',
                ),
              ),
              _link(
                context,
                'Privacy',
                () => _showInfo(
                  context,
                  title: 'Privacy',
                  body:
                      'Your account data is stored securely. Only parties involved in a booking can see related messages and details.',
                ),
              ),
              _link(
                context,
                'Help & support',
                () => HelpSupportPopover.show(context, roleLabel: roleLabel),
              ),
              _link(
                context,
                'Contact',
                () => _showInfo(
                  context,
                  title: 'Contact NeighborHelp',
                  body:
                      'support@neighborhelp.com\nServing Davao del Norte & nearby\n\nTrusted local services in your community.\nBuilt for neighbors, by neighbors.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _link(BuildContext context, String label, VoidCallback onPressed) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        child: Text(label),
      );

  static void _showInfo(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: GoogleFonts.inter(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
