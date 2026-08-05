import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/notification.dart' as n;
import 'admin_dashboard_widgets.dart';
import 'admin_detail_dialog.dart';
import 'admin_widgets.dart';

class NotificationHistoryRow {
  const NotificationHistoryRow({
    required this.title,
    required this.message,
    required this.audience,
    required this.sentAt,
    required this.status,
    required this.count,
    required this.type,
  });

  final String title;
  final String message;
  final String audience;
  final DateTime sentAt;
  final String status;
  final int count;
  final String type;
}

List<NotificationHistoryRow> groupNotificationHistory(List<n.AppNotification> items) {
  final groups = <String, List<n.AppNotification>>{};
  for (final note in items) {
    final dt = note.createdAt.toDate();
    final key = '${note.title}|${note.message}|${dt.year}-${dt.month}-${dt.day}-${dt.hour}-${dt.minute}';
    groups.putIfAbsent(key, () => []).add(note);
  }

  final rows = <NotificationHistoryRow>[];
  groups.forEach((_, list) {
    list.sort((a, b) => a.userId.compareTo(b.userId));
    final first = list.first;
    final audience = list.length > 1 ? '${list.length} users' : '1 user';
    final type = first.notificationType.toLowerCase();
    rows.add(
      NotificationHistoryRow(
        title: first.title,
        message: first.message,
        audience: list.length > 5 ? 'All users' : audience,
        sentAt: first.createdAt.toDate(),
        status: 'Sent',
        count: list.length,
        type: type.contains('direct') ? 'Direct' : 'Broadcast',
      ),
    );
  });
  rows.sort((a, b) => b.sentAt.compareTo(a.sentAt));
  return rows;
}

NotificationStats computeNotificationStats(List<n.AppNotification> items) {
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  final recent = items.where((n) => n.createdAt.toDate().isAfter(cutoff)).toList();
  final groups = groupNotificationHistory(recent);

  var broadcast = 0;
  var direct = 0;
  for (final g in groups) {
    if (g.type == 'Direct') {
      direct += g.count;
    } else {
      broadcast += g.count;
    }
  }

  return NotificationStats(
    total: recent.length,
    broadcast: broadcast,
    direct: direct,
    scheduled: 0,
  );
}

class NotificationStats {
  const NotificationStats({
    required this.total,
    required this.broadcast,
    required this.direct,
    required this.scheduled,
  });

  final int total;
  final int broadcast;
  final int direct;
  final int scheduled;
}

class AdminComposeAnnouncementCard extends StatelessWidget {
  const AdminComposeAnnouncementCard({
    super.key,
    required this.titleController,
    required this.messageController,
    required this.userIdController,
    required this.audienceMode,
    required this.onAudienceModeChanged,
    required this.broadcastFilter,
    required this.onBroadcastFilterChanged,
    required this.inApp,
    required this.email,
    required this.push,
    required this.onInAppChanged,
    required this.onEmailChanged,
    required this.onPushChanged,
    required this.scheduleNow,
    required this.onScheduleChanged,
    required this.messageLength,
    required this.sending,
    required this.onSaveDraft,
    required this.onSend,
  });

  final TextEditingController titleController;
  final TextEditingController messageController;
  final TextEditingController userIdController;
  final String audienceMode;
  final ValueChanged<String> onAudienceModeChanged;
  final String broadcastFilter;
  final ValueChanged<String> onBroadcastFilterChanged;
  final bool inApp;
  final bool email;
  final bool push;
  final ValueChanged<bool> onInAppChanged;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onPushChanged;
  final bool scheduleNow;
  final ValueChanged<bool> onScheduleChanged;
  final int messageLength;
  final bool sending;
  final VoidCallback onSaveDraft;
  final VoidCallback onSend;

