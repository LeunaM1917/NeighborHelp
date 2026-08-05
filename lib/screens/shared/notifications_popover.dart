import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/mobile_layout.dart';
import '../../models/app_user.dart';
import '../../models/notification.dart' as n;
import '../../services/firestore_service.dart';
import '../../widgets/stream_snapshot.dart';

/// Notification dropdown (web) or bottom sheet (mobile / compact).
class NotificationsPopover {
  NotificationsPopover._();

  static OverlayEntry? _entry;

  static void toggle(
    BuildContext context, {
    required GlobalKey anchorKey,
    required AppUser appUser,
  }) {
    if (_entry != null) {
      hide();
      return;
    }

    if (MobileLayout.useBottomSheets(context)) {
      final native = MobileLayout.isNativeApp(context);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: native ? 0.88 : 0.65,
          minChildSize: native ? 0.45 : 0.35,
          maxChildSize: 0.95,
          builder: (_, scrollController) => _NotificationSheet(
            appUser: appUser,
            scrollController: scrollController,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
      return;
    }

    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final overlay = Overlay.of(context);
    final anchorOffset = box.localToGlobal(Offset.zero);
    final anchorSize = box.size;
    final screen = MediaQuery.sizeOf(context);
    const popupWidth = 400.0;
    const maxHeight = 480.0;

    var left = anchorOffset.dx + anchorSize.width - popupWidth;
    left = left.clamp(12.0, screen.width - popupWidth - 12.0);
    final top = anchorOffset.dy + anchorSize.height + 10;

    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: hide,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            child: Material(
              color: Colors.transparent,
              child: _NotificationDropdown(
                appUser: appUser,
                maxHeight: maxHeight,
                onClose: hide,
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _NotificationDropdown extends StatelessWidget {
  const _NotificationDropdown({
    required this.appUser,
    required this.maxHeight,
    required this.onClose,
    this.scrollController,
    this.useCardLayout = false,
  });

  final AppUser appUser;
  final double maxHeight;
  final VoidCallback onClose;
  final ScrollController? scrollController;
  final bool useCardLayout;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    final shell = Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: useCardLayout
          ? null
          : BoxDecoration(
              color: FigmaColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.gray200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: ClipRRect(
        borderRadius: useCardLayout ? BorderRadius.zero : BorderRadius.circular(10),
        child: Stack(
          children: [
            StreamBuilder<List<n.AppNotification>>(
              stream: firestore.notificationsForUser(appUser.userId),
              builder: (context, snap) {
                if (isStreamWaiting(snap)) {
                  return SizedBox(
                    height: useCardLayout ? 160 : 120,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return _NotificationsEmptyState(compact: !useCardLayout);
                }
                final list = ListView.separated(
                  controller: scrollController,
                  shrinkWrap: scrollController == null,
                  padding: EdgeInsets.fromLTRB(
                    useCardLayout ? 16 : 0,
                    useCardLayout ? 8 : (scrollController == null ? 40 : 8),
                    useCardLayout ? 16 : 0,
                    useCardLayout ? 20 : 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => useCardLayout
                      ? const SizedBox(height: 10)
                      : const Divider(height: 1, color: FigmaColors.gray200),
                  itemBuilder: (context, index) {
                    final note = items[index];
                    return _NotificationRow(
                      note: note,
                      timeLabel: _formatNotificationTime(note.createdAt.toDate()),
                      useCardLayout: useCardLayout,
                      onTap: () => firestore.markNotificationRead(note.notificationId),
                    );
                  },
                );

                if (scrollController != null) {
                  return list;
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Scrollbar(
                    thumbVisibility: items.length > 5,
                    child: list,
                  ),
                );
              },
            ),
            if (scrollController == null)
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  style: IconButton.styleFrom(
                    foregroundColor: FigmaColors.gray600,
                    hoverColor: FigmaColors.gray100,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return shell;
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.appUser,
    required this.scrollController,
    required this.onClose,
  });

  final AppUser appUser;
  final ScrollController scrollController;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FigmaColors.gray50,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FigmaColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<n.AppNotification>>(
                    stream: FirestoreService().notificationsForUser(appUser.userId),
                    builder: (context, snap) {
                      final unread = (snap.data ?? []).where((note) => !note.isRead).length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.gray900,
                            ),
                          ),
                          if (unread > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                unread == 1 ? '1 unread' : '$unread unread',
                                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(foregroundColor: FigmaColors.gray700),
                ),
              ],
            ),
          ),
          Expanded(
            child: _NotificationDropdown(
              appUser: appUser,
              maxHeight: MediaQuery.sizeOf(context).height,
              onClose: onClose,
              scrollController: scrollController,
              useCardLayout: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 36 : 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: FigmaColors.tintBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 28, color: FigmaColors.navy),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 6),
          Text(
            'Updates about bookings, messages, and your account will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.note,
    required this.timeLabel,
    required this.onTap,
    this.useCardLayout = false,
  });

  final n.AppNotification note;
  final String timeLabel;
  final VoidCallback onTap;
  final bool useCardLayout;

  ({IconData icon, Color bg, Color fg}) _visualForType() {
    final type = note.notificationType.toLowerCase();
    if (type.contains('booking')) {
      return (icon: Icons.event_available_outlined, bg: FigmaColors.tintBlue, fg: FigmaColors.navy);
    }
    if (type.contains('message') || type.contains('chat')) {
      return (icon: Icons.chat_bubble_outline_rounded, bg: FigmaColors.tintGreen, fg: FigmaColors.green);
    }
    if (type.contains('payment') || type.contains('fee')) {
      return (icon: Icons.payments_outlined, bg: const Color(0xFFFFF4E5), fg: const Color(0xFFB45309));
    }
    if (type.contains('security') || type.contains('account')) {
      return (icon: Icons.shield_outlined, bg: FigmaColors.gray100, fg: FigmaColors.gray800);
    }
    if (type.contains('announce')) {
      return (icon: Icons.campaign_outlined, bg: FigmaColors.tintGreen2, fg: FigmaColors.green);
    }
    return (icon: Icons.notifications_outlined, bg: FigmaColors.gray100, fg: FigmaColors.gray800);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !note.isRead;
    final visual = _visualForType();

    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(useCardLayout ? 12 : 0),
      hoverColor: FigmaColors.gray50,
      child: Padding(
        padding: EdgeInsets.all(useCardLayout ? 14 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visual.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(visual.icon, size: 22, color: visual.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.gray900,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                      ),
                    ],
                  ),
                  if (note.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: FigmaColors.gray600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: FigmaColors.navy,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!useCardLayout) {
      return Material(
        color: isUnread ? const Color(0xFFE8EDF2) : FigmaColors.white,
        child: content,
      );
    }

    return Material(
      color: FigmaColors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread ? FigmaColors.navy.withValues(alpha: 0.2) : FigmaColors.gray200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

String _formatNotificationTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) {
    return DateFormat.jm().format(date);
  }
  if (now.difference(date).inDays < 7) {
    return DateFormat('EEE').format(date);
  }
  return DateFormat('MMM d').format(date);
}
