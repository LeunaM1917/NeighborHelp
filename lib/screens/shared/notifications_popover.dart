import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../models/notification.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_navigation.dart';
import '../../theme/role_theme.dart';
import '../../widgets/anchored_popover_geometry.dart';
import 'help_support_popover.dart';

/// One anchored menu for every role, including phones. PopupRoute supplies
/// outside-click, Escape and back dismissal without a centered dialog.
class NotificationsPopover {
  NotificationsPopover._();
  static _NotificationsRoute? _route;
  static GlobalKey? _anchor;
  static void toggle(
    BuildContext context, {
    required GlobalKey anchorKey,
    required AppUser appUser,
    bool openBesideAnchor = false,
    Stream<List<AppNotification>>? stream,
    Stream<int>? unreadCount,
    int? initialUnread,
    List<AppNotification>? initialItems,
    Future<void> Function(AppNotification)? onRead,
    Future<void> Function()? onReadAll,
    Future<void> Function(AppNotification)? onOpen,
    Future<void> Function()? onRetry,
    ValueChanged<int>? onSelectTab,
  }) {
    HelpSupportPopover.hide();
    final same = _route != null && _anchor == anchorKey;
    hide();
    if (same || anchorKey.currentContext == null) return;
    final select = onSelectTab ?? NotificationNavigationScope.maybeOf(context);
    final route = _NotificationsRoute(
      anchorKey: anchorKey,
      openBesideAnchor: openBesideAnchor,
      palette: RoleTheme.forBadge(appUser.role.firestoreValue),
      stream: stream ?? FirestoreService().notificationsForUser(appUser.userId),
      unreadCount: unreadCount,
      initialUnread: initialUnread,
      initialItems: initialItems,
      onRead:
          onRead ??
          (note) =>
              FirestoreService().markNotificationRead(note.notificationId),
      onReadAll:
          onReadAll ??
          () => FirestoreService().markAllNotificationsRead(appUser.userId),
      onRetry: onRetry ?? () => FirestoreService().retryDataLoads(),
      onOpen:
          onOpen ??
          (note) => NotificationNavigator().open(
            context,
            user: appUser,
            note: note,
            onSelectTab: select,
          ),
      onReadError: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not mark this notification as read. Open the bell to retry.',
              ),
            ),
          );
        }
      },
    );
    _route = route;
    _anchor = anchorKey;
    Navigator.of(context, rootNavigator: true).push<void>(route).whenComplete(
      () {
        if (identical(_route, route)) {
          _route = null;
          _anchor = null;
        }
      },
    );
  }

  static void hide() {
    final route = _route;
    _route = null;
    _anchor = null;
    void remove() {
      if (route?.navigator != null) route!.navigator!.removeRoute(route);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => remove());
    } else {
      remove();
    }
  }
}

