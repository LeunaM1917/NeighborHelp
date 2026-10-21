import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scroll_chrome.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/workspace_page_frame.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/role_theme.dart';
import 'widgets/admin_navigation.dart';
import '../../widgets/app_shell_tab_scroll.dart';
import 'widgets/admin_widgets.dart';
import 'pages/admin_activity_page.dart';
import 'pages/admin_bookings_page.dart';
import 'pages/admin_customers_page.dart';
import 'pages/admin_overview_page.dart';
import 'pages/admin_providers_page.dart';
import 'pages/admin_reports_page.dart';
import 'pages/admin_user_reports_page.dart';
import 'pages/admin_services_page.dart';
import 'pages/admin_notifications_page.dart';
import 'pages/admin_settings_page.dart';
import 'pages/admin_certificates_page.dart';
import 'pages/admin_recommendation_ranking_page.dart';
import 'pages/admin_verification_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.appUser, required this.auth});

  final AppUser appUser;
  final AuthService auth;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  late final AppShellTabScroll _tabScroll;

  static const _tabs = <_AdminTab>[
    _AdminTab('Overview', Icons.dashboard_outlined),
    _AdminTab('Customers', Icons.people_outline),
    _AdminTab('Providers', Icons.engineering_outlined),
    _AdminTab('User Reports', Icons.flag_outlined),
    _AdminTab('Verification', Icons.verified_user_outlined),
    _AdminTab('Certificates', Icons.workspace_premium_outlined),
    _AdminTab('Services', Icons.home_repair_service_outlined),
    _AdminTab('Bookings', Icons.event_note_outlined),
    _AdminTab('Reports', Icons.bar_chart_outlined),
    _AdminTab('Activity', Icons.history_outlined),
    _AdminTab('Notifications', Icons.campaign_outlined),
    _AdminTab('Ranking', Icons.leaderboard_outlined),
    _AdminTab('Settings', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabScroll = AppShellTabScroll(_tabs.length);
  }

  @override
  void dispose() {
    _tabScroll.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _tab) {
      _tabScroll.scrollToTop(index);
      return;
    }
    setState(() => _tab = index);
  }

  /// One scroll controller per tab — [IndexedStack] keeps every tab mounted.
  Widget _adminTabScope(int tabIndex, Widget child) {
    return AdminShellScrollScope(
      scrollController: _tabScroll.controllerFor(tabIndex),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide =
        !MobileLayout.isNativeApp(context) &&
        MediaQuery.sizeOf(context).width >= 900;
    final auth = widget.auth;

    return RoleThemeScope(
      palette: RoleTheme.admin,
      child: Scaffold(
        body: WorkspacePageFrame(
          wide: wide,
          scrollController: _tabScroll.controllerFor(_tab),
          rail: AdminNavigation(currentIndex: _tab, onSelect: _selectTab),
          header: _AdminTopBar(
            title: _tabs[_tab].label,
            appUser: widget.appUser,
            firestoreConnected: !auth.isLocalAdminOnly,
            onSignOut: () => auth.signOut(),
            onNotificationsTap: () => _selectTab(10),
          ),
          footer: const AppFooter(roleLabel: 'Admin'),
          bottomNavigation: AdminNavigation(
            currentIndex: _tab,
            onSelect: _selectTab,
            compact: true,
          ),
          child: AppScrollChrome(
            showBackToTop: true,
            footerClearance: 0,
            scrollController: _tabScroll.controllerFor(_tab),
            child: ClipRect(
              child: IndexedStack(
                index: _tab,
                sizing: StackFit.expand,
                children: [
                  _adminTabScope(
                    0,
                    AdminOverviewPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(
                    1,
                    AdminCustomersPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(
                    2,
                    AdminProvidersPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(
                    3,
                    AdminUserReportsPage(
                      auth: auth,
                      onNavigateToTab: _selectTab,
                    ),
                  ),
                  _adminTabScope(
                    4,
                    AdminVerificationPage(
                      auth: auth,
                      reviewerUserId: widget.appUser.userId,
                    ),
                  ),
                  _adminTabScope(5, AdminCertificatesPage(auth: auth)),
                  _adminTabScope(
                    6,
                    AdminServicesPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(
                    7,
                    AdminBookingsPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(
                    8,
                    AdminReportsPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(
                    9,
                    AdminActivityPage(auth: auth, onNavigateToTab: _selectTab),
                  ),
                  _adminTabScope(10, AdminNotificationsPage(auth: auth)),
                  _adminTabScope(
                    11,
                    AdminRecommendationRankingPage(auth: auth),
                  ),
                  _adminTabScope(
                    12,
                    AdminSettingsPage(
                      auth: auth,
                      appUser: widget.appUser,
                      onNavigateToTab: _selectTab,
                    ),
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

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.appUser,
    required this.firestoreConnected,
    required this.onSignOut,
    required this.onNotificationsTap,
  });

  final String title;
  final AppUser appUser;
  final bool firestoreConnected;
  final VoidCallback onSignOut;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!firestoreConnected)
                  Text('Preview only', style: GoogleFonts.inter(fontSize: 10)),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 600)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Admin Console',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: FigmaColors.gray600,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_outlined, size: 22),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'signout') {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => onSignOut(),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(appUser.fullName),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'signout',
                child: Text('Sign out'),
              ),
            ],
            child: CircleAvatar(
              radius: 16,
              backgroundColor: FigmaColors.navy,
              child: Text(
                _initials(appUser.fullName),
                style: GoogleFonts.inter(
                  color: FigmaColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) {
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'A';
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _AdminTab {
  const _AdminTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