  static const broadcastFilters = [
    'All users',
    'Customers only',
    'Providers only',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: '',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Compose announcement', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text('Title', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600)),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Enter announcement title',
                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Message', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600)),
                const Spacer(),
                Text('$messageLength/2000', style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: messageController,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'Type your message here…',
                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Target user ID (optional)',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: userIdController,
              enabled: audienceMode == 'specific',
              decoration: InputDecoration(
                hintText: 'Firebase UID for a single user',
                hintStyle: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final stack = c.maxWidth < 520;
                final allUsers = _AudienceOptionCard(
                  title: 'All users',
                  subtitle: 'Broadcast to everyone on the platform',
                  icon: Icons.public_outlined,
                  selected: audienceMode == 'all',
                  onTap: () => onAudienceModeChanged('all'),
                );
                final specific = _AudienceOptionCard(
                  title: 'Specific users',
                  subtitle: 'Send to one user by ID',
                  icon: Icons.person_outline,
                  selected: audienceMode == 'specific',
                  onTap: () => onAudienceModeChanged('specific'),
                );
                if (stack) {
                  return Column(children: [allUsers, const SizedBox(height: 10), specific]);
                }
                return Row(children: [Expanded(child: allUsers), const SizedBox(width: 12), Expanded(child: specific)]);
              },
            ),
            const SizedBox(height: 16),
            Text('Broadcast filter', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: FigmaColors.gray300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: broadcastFilter,
                  isExpanded: true,
                  items: [
                    for (final f in broadcastFilters)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: audienceMode == 'all'
                      ? (v) {
                          if (v != null) onBroadcastFilterChanged(v);
                        }
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Channels', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _ChannelChip(label: 'In-app', icon: Icons.notifications_outlined, selected: inApp, onChanged: onInAppChanged),
                _ChannelChip(label: 'Email', icon: Icons.mail_outline, selected: email, onChanged: onEmailChanged),
                _ChannelChip(label: 'Push', icon: Icons.phone_android_outlined, selected: push, onChanged: onPushChanged),
              ],
            ),
            const SizedBox(height: 16),
            Text('Schedule', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Send now')),
                ButtonSegment(value: false, label: Text('Schedule for later')),
              ],
              selected: {scheduleNow},
              onSelectionChanged: (s) {
                if (s.isNotEmpty) onScheduleChanged(s.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return FigmaColors.green;
                  return FigmaColors.gray700;
                }),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton(
                  onPressed: sending ? null : onSaveDraft,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Save as draft', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: sending ? null : onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: FigmaColors.green,
                      foregroundColor: FigmaColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      sending ? 'Sending…' : 'Send notification',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceOptionCard extends StatelessWidget {
  const _AudienceOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? FigmaColors.tintGreen : FigmaColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? FigmaColors.green : FigmaColors.gray300, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? FigmaColors.green : FigmaColors.gray600),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? FigmaColors.green : FigmaColors.gray400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? FigmaColors.green : FigmaColors.gray600),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onChanged,
      selectedColor: FigmaColors.tintGreen,
      checkmarkColor: FigmaColors.green,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? FigmaColors.green : FigmaColors.gray700,
      ),
      side: BorderSide(color: selected ? FigmaColors.green : FigmaColors.gray300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class AdminNotificationStatusChip extends StatelessWidget {
  const AdminNotificationStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'scheduled':
        bg = FigmaColors.orange50;
        fg = FigmaColors.orange600;
      case 'draft':
        bg = FigmaColors.gray100;
        fg = FigmaColors.gray600;
      default:
        bg = FigmaColors.tintGreen;
        fg = FigmaColors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class AdminRecentNotificationsTable extends StatelessWidget {
  const AdminRecentNotificationsTable({
    super.key,
    required this.rows,
    this.onViewAll,
    this.onOpenRow,
  });

  final List<NotificationHistoryRow> rows;
  final VoidCallback? onViewAll;
  final ValueChanged<NotificationHistoryRow>? onOpenRow;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');
    final display = rows.take(8).toList();

    return AdminPanelCard(
      title: '',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text('Recent notifications', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: onViewAll,
                  child: Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.green)),
                ),
              ],
            ),
          ),
          if (display.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No notifications sent yet.', style: GoogleFonts.inter(color: FigmaColors.gray500)),
            )
          else
            AdminHorizontalScrollTable(
              minTableWidth: 1050,
              child: DataTable(
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowHeight: 40,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 64,
                headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: FigmaColors.gray600),
                columns: const [
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Audience')),
                  DataColumn(label: Text('Channel')),
                  DataColumn(label: Text('Date Sent')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final r in display)
                    DataRow(
                      cells: [
                        DataCell(
                          onOpenRow != null
                              ? AdminTableDetailTap(
                                  onOpen: () => onOpenRow!(r),
                                  child: SizedBox(
                                    width: 180,
                                    child: Text(
                                      r.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  width: 180,
                                  child: Text(r.title, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                ),
                        ),
                        DataCell(Text(r.audience)),
                        DataCell(
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_android_outlined, size: 16, color: FigmaColors.gray500),
                              SizedBox(width: 4),
                              Icon(Icons.mail_outline, size: 16, color: FigmaColors.gray500),
                              SizedBox(width: 4),
                              Icon(Icons.notifications_outlined, size: 16, color: FigmaColors.green),
                            ],
                          ),
                        ),
                        DataCell(Text('${dateFmt.format(r.sentAt)} • ${timeFmt.format(r.sentAt)}')),
                        DataCell(AdminNotificationStatusChip(status: r.status)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onOpenRow != null) AdminTableViewButton(onPressed: () => onOpenRow!(r)),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: onOpenRow != null ? (_) => onOpenRow!(r) : null,
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'view', child: Text('View details')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class AdminNotificationInsightsPanel extends StatelessWidget {
  const AdminNotificationInsightsPanel({
    super.key,
    required this.stats,
    this.period = 'Last 30 days',
    this.onPeriodChanged,
  });

  final NotificationStats stats;
  final String period;
  final ValueChanged<String>? onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    if (total == 0) {
      return AdminPanelCard(
        title: 'Notification Insights',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No notification data yet', style: GoogleFonts.inter(color: FigmaColors.gray500)),
        ),
      );
    }

    final broadcastPct = (stats.broadcast / total * 100);
    final directPct = (stats.direct / total * 100);
    final scheduledPct = (stats.scheduled / total * 100);

    final sections = <PieChartSectionData>[
      if (stats.broadcast > 0)
        PieChartSectionData(value: stats.broadcast.toDouble(), color: FigmaColors.green, radius: 34, showTitle: false),
      if (stats.direct > 0)
        PieChartSectionData(value: stats.direct.toDouble(), color: FigmaColors.navy, radius: 34, showTitle: false),
      if (stats.scheduled > 0)
        PieChartSectionData(value: stats.scheduled.toDouble(), color: FigmaColors.orange600, radius: 34, showTitle: false),
    ];

    return AdminPanelCard(
      title: 'Notification Insights',
      trailing: period.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: FigmaColors.gray300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: period,
                  style: GoogleFonts.inter(fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 'Last 30 days', child: Text('Last 30 days')),
                    DropdownMenuItem(value: 'Last 7 days', child: Text('Last 7 days')),
                  ],
                  onChanged: onPeriodChanged == null
                      ? null
                      : (v) {
                          if (v != null) onPeriodChanged!(v);
                        },
                ),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            SizedBox(
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      startDegreeOffset: -90,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Total', style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray500)),
                    ],
                  ),
                ],
              ),
            ),
            _legend('Broadcast', broadcastPct, FigmaColors.green),
            _legend('Direct', directPct, FigmaColors.navy),
            _legend('Scheduled', scheduledPct, FigmaColors.orange600),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray600))),
          Text('${pct.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AdminNotificationRecentList extends StatelessWidget {
  const AdminNotificationRecentList({
    super.key,
    required this.rows,
    this.onViewAll,
  });

  final List<NotificationHistoryRow> rows;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final timeFmt = DateFormat('h:mm a');
    final recent = rows.take(3).toList();

    return AdminPanelCard(
      title: 'Recent Sent Notifications',
      trailing: TextButton(
        onPressed: onViewAll,
        child: Text('View all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.green)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: recent.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Nothing sent yet', style: GoogleFonts.inter(color: FigmaColors.gray500, fontSize: 13)),
              )
            : Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: FigmaColors.gray200),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(recent[i].title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  '${recent[i].audience} • ${dateFmt.format(recent[i].sentAt)} • ${timeFmt.format(recent[i].sentAt)}',
                                  style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
                                ),
                              ],
                            ),
                          ),
                          const AdminNotificationStatusChip(status: 'Sent'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class AdminNotificationQuickActions extends StatelessWidget {
  const AdminNotificationQuickActions({
    super.key,
    this.onBroadcast,
    this.onTargetUser,
    this.onViewHistory,
    this.onExport,
  });

  final VoidCallback? onBroadcast;
  final VoidCallback? onTargetUser;
  final VoidCallback? onViewHistory;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Quick Actions',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 280;
            final tiles = [
              _QuickTile(icon: Icons.campaign_outlined, label: 'Send Broadcast', onTap: onBroadcast),
              _QuickTile(icon: Icons.person_pin_outlined, label: 'Target Specific User', onTap: onTargetUser),
              _QuickTile(icon: Icons.history, label: 'View History', onTap: onViewHistory),
              _QuickTile(icon: Icons.file_download_outlined, label: 'Export Notifications', onTap: onExport),
            ];
            if (wide) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in tiles)
                    SizedBox(width: (c.maxWidth - 10) / 2, child: t),
                ],
              );
            }
            return Column(children: [for (final t in tiles) ...[t, const SizedBox(height: 8)]]);
          },
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FigmaColors.gray50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FigmaColors.gray200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: FigmaColors.gray700),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, size: 18, color: FigmaColors.gray400),
            ],
          ),
        ),
      ),
    );
  }
}
