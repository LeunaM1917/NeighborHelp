import 'package:flutter/material.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/user_role.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../widgets/admin_dashboard_widgets.dart';
import '../widgets/admin_notifications_widgets.dart';
import '../widgets/admin_table_details.dart';
import '../widgets/admin_widgets.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _userIdController = TextEditingController();

  String _audienceMode = 'all';
  String _broadcastFilter = 'All users';
  bool _inApp = true;
  bool _email = true;
  bool _push = true;
  bool _scheduleNow = true;
  String _insightsPeriod = 'Last 30 days';
  bool _sending = false;

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  UserRole? _roleFromFilter() {
    return switch (_broadcastFilter) {
      'Customers only' => UserRole.customer,
      'Providers only' => UserRole.provider,
      _ => null,
    };
  }

  String _trendHint(int count) {
    if (count <= 0) return '— 0% vs last 30 days';
    return '↑ vs last 30 days';
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title before sending.')),
      );
      return;
    }

    if (!_scheduleNow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled send — coming soon.')),
      );
      return;
    }

    if (!_inApp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable at least the In-app channel to send.')),
      );
      return;
    }

    setState(() => _sending = true);
    final firestore = FirestoreService();

    try {
      if (_audienceMode == 'specific') {
        final uid = _userIdController.text.trim();
        if (uid.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a target user ID for specific users.')),
            );
          }
          return;
        }
        await firestore.adminSendNotification(
          userId: uid,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          notificationType: 'Direct',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent to user')),
        );
      } else {
        final count = await firestore.adminBroadcastNotification(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          roleFilter: _roleFromFilter(),
          notificationType: 'Broadcast',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast sent to $count users')),
        );
      }

      if (_email || _push) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _email && _push
                  ? 'Email and push delivery are not wired yet — in-app notification saved.'
                  : 'Additional channels are not wired yet — in-app notification saved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      auth: widget.auth,
      useDashboardChrome: true,
      child: StreamBuilder(
        stream: FirestoreService().allNotificationsStream(),
        builder: (context, snap) {
          final items = snap.data ?? [];
          final stats = computeNotificationStats(items);
          final history = groupNotificationHistory(items);

          final broadcastPct = stats.total > 0 ? ((stats.broadcast / stats.total) * 100).round() : 0;
          final directPct = stats.total > 0 ? ((stats.direct / stats.total) * 100).round() : 0;
          final scheduledPct = stats.total > 0 ? ((stats.scheduled / stats.total) * 100).round() : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AdminDashboardHeader(
                title: 'Notifications',
                subtitle: 'Send announcements to customers, providers, or individual users.',
              ),
              const SizedBox(height: 24),
              AdminMetricGrid(
                children: [
                  AdminMetricCard(
                    label: 'Total notifications sent',
                    value: '${stats.total}',
                    hint: _trendHint(stats.total),
                    icon: Icons.notifications_outlined,
                    iconBg: FigmaColors.tintGreen,
                    iconColor: FigmaColors.green,
                  ),
                  AdminMetricCard(
                    label: 'Broadcast messages',
                    value: '${stats.broadcast}',
                    hint: 'Platform-wide announcements',
                    icon: Icons.campaign_outlined,
                    iconBg: FigmaColors.tintBlue,
                    iconColor: FigmaColors.navy,
                    trendLabel: '$broadcastPct% of total',
                  ),
                  AdminMetricCard(
                    label: 'Direct notifications',
                    value: '${stats.direct}',
                    hint: 'Single-user messages',
                    icon: Icons.person_pin_outlined,
                    iconBg: FigmaColors.purple50,
                    iconColor: FigmaColors.purple600,
                    trendLabel: '$directPct% of total',
                  ),
                  AdminMetricCard(
                    label: 'Scheduled messages',
                    value: '${stats.scheduled}',
                    hint: 'Queued for later',
                    icon: Icons.schedule_outlined,
                    iconBg: FigmaColors.orange50,
                    iconColor: FigmaColors.orange600,
                    trendLabel: '$scheduledPct% of total',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 960;
                  final main = Column(
                    children: [
                      AdminComposeAnnouncementCard(
                        titleController: _titleController,
                        messageController: _messageController,
                        userIdController: _userIdController,
                        audienceMode: _audienceMode,
                        onAudienceModeChanged: (v) => setState(() => _audienceMode = v),
                        broadcastFilter: _broadcastFilter,
                        onBroadcastFilterChanged: (v) => setState(() => _broadcastFilter = v),
                        inApp: _inApp,
                        email: _email,
                        push: _push,
                        onInAppChanged: (v) => setState(() => _inApp = v),
                        onEmailChanged: (v) => setState(() => _email = v),
                        onPushChanged: (v) => setState(() => _push = v),
                        scheduleNow: _scheduleNow,
                        onScheduleChanged: (v) => setState(() => _scheduleNow = v),
                        messageLength: _messageController.text.length,
                        sending: _sending,
                        onSaveDraft: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Draft saved locally — Firestore drafts coming soon.')),
                          );
                        },
                        onSend: _send,
                      ),
                      const SizedBox(height: 16),
                      AdminRecentNotificationsTable(
                        rows: history,
                        onOpenRow: (r) => showAdminNotificationDetail(context, row: r),
                        onViewAll: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${history.length} notification groups in history')),
                          );
                        },
                      ),
                    ],
                  );

                  final side = Column(
                    children: [
                      AdminNotificationInsightsPanel(
                        stats: stats,
                        period: _insightsPeriod,
                        onPeriodChanged: (v) => setState(() => _insightsPeriod = v),
                      ),
                      const SizedBox(height: 16),
                      AdminNotificationRecentList(
                        rows: history,
                        onViewAll: () {},
                      ),
                      const SizedBox(height: 16),
                      AdminNotificationQuickActions(
                        onBroadcast: () => setState(() => _audienceMode = 'all'),
                        onTargetUser: () => setState(() => _audienceMode = 'specific'),
                        onViewHistory: () {},
                        onExport: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export notifications — coming soon.')),
                          );
                        },
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
