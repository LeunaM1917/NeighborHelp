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
import 'figma_colors.dart';
import 'figma_marketing_assets.dart';
import '../widgets/app_scroll_chrome.dart';
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
  /// Notification bell and help icon in the top bar (customer & provider).
  final bool showUtilityActions;
  /// Active tab scroll (back-to-top FAB + re-tap tab).
  final ScrollController? scrollController;
  /// Bottom-nav index for Messages — shows unread badge when set.
  final int? messagesTabIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wide = AdaptiveBreakpoints.isExpanded(context);
    final mobile = MobileLayout.useMobileChrome(context);
    final native = MobileLayout.isNativeApp(context);

    return ColoredBox(
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: native,
        bottom: false,
        child: Column(
          children: [
            _AppShellTopBar(
            tabs: tabs,
            currentIndex: currentIndex,
            onTabChanged: onTabChanged,
            roleBadge: roleBadge,
            appUser: appUser,
            onSignOut: onSignOut,
            showNavLinks: wide,
            showUtilityActions: showUtilityActions,
            compact: mobile,
          ),
          Expanded(
            child: AppShellScrollChrome(
              scrollController: scrollController,
              child: child,
            ),
          ),
          if (!wide)
            _ShellBottomNav(
              tabs: tabs,
              currentIndex: currentIndex,
              onTabChanged: onTabChanged,
              useShortLabels: mobile,
              appUserId: appUser.userId,
              messagesTabIndex: messagesTabIndex,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppShellTopBar extends StatelessWidget {
  const _AppShellTopBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    required this.roleBadge,
    required this.appUser,
    required this.onSignOut,
    required this.showNavLinks,
    required this.showUtilityActions,
    required this.compact,
  });

  final List<AppShellTab> tabs;
  final int currentIndex;
  final AppShellNavigate onTabChanged;
  final String roleBadge;
  final AppUser appUser;
  final VoidCallback onSignOut;
  final bool showNavLinks;
  final bool showUtilityActions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barHeight = compact ? 52.0 : 64.0;
    final native = MobileLayout.isNativeApp(context);
    final showRoleBadge = showNavLinks || compact;

    return Material(
      color: colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outline)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final outerWidth = constraints.maxWidth;
              final pad = outerWidth >= 1024 ? 32.0 : outerWidth >= 640 ? 24.0 : 16.0;
              final contentWidth = (outerWidth - 2 * pad).clamp(0.0, 1280.0);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: contentWidth,
                    height: barHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FigmaBrandRow(
                                  logoHeight: compact ? (native ? 32 : 30) : 44,
                                  titleFontSize: compact ? (native ? 14 : 15) : 18,
                                  logoAssetPath: FigmaMarketingAssets.navLogo,
                                  onTap: () => onTabChanged(0),
                                  constrained: compact,
                                  showTitle: true,
                                ),
                                if (showRoleBadge) ...[
                                  const SizedBox(width: 12),
                                  _RoleBadge(label: roleBadge),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (showNavLinks)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < tabs.length; i++) ...[
                                  if (i > 0) SizedBox(width: compact ? 16 : 28),
                                  _ShellNavLink(
                                    label: tabs[i].label,
                                    active: currentIndex == i,
                                    onTap: () => onTabChanged(i),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showUtilityActions)
                                  _ShellUtilityActions(
                                    appUser: appUser,
                                    roleBadge: roleBadge,
                                    compact: compact,
                                  ),
                                _UserMenu(appUser: appUser, onSignOut: onSignOut),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTabChanged(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (messagesTabIndex != null && i == messagesTabIndex && appUserId != null)
                            StreamBuilder<int>(
                              stream: FirestoreService().unreadMessageCountStream(appUserId!),
                              builder: (context, snap) {
                                final unread = snap.data ?? 0;
                                return Badge(
                                  isLabelVisible: unread > 0,
                                  label: Text(unread > 9 ? '9+' : '$unread'),
                                  backgroundColor: rc.primary,
                                  child: Icon(
                                    i == currentIndex ? tabs[i].selectedIcon : tabs[i].icon,
                                    size: 24,
                                    color: i == currentIndex ? rc.primary : FigmaColors.gray600,
                                  ),
                                );
                              },
                            )
                          else
                            Icon(
                              i == currentIndex ? tabs[i].selectedIcon : tabs[i].icon,
                              size: 24,
                              color: i == currentIndex ? rc.primary : FigmaColors.gray600,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            tabs[i].navLabel(compact: useShortLabels),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w500,
                              color: i == currentIndex ? rc.primary : FigmaColors.gray600,
                            ),
                          ),
                        ],
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

class _ShellNavLink extends StatefulWidget {
  const _ShellNavLink({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ShellNavLink> createState() => _ShellNavLinkState();
}

class _ShellNavLinkState extends State<_ShellNavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    final on = widget.active;
    final hovered = _hover && !on;
    final fg = on ? role.primary : (hovered ? role.primary : FigmaColors.gray700);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: FigmaColors.gray100.withValues(alpha: 0.75),
          splashColor: role.tint.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 3,
                    child: on
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: role.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          )
                        : const SizedBox.shrink(),
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

class _ShellUtilityActions extends StatefulWidget {
  const _ShellUtilityActions({
    required this.appUser,
    required this.roleBadge,
    this.compact = false,
  });

  final AppUser appUser;
  final String roleBadge;
  final bool compact;

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

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: _helpKey,
              tooltip: 'Help',
              visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
              constraints: iconConstraints,
              padding: compact ? EdgeInsets.zero : null,
              onPressed: () {
                NotificationsPopover.hide();
                HelpSupportPopover.toggle(
                  context,
                  anchorKey: _helpKey,
                  roleLabel: widget.roleBadge,
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
                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                constraints: iconConstraints,
                padding: compact ? EdgeInsets.zero : null,
                onPressed: () {
                  HelpSupportPopover.hide();
                  NotificationsPopover.toggle(
                    context,
                    anchorKey: _bellKey,
                    appUser: widget.appUser,
                  );
                },
                icon: Icon(
                  unread > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
                  size: compact ? 22 : 24,
                  color: unread > 0 ? role.primary : colorScheme.onSurfaceVariant,
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
    final border = isProvider ? FigmaColors.gray200 : role.primary.withValues(alpha: 0.25);

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
  const _UserMenu({required this.appUser, required this.onSignOut});

  final AppUser appUser;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final role = context.roleColors;
    final initials = _initials(appUser.fullName);

    final compact = MobileLayout.useMobileChrome(context);

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
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              Text(
                appUser.email,
                style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
      ],
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 2 : 8, right: compact ? 0 : 8, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: compact ? 13 : 16,
              backgroundColor: role.tint,
              backgroundImage: appUser.profilePhotoUrl != null ? NetworkImage(appUser.profilePhotoUrl!) : null,
              child: appUser.profilePhotoUrl == null
                  ? Text(
                      initials,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: role.primary),
                    )
                  : null,
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant, size: 20),
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
