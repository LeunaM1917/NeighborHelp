import 'package:flutter/material.dart';
import '../../../models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/enable_notifications_button.dart';
import '../../../widgets/app_preferences_panel.dart';
import '../../../widgets/admin_mfa_panel.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_retention_panel.dart';
import '../widgets/admin_widgets.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({
    super.key,
    required this.auth,
    required this.appUser,
    this.onNavigateToTab,
  });
  final AuthService auth;
  final AppUser appUser;
  final ValueChanged<int>? onNavigateToTab;
  @override
  Widget build(BuildContext context) => AdminPageFrame(
    auth: auth,
    useDashboardChrome: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppPreferencesPanel(),
        const AdminMfaPanel(),
        const AdminDashboardHeader(
          title: 'Admin settings',
          subtitle: 'Account protection, notifications and record retention.',
        ),
        const SizedBox(height: 20),
        const AdminPanelCard(
          title: 'Session protection',
          child: Text(
            'Administrators sign out after 15 minutes without activity. Customers and providers sign out after one hour. Returning from the background checks elapsed inactivity.',
          ),
        ),
        const SizedBox(height: 16),
        const AdminPanelCard(
          title: 'Device notifications',
          child: EnableNotificationsButton(),
        ),
        const SizedBox(height: 16),
        const AdminPanelCard(
          title: 'Backup and recovery',
          child: Text(
            'Backup status has not been verified from this app. Use the documented Firebase backup checks and recovery drill before pilot deployment. A connection to Firestore does not prove that a backup exists.',
          ),
        ),
        const SizedBox(height: 16),
        if (auth.isLocalAdminOnly)
          const AdminErrorBox(
            message:
                'Firebase administrator sign-in is required for data management.',
          )
        else
          const AdminPanelCard(
            title: 'Data management',
            child: AdminRetentionPanel(),
          ),
      ],
    ),
  );
}
