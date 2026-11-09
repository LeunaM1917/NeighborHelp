import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  if (!useEmulators) FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(options: useEmulators ? const FirebaseOptions(
      apiKey: 'demo-api-key', appId: '1:1234567890:web:neighborhelp', messagingSenderId: '1234567890',
      projectId: 'demo-neighborhelp', storageBucket: 'demo-neighborhelp.appspot.com',
    ) : DefaultFirebaseOptions.currentPlatform);
    const appCheckEnabled = bool.fromEnvironment('APP_CHECK_ENABLED');
    if (!useEmulators && appCheckEnabled) {
      const siteKey = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');
      if (kIsWeb && siteKey.isEmpty) throw StateError('APP_CHECK_WEB_SITE_KEY is required when App Check is enabled on web.');
      await FirebaseAppCheck.instance.activate(
        webProvider: kIsWeb ? ReCaptchaV3Provider(siteKey) : null,
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      );
    }
    if (useEmulators) {
      const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
      await FirebaseAuth.instance.useAuthEmulator(host, 9098);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8088);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5008);
      await FirebaseStorage.instance.useStorageEmulator(host, 9198);
    } else if (kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      } catch (_) { /* Unsupported browsers still retain in-memory loaded data. */ }
    }
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
    runApp(const _FirebaseInitErrorApp());
    return;
  }

  // Do not await push setup before [runApp]: on web, [requestPermission] can stall
  // cold start (blank page with only index.html title) until the user interacts.
  runApp(const NeighborHelpApp());
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (useEmulators) return;
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
