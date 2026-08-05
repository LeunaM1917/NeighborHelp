import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/admin_config.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_settings_widgets.dart';
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
  Widget build(BuildContext context) {
    final firestoreConnected = !auth.isLocalAdminOnly;
    final lastLogin = appUser.lastActive ?? appUser.updatedAt;
    final lastLoginStr = DateFormat('MMM d, yyyy • h:mm a').format(lastLogin.toDate());

    return AdminPageFrame(
      auth: auth,
      useDashboardChrome: true,
      child: StreamBuilder(
        stream: FirestoreService().allUsersStream(),
        builder: (context, userSnap) {
          final users = userSnap.data ?? [];
          final adminCount = users
              .where((u) => u.role == UserRole.administrator)
              .length;

          final recentUpdates = [
            AdminSettingsUpdateItem(
              title: 'Admin role permissions updated',
              date: DateTime.now().subtract(const Duration(days: 1)),
            ),
            AdminSettingsUpdateItem(
              title: 'Notification channels configured',
              date: DateTime.now().subtract(const Duration(days: 3)),
            ),
            AdminSettingsUpdateItem(
              title: 'Firestore rules deployed',
              date: DateTime.now().subtract(const Duration(days: 5)),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminDashboardHeader(
                title: 'Admin settings',
                subtitle: 'Console preferences and platform configuration reference.',
              ),
              if (auth.isLocalAdminOnly) ...[
                const SizedBox(height: 16),
                AdminFirestoreBanner(auth: auth),
              ],
              const SizedBox(height: 24),
              AdminMetricGrid(
                children: [
                  AdminMetricCard(
                    label: 'Admin accounts',
                    value: '${adminCount > 0 ? adminCount : 1}',
                    hint: 'Active account${adminCount == 1 ? '' : 's'}',
                    icon: Icons.person_outline,
                    iconBg: FigmaColors.tintGreen,
                    iconColor: FigmaColors.green,
                  ),
                  AdminMetricCard(
                    label: 'Connected services',
                    value: firestoreConnected ? '3' : '0',
                    hint: 'Active integrations',
                    icon: Icons.cloud_outlined,
                    iconBg: FigmaColors.tintBlue,
                    iconColor: FigmaColors.navy,
                  ),
                  AdminMetricCard(
                    label: 'Notification channels',
                    value: '3',
                    hint: 'Configured channels',
                    icon: Icons.notifications_outlined,
                    iconBg: FigmaColors.purple50,
                    iconColor: FigmaColors.purple600,
                  ),
                  AdminMetricCard(
                    label: 'Security status',
                    value: firestoreConnected ? 'Healthy' : 'Preview',
                    hint: firestoreConnected ? 'All systems secure' : 'Local preview mode',
                    icon: Icons.shield_outlined,
                    iconBg: FigmaColors.tintGreen2,
                    iconColor: FigmaColors.green,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 960;
                  final main = Column(
                    children: [
                      AdminSettingsSectionCard(
                        icon: Icons.person_outline,
                        iconBg: FigmaColors.tintGreen,
                        iconColor: FigmaColors.green,
                        title: 'Account & Access',
                        subtitle: 'Administrator identity and Firestore connection for this console.',
                        trailingAction: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit access — manage users in Firebase Console.')),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text('Edit access', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FigmaColors.green,
                            side: const BorderSide(color: FigmaColors.green),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        fields: [
                          AdminSettingsField(
                            label: 'Admin email',
                            value: appUser.email.isNotEmpty ? appUser.email : AdminConfig.firebaseEmail,
                          ),
                          AdminSettingsField(
                            label: 'Role',
                            value: appUser.role.firestoreValue,
                          ),
                          AdminSettingsField(
                            label: 'Firestore connection',
                            value: firestoreConnected ? 'Yes' : 'No (preview)',
                            pill: AdminSettingsStatusPill(
                              label: firestoreConnected ? 'Connected' : 'Offline',
                              positive: firestoreConnected,
                            ),
                          ),
                          AdminSettingsField(
                            label: 'Last login',
                            value: lastLoginStr,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AdminSettingsSectionCard(
                        icon: Icons.policy_outlined,
                        iconBg: FigmaColors.tintBlue,
                        iconColor: FigmaColors.navy,
                        title: 'Platform policies',
                        subtitle: 'Verification, bookings, and services are managed from their respective tabs.',
                        onTap: () => onNavigateToTab?.call(4),
                        fields: const [
                          AdminSettingsField(label: 'Provider verification', value: 'Required'),
                          AdminSettingsField(label: 'Booking moderation', value: 'Auto-review enabled'),
                          AdminSettingsField(label: 'Service visibility', value: 'Public'),
                          AdminSettingsField(label: 'Admin permissions', value: 'Role-based'),
                        ],
                        footer: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            AdminSettingsStatusPill(label: 'Verification'),
                            AdminSettingsStatusPill(label: 'Bookings'),
                            AdminSettingsStatusPill(label: 'Services'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AdminSettingsSectionCard(
                        icon: Icons.notifications_active_outlined,
                        iconBg: FigmaColors.purple50,
                        iconColor: FigmaColors.purple600,
                        title: 'Notifications & Alerts',
                        subtitle: 'Announcements are stored in the notifications collection and shown in the top-bar bell.',
                        onTap: () => onNavigateToTab?.call(10),
                        fields: [
                          const AdminSettingsField(
                            label: 'Storage',
                            value: 'notifications collection',
                          ),
                          AdminSettingsField(
                            label: 'Channels',
                            value: 'In-app · Email · Push',
                          ),
                          AdminSettingsField(
                            label: 'Broadcast enabled',
                            value: '',
                            pill: const AdminSettingsStatusPill(label: 'Enabled'),
                          ),
                          AdminSettingsField(
                            label: 'Alert logs enabled',
                            value: '',
                            pill: const AdminSettingsStatusPill(label: 'Enabled'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AdminSettingsSectionCard(
                        icon: Icons.tune_outlined,
                        iconBg: FigmaColors.gray100,
                        iconColor: FigmaColors.gray700,
                        title: 'System preferences',
                        subtitle: 'Display and logging defaults for the admin console.',
                        fields: [
                          const AdminSettingsField(label: 'Time zone', value: 'Asia/Manila'),
                          const AdminSettingsField(label: 'Date format', value: 'MMM d, yyyy'),
                          const AdminSettingsField(label: 'Theme', value: 'Light'),
                          AdminSettingsField(
                            label: 'Audit logging',
                            value: '',
                            pill: const AdminSettingsStatusPill(label: 'Enabled'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AdminSettingsSectionCard(
                        icon: Icons.security_outlined,
                        iconBg: FigmaColors.tintGreen,
                        iconColor: FigmaColors.green,
                        title: 'Security & Maintenance',
                        subtitle: 'Deploy firebase/firestore.rules when changing admin permissions.',
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Firestore rules', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                              content: SingleChildScrollView(
                                child: Text(
                                  'Administrator access requires users/{uid}.role = "Administrator". '
                                  'Edit firebase/firestore.rules and deploy from the Firebase CLI or Console.',
                                  style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        fields: [
                          AdminSettingsField(
                            label: 'Session management',
                            value: '',
                            pill: const AdminSettingsStatusPill(label: 'Active'),
                          ),
                          AdminSettingsField(
                            label: 'Firestore rules',
                            value: '',
                            pill: AdminSettingsStatusPill(label: firestoreConnected ? 'Synced' : 'Preview', positive: firestoreConnected),
                          ),
                          AdminSettingsField(
                            label: 'Backup status',
                            value: '',
                            pill: const AdminSettingsStatusPill(label: 'Healthy'),
                          ),
                          AdminSettingsField(
                            label: 'API connection',
                            value: '',
                            pill: AdminSettingsStatusPill(label: firestoreConnected ? 'Enabled' : 'Disabled', positive: firestoreConnected),
                          ),
                        ],
                      ),
                    ],
                  );

                  final side = Column(
                    children: [
                      AdminSettingsInsightsPanel(firestoreConnected: firestoreConnected),
                      const SizedBox(height: 16),
                      AdminSettingsRecentUpdates(
                        items: recentUpdates,
                        onViewAll: () => onNavigateToTab?.call(9),
                      ),
                      const SizedBox(height: 16),
                      AdminSettingsQuickActions(
                        onManageRoles: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Manage roles in Firebase Auth & Firestore users collection.')),
                          );
                        },
                        onReviewRules: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Review rules', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                              content: Text(
                                'Open firebase/firestore.rules in your project. '
                                'Set users/{uid}.role to "Administrator" for admin access.',
                                style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                        onExportConfig: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export config — coming soon.')),
                          );
                        },
                        onViewLogs: () => onNavigateToTab?.call(9),
                      ),
                    ],
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: main),
                        const SizedBox(width: 16),
                        SizedBox(width: 320, child: side),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      main,
                      const SizedBox(height: 16),
                      side,
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