class _NotificationsRoute extends PopupRoute<void> {
  _NotificationsRoute({
    required this.anchorKey,
    required this.openBesideAnchor,
    required this.palette,
    required this.stream,
    this.unreadCount,
    this.initialUnread,
    required this.initialItems,
    required this.onRead,
    required this.onReadAll,
    required this.onOpen,
    required this.onRetry,
    required this.onReadError,
  });
  final GlobalKey anchorKey;
  final bool openBesideAnchor;
  final RolePalette palette;
  final Stream<List<AppNotification>> stream;
  final Stream<int>? unreadCount;
  final int? initialUnread;
  final List<AppNotification>? initialItems;
  final Future<void> Function(AppNotification) onRead, onOpen;
  final Future<void> Function() onReadAll, onRetry;
  final VoidCallback onReadError;
  @override
  Color? get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Close notifications';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);
  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute != null) {
      scheduleMicrotask(() {
        if (identical(NotificationsPopover._route, this)) {
          NotificationsPopover.hide();
        }
      });
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context), insets = media.padding;
    final safeSize = Size(
      media.size.width - insets.horizontal,
      math.max(
        0,
        media.size.height -
            insets.top -
            math.max(insets.bottom, media.viewInsets.bottom),
      ),
    );
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isActive) NotificationsPopover.hide();
      });
      return const SizedBox.shrink();
    }
    final origin = Offset(insets.left, insets.top);
    final popup = anchoredPopoverRect(
      viewport: safeSize,
      anchor: (box.localToGlobal(Offset.zero) - origin) & box.size,
      preferredWidth: 420,
      maxHeight: 560,
      openBesideAnchor: openBesideAnchor,
      fitToAnchorSpace: true,
    );
    return Stack(
      children: [
        Positioned(
          left: popup.left + origin.dx,
          top: popup.top + origin.dy,
          width: popup.width,
          height: popup.height,
          child: RoleThemeScope(
            palette: palette,
            child: Material(
              color: Colors.transparent,
              child: NotificationsPanel(
                stream: stream,
                unreadCount: unreadCount,
                initialUnread: initialUnread,
                initialItems: initialItems,
                onClose: NotificationsPopover.hide,
                onRead: onRead,
                onReadAll: onReadAll,
                onOpen: onOpen,
                onRetry: onRetry,
                onReadError: onReadError,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.appUser,
    this.openBesideAnchor = false,
    this.onSelectTab,
    this.compact = false,
    this.stream,
    this.unreadCount,
    this.onRead,
    this.onReadAll,
    this.onOpen,
  });
  final AppUser appUser;
  final bool openBesideAnchor, compact;
  final ValueChanged<int>? onSelectTab;
  final Stream<List<AppNotification>>? stream;
  final Stream<int>? unreadCount;
  final Future<void> Function(AppNotification)? onRead, onOpen;
  final Future<void> Function()? onReadAll;
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _anchor = GlobalKey();
  late Stream<List<AppNotification>> _stream;
  late Stream<int> _unreadCount;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _stream =
        widget.stream?.asBroadcastStream() ??
        FirestoreService().notificationsForUser(widget.appUser.userId);
    _unreadCount =
        widget.unreadCount?.asBroadcastStream() ??
        (widget.stream == null
            ? FirestoreService().unreadNotificationsCountForUser(
                widget.appUser.userId,
              )
            : _stream.map((notes) => notes.where((n) => !n.isRead).length));
  }

  @override
  void didUpdateWidget(NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appUser.userId != widget.appUser.userId ||
        oldWidget.stream != widget.stream ||
        oldWidget.unreadCount != widget.unreadCount) {
      NotificationsPopover.hide();
      _bind();
    }
  }

  @override
  void dispose() {
    NotificationsPopover.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleTheme.forBadge(widget.appUser.role.firestoreValue);
    return StreamBuilder<List<AppNotification>>(
      stream: _stream,
      builder: (context, snapshot) {
        final recentUnread = (snapshot.data ?? const <AppNotification>[])
            .where((n) => !n.isRead)
            .length;
        return StreamBuilder<int>(
          stream: _unreadCount,
          initialData: recentUnread,
          builder: (context, countSnapshot) {
            final unread = countSnapshot.data ?? recentUnread;
            return IconButton(
              key: _anchor,
              tooltip: 'Notifications',
              visualDensity: widget.compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              constraints: BoxConstraints(
                minWidth: widget.compact ? 36 : 44,
                minHeight: widget.compact ? 36 : 44,
              ),
              onPressed: () => NotificationsPopover.toggle(
                context,
                anchorKey: _anchor,
                appUser: widget.appUser,
                openBesideAnchor: widget.openBesideAnchor,
                stream: _stream,
                unreadCount: _unreadCount,
                initialUnread: unread,
                initialItems: snapshot.data,
                onSelectTab: widget.onSelectTab,
                onRead: widget.onRead,
                onReadAll: widget.onReadAll,
                onOpen: widget.onOpen,
              ),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                backgroundColor: role.primary,
                child: Icon(
                  unread > 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_outlined,
                  size: 22,
                  color: unread > 0 ? role.primary : FigmaColors.gray700,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({
    super.key,
    required this.stream,
    this.unreadCount,
    this.initialUnread,
    required this.onClose,
    required this.onRead,
    required this.onReadAll,
    required this.onOpen,
    this.initialItems,
    this.onRetry,
    this.onReadError,
  });
  final Stream<List<AppNotification>> stream;
  final Stream<int>? unreadCount;
  final int? initialUnread;
  final List<AppNotification>? initialItems;
  final VoidCallback onClose;
  final Future<void> Function(AppNotification) onRead, onOpen;
  final Future<void> Function() onReadAll;
  final Future<void> Function()? onRetry;
  final VoidCallback? onReadError;
  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  final _scroll = ScrollController();
  final _read = <String>{};
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _all(List<AppNotification> notes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onReadAll();
      if (mounted) {
        setState(() => _read.addAll(notes.map((n) => n.notificationId)));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not mark all notifications as read. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(AppNotification note) {
    // A slow/offline receipt must not stop a member from opening the record.
    if (!note.isRead) {
      unawaited(
        Future.sync(() => widget.onRead(note)).catchError((Object _) {
          widget.onReadError?.call();
        }),
      );
    }
    widget.onClose();
    unawaited(
      Future.sync(() => widget.onOpen(note)).catchError((Object _) {
        /* Router reports unavailable records. */
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    return Container(
      key: const ValueKey('notifications-dropdown'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: StreamBuilder<List<AppNotification>>(
        stream: widget.stream,
        initialData: widget.initialItems,
        builder: (context, snapshot) {
          final items = {
            for (final n in snapshot.data ?? const <AppNotification>[])
              n.notificationId: n,
          }.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final unread = items
              .where((n) => !n.isRead && !_read.contains(n.notificationId))
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: role.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close notifications',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 12, 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    StreamBuilder<int>(
                      stream: widget.unreadCount,
                      initialData: widget.initialUnread ?? unread,
                      builder: (context, count) => Text(
                        '${count.data ?? unread} unread',
                        style: const TextStyle(
                          fontSize: 12,
                          color: FigmaColors.gray600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy || snapshot.hasError || items.isEmpty
                          ? null
                          : () => _all(items),
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark all as read'),
                      style: TextButton.styleFrom(
                        foregroundColor: role.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: FigmaColors.gray200),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: FigmaColors.red600,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(
                child: snapshot.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Could not load notifications. Check your connection and try again.',
                                textAlign: TextAlign.center,
                              ),
                              if (widget.onRetry != null)
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await widget.onRetry!();
                                    } catch (_) {
                                      /* Stream exposes retry failures. */
                                    }
                                  },
                                  child: const Text('Retry'),
                                ),
                            ],
                          ),
                        ),
                      )
                    : !snapshot.hasData
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none_outlined,
                                size: 36,
                                color: FigmaColors.gray400,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No notifications yet',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Updates about bookings, messages, and your account will show up here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FigmaColors.gray600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _scroll,
                        thumbVisibility: items.length > 3,
                        child: ListView.separated(
                          controller: _scroll,
                          padding: EdgeInsets.zero,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: FigmaColors.gray200,
                          ),
                          itemBuilder: (context, index) {
                            final note = items[index];
                            return _NotificationRow(
                              note: note,
                              unread:
                                  !note.isRead &&
                                  !_read.contains(note.notificationId),
                              onTap: () => _open(note),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.note,
    required this.unread,
    required this.onTap,
  });
  final AppNotification note;
  final bool unread;
  final VoidCallback onTap;
  IconData get icon {
    final type = note.notificationType.toLowerCase();
    if (note.relatedCertificationId != null || type.contains('certificate')) {
      return Icons.workspace_premium_outlined;
    }
    if (note.relatedReportId != null || type.contains('report')) {
      return Icons.flag_outlined;
    }
    if (type.contains('message') ||
        type.contains('inquiry') ||
        type.contains('chat')) {
      return Icons.chat_bubble_outline;
    }
    if (note.relatedServiceId != null || type.contains('service')) {
      return Icons.home_repair_service_outlined;
    }
    if (type.contains('verif') || type.contains('security')) {
      return Icons.verified_user_outlined;
    }
    if (type.contains('review')) return Icons.star_outline;
    if (type.contains('payment')) return Icons.payments_outlined;
    if (note.relatedBookingId != null || type.contains('booking')) {
      return Icons.event_note_outlined;
    }
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final role = context.roleColors;
    final date = note.createdAt.toDate().toUtc().add(const Duration(hours: 8));
    final time = note.createdAt.seconds == 0
        ? 'Time unavailable'
        : '${DateFormat('MMM d, h:mm a').format(date)} · Manila';
    return Material(
      color: unread ? role.tint.withValues(alpha: .55) : Colors.white,
      child: InkWell(
        key: ValueKey('notification-${note.notificationId}'),
        onTap: onTap,
        hoverColor: role.tint,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: role.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: role.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: FigmaColors.gray900,
                      ),
                    ),
                    if (note.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: FigmaColors.gray600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: FigmaColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: role.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
