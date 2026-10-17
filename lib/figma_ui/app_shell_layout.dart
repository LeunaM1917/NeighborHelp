import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_user.dart';
import '../screens/shared/help_support_popover.dart';
import '../screens/shared/notifications_popover.dart';
import '../services/firestore_service.dart';
import '../theme/adaptive_breakpoints.dart';
import '../theme/mobile_layout.dart';
import '../theme/role_theme.dart';
import 'app_shell_tab.dart';
import 'app_shell_sidebar.dart';
import 'figma_colors.dart';
import 'figma_marketing_assets.dart';
import '../widgets/app_scroll_chrome.dart';
import '../widgets/app_footer.dart';
import '../widgets/workspace_page_frame.dart';
import 'widgets/figma_brand_row.dart';

typedef AppShellNavigate = void Function(int index);

class AppShellLayout extends StatelessWidget {
  const AppShellLayout({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    required this.appUser,
    required this.roleBadge,
    required this.onSignOut,
    required this.child,
    this.showUtilityActions = true,
    this.scrollController,
    this.messagesTabIndex,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final AppShellNavigate onTabChanged;
  final AppUser appUser;
  final String roleBadge;
  final VoidCallback onSignOut;
  final Widget child;

  /// Notification and help actions in the desktop rail or mobile header.
  final bool showUtilityActions;

  /// Active tab scroll (back-to-top FAB + re-tap tab).
  final ScrollController? scrollController;

  /// Navigation index for Messages — shows unread badge when set.
  final int? messagesTabIndex;

  @override
  Widget build(BuildContext context) {
    final native = MobileLayout.isNativeApp(context);
    final wide = !native && AdaptiveBreakpoints.isExpanded(context);
    final mobile = MobileLayout.useMobileChrome(context);

    return WorkspacePageFrame(
      wide: wide,
      rail: AppShellSidebar(
        tabs: tabs,
        currentIndex: currentIndex,
        onTabChanged: onTabChanged,
        roleBadge: roleBadge,
        account: _UserMenu(
          appUser: appUser,
          onSignOut: onSignOut,
          compact: true,
        ),
        bottomActions: showUtilityActions
            ? _ShellUtilityActions(
                appUser: appUser,
                roleBadge: roleBadge,
                vertical: true,
              )
            : null,
        iconBuilder: (index, selected) => _ShellTabIcon(
          tab: tabs[index],
          selected: selected,
          appUserId: appUser.userId,
          showUnread: index == messagesTabIndex,
        ),
      ),
      header: _AppShellTopBar(
        currentTitle: wide ? tabs[currentIndex].label : null,
        onHomeTap: () => onTabChanged(0),
        roleBadge: roleBadge,
        appUser: appUser,
        onSignOut: onSignOut,
        showUtilityActions: showUtilityActions,
        compact: mobile,
        desktop: wide,
      ),
      footer: AppFooter(roleLabel: roleBadge),
      bottomNavigation: _ShellBottomNav(
        tabs: tabs,
        currentIndex: currentIndex,
        onTabChanged: onTabChanged,
        useShortLabels: mobile,
        appUserId: appUser.userId,
        messagesTabIndex: messagesTabIndex,
      ),
      child: AppShellScrollChrome(
        scrollController: scrollController,
        footerClearance: wide ? 0 : 300,
        child: child,
      ),
    );
  }
}

class _AppShellTopBar extends StatelessWidget {
  const _AppShellTopBar({
    required this.currentTitle,
    required this.onHomeTap,
    required this.roleBadge,
    required this.appUser,
    required this.onSignOut,
    required this.showUtilityActions,
    required this.compact,
    required this.desktop,
  });

  final String? currentTitle;
  final VoidCallback onHomeTap;
  final String roleBadge;
  final AppUser appUser;
  final VoidCallback onSignOut;
  final bool showUtilityActions;
  final bool compact;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (desktop) {
      return SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentTitle!,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _RoleBadge(label: roleBadge),
            ],
          ),
        ),
      );
    }

    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outline)),
        ),
        child: SizedBox(
          height: compact ? 56 : 64,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Leave room for help, notifications and account on small phones.
                final showBrandTitle = constraints.maxWidth >= 380;
                return Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 222),
                              child: FigmaBrandRow(
                                logoHeight: compact ? 30 : 36,
                                titleFontSize: compact ? 15 : 18,
                                logoAssetPath: FigmaMarketingAssets.navLogo,
                                onTap: onHomeTap,
                                constrained: true,
                                showTitle: showBrandTitle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RoleBadge(label: roleBadge),
                          if (currentTitle != null) ...[
                            const SizedBox(width: 24),
                            const SizedBox(
                              height: 24,
                              child: VerticalDivider(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                currentTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showUtilityActions)
                      _ShellUtilityActions(
                        appUser: appUser,
                        roleBadge: roleBadge,
                        compact: compact,
                      ),
                    _UserMenu(appUser: appUser, onSignOut: onSignOut),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile bottom nav — [onTabChanged] fires on every tap, including re-tap (scroll-to-top).
class _ShellBottomNav extends StatelessWidget {
  const _ShellBottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    required this.useShortLabels,
    this.appUserId,
    this.messagesTabIndex,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final AppShellNavigate onTabChanged;
  final bool useShortLabels;
  final String? appUserId;
  final int? messagesTabIndex;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final surface = Theme.of(context).colorScheme.surface;

    return Material(
      color: surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == currentIndex,
                      button: true,
                      child: InkWell(
                        onTap: () => onTabChanged(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ShellTabIcon(
                              tab: tabs[i],
                              selected: i == currentIndex,
                              appUserId: appUserId,
                              showUnread: i == messagesTabIndex,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tabs[i].navLabel(compact: useShortLabels),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: i == currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: i == currentIndex
                                    ? rc.primary
                                    : FigmaColors.gray600,
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
        ),
      ),
    );
  }
}

/// Keep unread-message badges identical in desktop and mobile navigation.
class _ShellTabIcon extends StatelessWidget {
  const _ShellTabIcon({
    required this.tab,
    required this.selected,
    required this.showUnread,
    this.appUserId,
  });

  final AppShellTab tab;
  final bool selected;
  final bool showUnread;
  final String? appUserId;

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    final icon = Icon(
      selected ? tab.selectedIcon : tab.icon,
      size: 24,
      color: selected ? role.primary : FigmaColors.gray600,
    );
    if (!showUnread || appUserId == null) return icon;

    return StreamBuilder<int>(
      stream: FirestoreService().unreadMessageCountStream(appUserId!),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 9 ? '9+' : '$unread'),
          backgroundColor: role.primary,
          child: icon,
        );
      },
    );
  }
}

