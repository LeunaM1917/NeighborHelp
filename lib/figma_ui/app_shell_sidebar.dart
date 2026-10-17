import 'package:flutter/material.dart';

import '../widgets/workspace_navigation_rail.dart';
import 'app_shell_tab.dart';

/// Customer and provider destinations use the same slim desktop rail.
class AppShellSidebar extends StatelessWidget {
  const AppShellSidebar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    required this.roleBadge,
    this.iconBuilder,
    this.account,
    this.bottomActions,
  });

  static const double width = WorkspaceNavigationRail.width;

  final List<AppShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final String roleBadge;
  final Widget Function(int index, bool selected)? iconBuilder;
  final Widget? account;
  final Widget? bottomActions;

  @override
  Widget build(BuildContext context) => WorkspaceNavigationRail(
    items: [
      for (var i = 0; i < tabs.length; i++)
        WorkspaceNavigationItem(
          label: tabs[i].label,
          shortLabel: tabs[i].shortLabel,
          icon: tabs[i].icon,
          selectedIcon: tabs[i].selectedIcon,
          index: i,
        ),
    ],
    currentIndex: currentIndex,
    onSelect: onTabChanged,
    iconBuilder: iconBuilder,
    account: account,
    bottomActions: bottomActions,
  );
}
