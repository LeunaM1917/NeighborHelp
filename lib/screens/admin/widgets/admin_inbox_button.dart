import 'package:flutter/material.dart';
import '../../../models/app_user.dart';
import '../../shared/notifications_popover.dart';

/// Administrator entry into the same notification menu as other roles.
class AdminInboxButton extends StatelessWidget {
  const AdminInboxButton({
    super.key,
    required this.appUser,
    required this.onNavigate,
    this.openBesideAnchor = false,
  });
  final AppUser appUser;
  final ValueChanged<int> onNavigate;
  final bool openBesideAnchor;
  @override
  Widget build(BuildContext context) => NotificationBell(
    appUser: appUser,
    onSelectTab: onNavigate,
    openBesideAnchor: openBesideAnchor,
  );
}
