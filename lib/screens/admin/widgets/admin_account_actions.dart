import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import 'admin_inbox_button.dart';

class AdminAccountActions extends StatelessWidget {
  const AdminAccountActions({
    super.key,
    required this.appUser,
    required this.onNotificationsTap,
    required this.onSignOut,
    this.vertical = false,
    this.onAdminNotificationSelected,
  });

  final AppUser appUser;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSignOut;
  final bool vertical;
  final ValueChanged<int>? onAdminNotificationSelected;

  @override
  Widget build(BuildContext context) {
    final parts = appUser.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'A'
        : parts.length == 1
        ? parts.first[0].toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    final children = <Widget>[
      if (onAdminNotificationSelected != null) AdminInboxButton(appUser: appUser, onNavigate: onAdminNotificationSelected!) else IconButton(
        tooltip: 'Notifications',
        onPressed: onNotificationsTap,
        icon: const Icon(Icons.notifications_outlined, size: 22),
      ),
      if (vertical) const SizedBox(height: 8),
      PopupMenuButton<String>(
        tooltip: 'Account menu',
        onSelected: (value) {
          if (value == 'signout') {
            WidgetsBinding.instance.addPostFrameCallback((_) => onSignOut());
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              appUser.fullName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'signout',
            child: Text('Sign out'),
          ),
        ],
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: CircleAvatar(
              radius: 16,
              backgroundColor: FigmaColors.navy,
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  color: FigmaColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
