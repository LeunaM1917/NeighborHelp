import 'package:flutter/material.dart';

import '../../figma_ui/app_shell_layout.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/app_shell_tab.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_shell_tab_scroll.dart';
import '../shared/messages_hub.dart';
import 'provider_profile_tab.dart';
import 'tabs/provider_dashboard_tab.dart';
import 'tabs/provider_messages_tab.dart';
import 'tabs/provider_jobs_tab.dart';
import 'tabs/provider_services_tab.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.appUser, required this.auth});

  final AppUser appUser;
  final AuthService auth;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _tab = 0;
  late final AppShellTabScroll _tabScroll;
  static const _messagesTabIndex = 3;

  void _activateMessagesTab() {
    if (mounted) setState(() => _tab = _messagesTabIndex);
  }

  @override
  void initState() {
    super.initState();
    _tabScroll = AppShellTabScroll(5);
    MessagesHub.shellMessagesActivator = _activateMessagesTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFooterCache.ensurePrecached(context);
    });
  }

  @override
  void dispose() {
    if (MessagesHub.shellMessagesActivator == _activateMessagesTab) {
      MessagesHub.shellMessagesActivator = null;
    }
    _tabScroll.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index == _tab) {
      _tabScroll.scrollToTop(index);
      return;
    }
    setState(() => _tab = index);
  }

  static const _tabs = [
    AppShellTab(
      label: 'Dashboard',
      shortLabel: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    AppShellTab(
      label: 'Services',
      shortLabel: 'Services',
      icon: Icons.home_repair_service_outlined,
      selectedIcon: Icons.home_repair_service_rounded,
    ),
    AppShellTab(
      label: 'Jobs',
      shortLabel: 'Jobs',
      icon: Icons.work_outline,
      selectedIcon: Icons.work_rounded,
    ),
    AppShellTab(
      label: 'Messages',
      shortLabel: 'Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble_rounded,
    ),
    AppShellTab(
      label: 'Profile',
      shortLabel: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RoleThemeScope(
      palette: RoleTheme.provider,
      child: Scaffold(
        body: AppShellLayout(
        tabs: _tabs,
        currentIndex: _tab,
        onTabChanged: _onTabChanged,
        scrollController: _tabScroll.controllerFor(_tab),
        appUser: widget.appUser,
        roleBadge: 'Provider',
        onSignOut: () => widget.auth.signOut(),
        messagesTabIndex: _messagesTabIndex,
        child: IndexedStack(
          index: _tab,
          children: [
            ProviderDashboardTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(0),
              onNavigateToTab: (i) => setState(() => _tab = i),
            ),
            ProviderServicesTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(1),
              onNavigateToTab: (i) => setState(() => _tab = i),
            ),
            ProviderJobsTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(2),
              onNavigateToTab: (i) => setState(() => _tab = i),
            ),
            ProviderMessagesTab(appUser: widget.appUser),
            ProviderProfileTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(4),
              onNavigateToTab: (i) => setState(() => _tab = i),
              onSignOut: () => widget.auth.signOut(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
