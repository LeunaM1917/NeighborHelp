import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/figma_layout.dart';
import '../../figma_ui/figma_marketing_assets.dart';
import '../../figma_ui/widgets/figma_brand_row.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_scroll_chrome.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final auth = widget.auth;

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: Column(
        children: [
          _AdminTopBar(
            appUser: widget.appUser,
            firestoreConnected: !auth.isLocalAdminOnly,
            onSignOut: () => auth.signOut(),
          ),
          Expanded(
            child: Row(
              children: [
                if (wide)
                  _AdminSideNav(
                    tabs: _tabs,
                    selectedIndex: _tab,
                    onSelect: _selectTab,
                  ),
                Expanded(
                  child: AppScrollChrome(
                    showBackToTop: true,
                    scrollController: _tabScroll.controllerFor(_tab),
                    child: ClipRect(
                      child: IndexedStack(
                        index: _tab,
                        sizing: StackFit.expand,
                        children: [
                          _adminTabScope(
                            0,
                            AdminOverviewPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
                          ),
                          _adminTabScope(
                            1,
                            AdminCustomersPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
                          ),
                          _adminTabScope(
                            2,
                            AdminProvidersPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
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
                          _adminTabScope(
                            5,
                            AdminCertificatesPage(auth: auth),
                          ),
                          _adminTabScope(
                            6,
                            AdminServicesPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
                          ),
                          _adminTabScope(
                            7,
                            AdminBookingsPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
                          ),
                          _adminTabScope(
                            8,
                            AdminReportsPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
                          ),
                          _adminTabScope(
                            9,
                            AdminActivityPage(
                              auth: auth,
                              onNavigateToTab: _selectTab,
                            ),
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
              ],
            ),
          ),
          if (!wide)
            Material(
              color: colorScheme.surface,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_tabs[i].label),
                            selected: _tab == i,
                            onSelected: (_) => _selectTab(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.appUser,
    required this.firestoreConnected,
    required this.onSignOut,
  });

  final AppUser appUser;
  final bool firestoreConnected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outline)),
        ),
        child: FigmaWideContainer(
          child: LayoutBuilder(
            builder: (context, c) {
              final showName = c.maxWidth >= 720;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: FigmaBrandRow(
                              logoHeight: 40,
                              titleFontSize: 17,
                              logoAssetPath: FigmaMarketingAssets.navLogo,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: FigmaColors.tintBlue,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: FigmaColors.gray200),
                            ),
                            child: Text(
                              'Admin Console',
                              style: GoogleFonts.inter(
                                color: FigmaColors.navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!firestoreConnected) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Preview only',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.notifications_outlined, size: 22),
                              tooltip: 'Notifications',
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: FigmaColors.red600,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (showName)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                appUser.fullName,
                                style: GoogleFonts.inter(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        PopupMenuButton<String>(
                          offset: const Offset(0, 8),
                          tooltip: 'Account menu',
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (value) {
                            if (value != 'signout') return;
                            // Wait for the menu overlay to close before sign-out rebuilds the tree.
                            WidgetsBinding.instance.addPostFrameCallback((_) => onSignOut());
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'signout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 20, color: colorScheme.onSurface),
                                  const SizedBox(width: 10),
                                  Text('Sign out', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: FigmaColors.navy,
                            child: Text(
                              _initials(appUser.fullName),
                              style: GoogleFonts.inter(
                                color: FigmaColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminSideNav extends StatelessWidget {
  const _AdminSideNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_AdminTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: const BoxDecoration(
        color: FigmaColors.white,
        border: Border(right: BorderSide(color: FigmaColors.gray200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'PLATFORM MANAGEMENT',
                  style: GoogleFonts.inter(
                    color: FigmaColors.gray500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < tabs.length; i++)
                  _AdminNavTile(
                    tab: tabs[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: FigmaColors.gray50,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.headset_mic_outlined, color: FigmaColors.gray600, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need help?',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Contact support',
                              style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({required this.tab, required this.selected, required this.onTap});

  final _AdminTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? FigmaColors.tintGreen : Colors.transparent;
    final fg = selected ? FigmaColors.green : FigmaColors.gray600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(tab.icon, color: fg, size: 20),
                const SizedBox(width: 12),
                Text(
                  tab.label,
                  style: GoogleFonts.inter(
                    color: fg,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'A';
  if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : 'A';
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _AdminTab {
  const _AdminTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
