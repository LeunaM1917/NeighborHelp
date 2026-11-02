import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';

class EnableNotificationsButton extends StatefulWidget {
  const EnableNotificationsButton({super.key});
  @override
  State<EnableNotificationsButton> createState() =>
      _EnableNotificationsButtonState();
}

class _EnableNotificationsButtonState extends State<EnableNotificationsButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.notifications_outlined),
    label: const Text('Enable device notifications'),
    onPressed: _busy
        ? null
        : () async {
            setState(() => _busy = true);
            try {
              final enabled = await PushNotificationService().enable();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      enabled
                          ? 'Device notifications enabled.'
                          : 'Device notifications are unavailable or blocked. In-app notifications remain available.',
                    ),
                  ),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not enable notifications. Check browser or device permissions.',
                    ),
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
  );
}