class _ShellUtilityActions extends StatefulWidget {
  const _ShellUtilityActions({
    required this.appUser,
    required this.roleBadge,
    this.compact = false,
    this.vertical = false,
  });

  final AppUser appUser;
  final String roleBadge;
  final bool compact;
  final bool vertical;

  @override
  State<_ShellUtilityActions> createState() => _ShellUtilityActionsState();
}

class _ShellUtilityActionsState extends State<_ShellUtilityActions> {
  final _helpKey = GlobalKey();
  final _bellKey = GlobalKey();

  @override
  void dispose() {
    HelpSupportPopover.hide();
    NotificationsPopover.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = context.roleColors;

    return StreamBuilder(
      stream: FirestoreService().notificationsForUser(widget.appUser.userId),
      builder: (context, snap) {
        final unread = (snap.data ?? []).where((n) => !n.isRead).length;
        final compact = widget.compact;

        final tight = compact && MobileLayout.isNativeApp(context);
        final iconConstraints = tight
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : compact
            ? const BoxConstraints(minWidth: 36, minHeight: 36)
            : const BoxConstraints(minWidth: 48, minHeight: 48);

        return Flex(
          direction: widget.vertical ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: _helpKey,
              tooltip: 'Help',
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              constraints: iconConstraints,
              padding: compact ? EdgeInsets.zero : null,
              onPressed: () {
                NotificationsPopover.hide();
                HelpSupportPopover.toggle(
                  context,
                  anchorKey: _helpKey,
                  roleLabel: widget.roleBadge,
                  openBesideAnchor: widget.vertical,
                );
              },
              icon: Icon(Icons.help_outline_rounded, size: compact ? 22 : 24),
              style: IconButton.styleFrom(
                foregroundColor: FigmaColors.gray700,
                backgroundColor: FigmaColors.gray100,
              ),
            ),
            SizedBox(width: compact ? 0 : 4),
            Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 9 ? '9+' : '$unread'),
              backgroundColor: role.primary,
              child: IconButton(
                key: _bellKey,
                tooltip: 'Notifications',
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                constraints: iconConstraints,
                padding: compact ? EdgeInsets.zero : null,
                onPressed: () {
                  HelpSupportPopover.hide();
                  NotificationsPopover.toggle(
                    context,
                    anchorKey: _bellKey,
                    appUser: widget.appUser,
                    openBesideAnchor: widget.vertical,
                  );
                },
                icon: Icon(
                  unread > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_outlined,
                  size: compact ? 22 : 24,
                  color: unread > 0
                      ? role.primary
                      : colorScheme.onSurfaceVariant,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: FigmaColors.gray700,
                  backgroundColor: unread > 0 ? role.tint : FigmaColors.gray100,
                ),
              ),
            ),
            SizedBox(width: compact ? 4 : 8),
          ],
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    final isProvider = label.toLowerCase() == 'provider';
    final bg = isProvider ? FigmaColors.gray100 : role.tint;
    final fg = isProvider ? FigmaColors.navy : role.primary;
    final border = isProvider
        ? FigmaColors.gray200
        : role.primary.withValues(alpha: 0.25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.appUser,
    required this.onSignOut,
    this.compact = false,
  });

  final AppUser appUser;
  final VoidCallback onSignOut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = context.roleColors;
    final initials = _initials(appUser.fullName);

    final compact = this.compact || MobileLayout.useMobileChrome(context);

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      onSelected: (v) {
        if (v != 'signout') return;
        WidgetsBinding.instance.addPostFrameCallback((_) => onSignOut());
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appUser.fullName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                appUser.email,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
      ],
      child: Padding(
        padding: EdgeInsets.only(
          left: compact ? 2 : 8,
          right: compact ? 0 : 8,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: compact ? 13 : 16,
              backgroundColor: role.tint,
              backgroundImage: appUser.profilePhotoUrl != null
                  ? NetworkImage(appUser.profilePhotoUrl!)
                  : null,
              child: appUser.profilePhotoUrl == null
                  ? Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: role.primary,
                      ),
                    )
                  : null,
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
