import 'package:flutter/material.dart';

import '../../figma_ui/app_shell_layout.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/app_shell_tab.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_footer.dart';
import '../../widgets/app_shell_tab_scroll.dart';
import '../../widgets/app_shell_tab_storage.dart';
import '../shared/messages_hub.dart';
import 'tabs/customer_bookings_tab.dart';
import 'tabs/customer_browse_tab.dart';
import 'tabs/customer_home_tab.dart';
import 'tabs/customer_messages_tab.dart';
import 'customer_profile_tab.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.appUser, required this.auth});

  final AppUser appUser;
  final AuthService auth;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  static final _tabKey = AppShellTabStorage.keyForRole('customer');
  late int _tab;
  late final AppShellTabScroll _tabScroll;
  static const _messagesTabIndex = 3;
  static const _tabs = [
    AppShellTab(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    AppShellTab(label: 'Browse', icon: Icons.search_outlined, selectedIcon: Icons.search_rounded),
    AppShellTab(label: 'Bookings', icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded),
    AppShellTab(label: 'Messages', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble_rounded),
    AppShellTab(label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person_rounded),
  ];

  void _setTab(int index) {
    AppShellTabStorage.write(context, _tabKey, index);
    setState(() => _tab = index);
  }

  void _activateMessagesTab() {
    if (mounted) _setTab(_messagesTabIndex);
  }

  @override
  void initState() {
    super.initState();
    _tab = AppShellTabStorage.read(context, _tabKey);
    _tabScroll = AppShellTabScroll(_tabs.length);
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

  @override
  Widget build(BuildContext context) {
    return RoleThemeScope(
      palette: RoleTheme.customer,
      child: Scaffold(
        body: AppShellLayout(
        tabs: _tabs,
        currentIndex: _tab,
        onTabChanged: _onTabChanged,
        scrollController: _tabScroll.controllerFor(_tab),
        appUser: widget.appUser,
        roleBadge: 'Customer',
        onSignOut: () => widget.auth.signOut(),
        messagesTabIndex: _messagesTabIndex,
        child: IndexedStack(
          index: _tab,
          children: [
            CustomerHomeTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(0),
              onBrowseTap: () => _setTab(1),
              onBookingsTap: () => _setTab(2),
            ),
            CustomerBrowseTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(1),
            ),
            CustomerBookingsTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(2),
            ),
            CustomerMessagesTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(3),
            ),
            CustomerProfileTab(
              appUser: widget.appUser,
              scrollController: _tabScroll.controllerFor(4),
              onBrowseTap: () => _setTab(1),
              onBookingsTap: () => _setTab(2),
              onSignOut: () => widget.auth.signOut(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
