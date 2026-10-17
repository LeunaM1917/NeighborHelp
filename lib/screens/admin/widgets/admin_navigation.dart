import 'package:flutter/material.dart';

import '../../../widgets/workspace_navigation_rail.dart';

/// These indices intentionally match AdminShell's existing IndexedStack.
const adminNavigationItems = [
  WorkspaceNavigationItem(
    label: 'Overview',
    shortLabel: 'Home',
    icon: Icons.dashboard_outlined,
    index: 0,
  ),
  WorkspaceNavigationItem(
    label: 'People',
    icon: Icons.people_outline,
    children: [
      WorkspaceNavigationItem(
        label: 'Customers',
        icon: Icons.people_outline,
        index: 1,
      ),
      WorkspaceNavigationItem(
        label: 'Providers',
        icon: Icons.engineering_outlined,
        index: 2,
      ),
    ],
  ),
  WorkspaceNavigationItem(
    label: 'Trust & safety',
    shortLabel: 'Trust',
    icon: Icons.verified_user_outlined,
    children: [
      WorkspaceNavigationItem(
        label: 'User Reports',
        icon: Icons.flag_outlined,
        index: 3,
      ),
      WorkspaceNavigationItem(
        label: 'Verification',
        icon: Icons.verified_user_outlined,
        index: 4,
      ),
      WorkspaceNavigationItem(
        label: 'Certificates',
        icon: Icons.workspace_premium_outlined,
        index: 5,
      ),
    ],
  ),
  WorkspaceNavigationItem(
    label: 'Marketplace',
    shortLabel: 'Work',
    icon: Icons.storefront_outlined,
    children: [
      WorkspaceNavigationItem(
        label: 'Services',
        icon: Icons.home_repair_service_outlined,
        index: 6,
      ),
      WorkspaceNavigationItem(
        label: 'Bookings',
        icon: Icons.event_note_outlined,
        index: 7,
      ),
    ],
  ),
  WorkspaceNavigationItem(
    label: 'Insights',
    icon: Icons.bar_chart_outlined,
    children: [
      WorkspaceNavigationItem(
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        index: 8,
      ),
      WorkspaceNavigationItem(
        label: 'Activity',
        icon: Icons.history_outlined,
        index: 9,
      ),
      WorkspaceNavigationItem(
        label: 'Ranking',
        icon: Icons.leaderboard_outlined,
        index: 11,
      ),
    ],
  ),
  WorkspaceNavigationItem(
    label: 'Manage',
    shortLabel: 'More',
    icon: Icons.tune_rounded,
    children: [
      WorkspaceNavigationItem(
        label: 'Notifications',
        icon: Icons.campaign_outlined,
        index: 10,
      ),
      WorkspaceNavigationItem(
        label: 'Settings',
        icon: Icons.settings_outlined,
        index: 12,
      ),
    ],
  ),
];

class AdminNavigation extends StatelessWidget {
  const AdminNavigation({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.compact = false,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) => compact
      ? WorkspaceNavigationBar(
          items: adminNavigationItems,
          currentIndex: currentIndex,
          onSelect: onSelect,
        )
      : WorkspaceNavigationRail(
          items: adminNavigationItems,
          currentIndex: currentIndex,
          onSelect: onSelect,
        );
}
