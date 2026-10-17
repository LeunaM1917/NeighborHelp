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
  });

  final bool wide;
  final Widget rail;
  final Widget header;
  final Widget child;
  final Widget? bottomNavigation;
  final Widget? footer;

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
                        child: child,
                      ),
                      if (wide && footer != null) footer!,
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
