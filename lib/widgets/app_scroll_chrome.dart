import 'package:flutter/material.dart';

import '../figma_ui/figma_colors.dart';
import '../theme/adaptive_breakpoints.dart';
import '../theme/mobile_layout.dart';
import '../theme/role_theme.dart';

/// Back-to-top overlay for scrollable pages (marketing site, app shell, pushed routes).
class AppScrollChrome extends StatefulWidget {
  const AppScrollChrome({
    super.key,
    required this.child,
    this.scrollController,
    this.accentColor,
    this.bottomInset,
    this.footerClearance = 300,
    this.showBackToTop = false,
  });

  final Widget child;
  final ScrollController? scrollController;
  final Color? accentColor;
  /// Space above bottom edge (e.g. mobile bottom nav). Defaults by breakpoint.
  final double? bottomInset;
  final double footerClearance;
  /// When false, no scroll-to-top FAB (dialogs, pushed routes, marketing).
  final bool showBackToTop;

  @override
  State<AppScrollChrome> createState() => _AppScrollChromeState();
}

/// App shell tabs (customer / provider / admin main area).
class AppShellScrollChrome extends StatelessWidget {
  const AppShellScrollChrome({super.key, required this.child, this.scrollController});

  final Widget child;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return AppScrollChrome(
      scrollController: scrollController,
      showBackToTop: !MobileLayout.isNativeApp(context),
      child: child,
    );
  }
}

class _ScrollChromeFabState {
  _ScrollChromeFabState(this.show, this.nearBottom);

  final bool show;
  final bool nearBottom;

  @override
  bool operator ==(Object other) =>
      other is _ScrollChromeFabState && show == other.show && nearBottom == other.nearBottom;

  @override
  int get hashCode => Object.hash(show, nearBottom);
}

class _AppScrollChromeState extends State<AppScrollChrome> {
  final _fabState = ValueNotifier(_ScrollChromeFabState(false, false));
  BuildContext? _scrollContext;

  static const _showAfterScroll = 280.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onControllerScroll);
  }

  @override
  void didUpdateWidget(AppScrollChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onControllerScroll);
      widget.scrollController?.addListener(_onControllerScroll);
    }
    if (!widget.showBackToTop && _fabState.value.show) {
      _fabState.value = _ScrollChromeFabState(false, false);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onControllerScroll);
    _fabState.dispose();
    super.dispose();
  }

  void _onControllerScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    _applyMetrics(controller.position);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (widget.scrollController != null) return false;
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    if (!metrics.hasContentDimensions) return false;
    _scrollContext = notification.context;
    _applyMetrics(metrics);
    return false;
  }

  void _applyMetrics(ScrollMetrics metrics) {
    if (!widget.showBackToTop) return;
    final nearBottom = metrics.maxScrollExtent > 0 && metrics.pixels >= metrics.maxScrollExtent - 64;
    final show = metrics.pixels > _showAfterScroll;
    final next = _ScrollChromeFabState(show, nearBottom);
    if (next == _fabState.value) return;
    _fabState.value = next;
  }

  void _scrollToTop() {
    final controller = widget.scrollController;
    if (controller != null && controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final ctx = _scrollContext;
    if (ctx == null) return;
    final position = Scrollable.maybeOf(ctx)?.position;
    if (position != null && position.hasPixels) {
      position.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double _fabBottom(BuildContext context, bool nearBottom) {
    final wide = AdaptiveBreakpoints.isExpanded(context);
    final base = widget.bottomInset ?? (wide ? 28.0 : 92.0);
    final footerPad = MobileLayout.hideMarketingFooter(context) ? 24.0 : widget.footerClearance;
    if (nearBottom) return base + footerPad;
    return base;
  }

  Color _accent(BuildContext context) {
    return widget.accentColor ?? context.roleColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (widget.showBackToTop)
            ValueListenableBuilder<_ScrollChromeFabState>(
              valueListenable: _fabState,
              builder: (context, state, _) {
                if (!state.show) return const SizedBox.shrink();
                return Positioned(
                  right: 24,
                  bottom: _fabBottom(context, state.nearBottom),
                  child: _BackToTopButton(
                    primary: _accent(context),
                    onPressed: _scrollToTop,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BackToTopButton extends StatelessWidget {
  const _BackToTopButton({required this.primary, required this.onPressed});

  final Color primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      color: FigmaColors.white,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primary.withValues(alpha: 0.35)),
          ),
          child: Icon(Icons.keyboard_arrow_up_rounded, color: primary, size: 28),
        ),
      ),
    );
  }
}
