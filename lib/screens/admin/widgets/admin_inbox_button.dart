import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/notification.dart';
import '../../../services/firestore_service.dart';

class AdminInboxButton extends StatelessWidget {
  const AdminInboxButton({
    super.key,
    required this.appUser,
    required this.onNavigate,
  });
  final AppUser appUser;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppNotification>>(
    stream: FirestoreService().adminNotificationsForUser(appUser.userId),
    builder: (context, snapshot) {
      final items = snapshot.data ?? const <AppNotification>[];
      final unread = items.where((n) => !n.isRead).length;
      return IconButton(
        tooltip: 'Notifications',
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread >= 50 ? '50+' : '$unread'),
          child: const Icon(Icons.notifications_outlined, size: 22),
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AdminInboxDialog(
            stream: FirestoreService().adminNotificationsForUser(
              appUser.userId,
            ),
            initialItems: items,
            onRead: (n) =>
                FirestoreService().markNotificationRead(n.notificationId),
            onNavigate: onNavigate,
            onRetry: () => FirestoreService().retryDataLoads(),
          ),
        ),
      );
    },
  );
}

class AdminInboxDialog extends StatefulWidget {
  const AdminInboxDialog({
    super.key,
    required this.stream,
    required this.onRead,
    required this.onNavigate,
    this.initialItems = const [],
    this.onRetry,
  });
  final Stream<List<AppNotification>> stream;
  final List<AppNotification> initialItems;
  final Future<void> Function(AppNotification notification) onRead;
  final ValueChanged<int> onNavigate;
  final Future<void> Function()? onRetry;
  @override
  State<AdminInboxDialog> createState() => _AdminInboxDialogState();
}

class _AdminInboxDialogState extends State<AdminInboxDialog> {
  bool _busy = false;
  String? _error;
  Future<void> _read(List<AppNotification> notes, {bool open = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Future.wait(notes.where((n) => !n.isRead).map(widget.onRead));
      if (!mounted) return;
      if (open) {
        Navigator.pop(context);
        final tab = notes.first.adminTab;
        if (tab != null && tab >= 0 && tab <= 13 && tab != 10) {
          widget.onNavigate(tab);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not mark notifications as read. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Notifications'),
    content: SizedBox(
      width: 520,
      height: MediaQuery.sizeOf(context).height * .55,
      child: StreamBuilder<List<AppNotification>>(
        stream: widget.stream,
        initialData: widget.initialItems,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Could not load notifications.'),
                if (widget.onRetry != null)
                  TextButton(
                    onPressed: widget.onRetry,
                    child: const Text('Retry'),
                  ),
              ],
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !(snapshot.hasData && snapshot.data!.isNotEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <AppNotification>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Recent registrations, certificate submissions and review updates.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy || items.every((n) => n.isRead)
                      ? null
                      : () => _read(items),
                  child: const Text('Mark all as read'),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: FigmaColors.red600),
                ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No notifications yet.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final note = items[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            leading: Icon(
                              note.isRead
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                              color: note.isRead
                                  ? FigmaColors.gray400
                                  : FigmaColors.navy,
                            ),
                            title: Text(
                              note.title,
                              style: TextStyle(
                                fontWeight: note.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.message),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(
                                    note.createdAt.toDate().toUtc().add(
                                      const Duration(hours: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: _busy
                                ? null
                                : () => _read([note], open: true),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
