import 'package:flutter/material.dart';

import '../theme/mobile_layout.dart';

/// Keeps the rail fixed while page content scrolls inside a rounded workspace.
class WorkspacePageFrame extends StatelessWidget {
  const WorkspacePageFrame({
    super.key,
    required this.wide,
    required this.rail,
    required this.header,
    required this.child,
    this.bottomNavigation,
    this.footer,
    this.scrollController,
  });

  final bool wide;
  final Widget rail;
  final Widget header;
  final Widget child;
  final Widget? bottomNavigation;
  final Widget? footer;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: SafeArea(
      top: MobileLayout.isNativeApp(context),
      bottom: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) rail,
          Expanded(
            key: const ValueKey('workspace-main'),
            child: Padding(
              padding: wide
                  ? const EdgeInsets.fromLTRB(0, 8, 8, 8)
                  : EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(wide ? 28 : 0),
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      header,
                      Expanded(
                        key: const ValueKey('workspace-content'),
                        child: _WorkspaceScrollArea(
                          scrollController: scrollController,
                          footer: wide ? footer : null,
                          child: child,
                        ),
                      ),
                      if (!wide && bottomNavigation != null) bottomNavigation!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Reveals the shared footer only at the end of the active page's scroll.
class _WorkspaceScrollArea extends StatefulWidget {
  const _WorkspaceScrollArea({
    required this.child,
    this.footer,
    this.scrollController,
  });

  final Widget child;
  final Widget? footer;
  final ScrollController? scrollController;

  @override
  State<_WorkspaceScrollArea> createState() => _WorkspaceScrollAreaState();
}

class _WorkspaceScrollAreaState extends State<_WorkspaceScrollArea> {
  final _footerKey = GlobalKey();
  bool _showFooter = false;
  bool _updateScheduled = false;
  ScrollMetrics? _notificationMetrics;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_scheduleUpdate);
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(_WorkspaceScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_scheduleUpdate);
      widget.scrollController?.addListener(_scheduleUpdate);
      _notificationMetrics = null;
      _showFooter = false;
    }
    _scheduleUpdate();
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_scheduleUpdate);
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      final controller = widget.scrollController;
      final metrics = controller == null
          ? _notificationMetrics
          : controller.hasClients
          ? controller.position
          : null;
      final footerHeight = _showFooter
          ? (_footerKey.currentContext?.size?.height ?? 0.0)
          : 0.0;
      // Revealing the footer shortens the viewport. Account for its height so
      // that this layout change does not immediately hide it again.
      final show =
          widget.footer != null &&
          metrics != null &&
          metrics.hasContentDimensions &&
          metrics.axis == Axis.vertical &&
          metrics.extentAfter <= footerHeight + 1;
      if (show != _showFooter) setState(() => _showFooter = show);
    });
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            _notificationMetrics = notification.metrics;
            _scheduleUpdate();
          }
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) {
              _notificationMetrics = notification.metrics;
              _scheduleUpdate();
            }
            return false;
          },
          child: Column(
            children: [
              Expanded(child: widget.child),
              if (widget.footer != null)
                Offstage(
                  offstage: !_showFooter,
                  child: KeyedSubtree(key: _footerKey, child: widget.footer!),
                ),
            ],
          ),
        ),
      );
}
