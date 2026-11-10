import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../theme/role_theme.dart';
import 'messages_hub.dart';

/// Standalone entry into the same message layout used by both role shells.
class InquiryScreen extends StatelessWidget {
  const InquiryScreen({
    super.key,
    required this.appUser,
    required this.inquiryId,
  });
  final AppUser appUser;
  final String inquiryId;
  @override
  Widget build(BuildContext context) {
    final asCustomer = appUser.role == UserRole.customer;
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RoleThemeScope(
        palette: asCustomer ? RoleTheme.customer : RoleTheme.provider,
        child: MessagesHub(
          appUser: appUser,
          asCustomer: asCustomer,
          initialInquiryId: inquiryId,
        ),
      ),
    );
  }
}
