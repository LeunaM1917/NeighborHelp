import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../figma_ui/figma_colors.dart';
import '../figma_ui/figma_layout.dart';
import '../widgets/app_footer.dart';
import '../widgets/app_scroll_chrome.dart';
import '../theme/role_theme.dart';

/// Shared layout and components for signed-in Customer / Provider / Admin apps.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                foregroundColor: FigmaColors.gray700,
                backgroundColor: FigmaColors.gray100,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.gray900,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(fontSize: 15, color: FigmaColors.gray600, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
                  ],
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: card),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(fontSize: 15, color: FigmaColors.gray900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded, color: FigmaColors.gray400, size: 22),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class AppHeroBand extends StatelessWidget {
  const AppHeroBand({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FigmaHeroGradientBackground(
      child: FigmaWideContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: child,
        ),
      ),
    );
  }
}

class AppTabBody extends StatelessWidget {
  const AppTabBody({
    super.key,
    required this.child,
    this.scrollController,
    this.grayBackground = true,
    this.showFooter = false,
    this.footerRoleLabel = 'Customer',
  });

  final Widget child;
  final ScrollController? scrollController;
  final bool grayBackground;
  /// Footer belongs only on shell main tabs (e.g. customer Home, Browse, Bookings).
  /// Keep false on Messages, Profile, and pushed/popup screens.
  final bool showFooter;
  final String footerRoleLabel;

  @override
  Widget build(BuildContext context) {
    final scrollContent = SingleChildScrollView(
      controller: scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: child,
            ),
          ),
          if (showFooter) CachedAppFooter(roleLabel: footerRoleLabel),
        ],
      ),
    );

    return ColoredBox(
      color: grayBackground ? FigmaColors.gray50 : FigmaColors.white,
      child: showFooter
          ? AppScrollChrome(footerClearance: 320, child: scrollContent)
          : scrollContent,
    );
  }
}

/// Visual booking status timeline for customer/provider detail screens.
///
/// Renders a self-contained card (icon + "Status tracker" header) with a
/// horizontal step timeline. Pass [createdAt]/[updatedAt] to show timestamps
/// under the first step and the current step.
class BookingStatusTracker extends StatelessWidget {
  const BookingStatusTracker({
    super.key,
    required this.status,
    this.pendingAt,
    this.acceptedAt,
    this.inProgressAt,
    this.completedAt,
    @Deprecated('Use pendingAt') this.createdAt,
    @Deprecated('Use milestone timestamps') this.updatedAt,
  });

  final String status;
  final DateTime? pendingAt;
  final DateTime? acceptedAt;
  final DateTime? inProgressAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static const _steps = ['Pending', 'Accepted', 'In Progress', 'Milestone complete'];

  int _activeIndex(String s) {
    final lower = s.toLowerCase();
    if (lower == 'cancelled' || lower == 'canceled') return -1;
    if (lower == 'completed' || lower == 'milestone complete') return 3;
    if (lower == 'in progress') return 2;
    if (lower == 'accepted') return 1;
    return 0;
  }

  DateTime? _milestoneForStep(int i) {
    return switch (i) {
      0 => pendingAt ?? createdAt,
      1 => acceptedAt,
      2 => inProgressAt,
      3 => completedAt,
      _ => null,
    };
  }

  String? _timeFor(int i) {
    final at = _milestoneForStep(i);
    if (at == null) return null;
    return DateFormat('MMM d, h:mm a').format(at);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    final active = _activeIndex(status);
    final cancelled = active < 0;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: role.tint, borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.show_chart_rounded, size: 18, color: role.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Status tracker',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cancelled)
            Row(
              children: [
                const Icon(Icons.cancel_outlined, color: FigmaColors.red600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This booking was cancelled.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.gray800),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: _TimelineStep(
                      label: _steps[i],
                      time: _timeFor(i),
                      reached: i <= active,
                      isCurrent: i == active,
                      showLeftLine: i > 0,
                      showRightLine: i < _steps.length - 1,
                      leftLineReached: i <= active,
                      rightLineReached: (i + 1) <= active,
                      primary: role.primary,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.time,
    required this.reached,
    required this.isCurrent,
    required this.showLeftLine,
    required this.showRightLine,
    required this.leftLineReached,
    required this.rightLineReached,
    required this.primary,
  });

  final String label;
  final String? time;
  final bool reached;
  final bool isCurrent;
  final bool showLeftLine;
  final bool showRightLine;
  final bool leftLineReached;
  final bool rightLineReached;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final labelColor = isCurrent
        ? primary
        : (reached ? FigmaColors.gray900 : FigmaColors.gray500);

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _line(showLeftLine, leftLineReached)),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: reached ? primary : FigmaColors.gray100,
                shape: BoxShape.circle,
                border: reached ? null : Border.all(color: FigmaColors.gray300, width: 2),
              ),
              child: reached
                  ? const Icon(Icons.check_rounded, size: 18, color: FigmaColors.white)
                  : null,
            ),
            Expanded(child: _line(showRightLine, rightLineReached)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: labelColor),
        ),
        if (time != null) ...[
          const SizedBox(height: 2),
          Text(
            time!,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
          ),
        ],
      ],
    );
  }

  Widget _line(bool show, bool reached) {
    return Container(
      height: 3,
      color: show ? (reached ? primary : FigmaColors.gray200) : Colors.transparent,
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: destructive ? FigmaColors.red600 : role.primary,
        foregroundColor: FigmaColors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      icon: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white))
          : Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
      label: Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}
