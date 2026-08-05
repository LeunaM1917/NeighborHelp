import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top brand row: logotype + optional subtitle.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.subtitle, this.compact = false});

  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = GoogleFonts.inter(
      fontSize: compact ? 22 : 26,
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
      letterSpacing: -0.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 6 : 8,
              height: compact ? 22 : 28,
              decoration: BoxDecoration(
                color: colorScheme.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Neighbor', style: titleStyle),
                  TextSpan(
                    text: 'Help',
                    style: titleStyle.copyWith(color: colorScheme.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: compact ? 13 : 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

/// Card panel for auth and forms.
class MarketplacePanel extends StatelessWidget {
  const MarketplacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Full-screen backdrop for auth flows.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.body,
    this.leading,
    this.title,
  });

  final Widget body;
  final Widget? leading;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAppBar = leading != null || title != null;
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: hasAppBar
          ? AppBar(
              automaticallyImplyLeading: leading != null,
              leading: leading,
              title: title,
              titleTextStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth >= 900 ? 440.0 : c.maxWidth;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: body,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
