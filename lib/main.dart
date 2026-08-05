import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
    runApp(const _FirebaseInitErrorApp());
    return;
  }

  // Do not await push setup before [runApp]: on web, [requestPermission] can stall
  // cold start (blank page with only index.html title) until the user interacts.
  runApp(const NeighborHelpApp());
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await PushNotificationService().init();
    } catch (e, st) {
      debugPrint('PushNotificationService init failed: $e\n$st');
    }
  });
}

class _FirebaseInitErrorApp extends StatelessWidget {
  const _FirebaseInitErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('NeighborHelp', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                Text(
                  'Firebase failed to initialize. Replace lib/firebase_options.dart using '
                  '`dart pub global activate flutterfire_cli` and `flutterfire configure`, '
                  'then rebuild.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
