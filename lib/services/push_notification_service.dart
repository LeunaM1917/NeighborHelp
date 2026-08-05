import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Heavy work should stay minimal; initialize Firebase here if needed.
  if (kDebugMode) {
    debugPrint('Background message: ${message.messageId}');
  }
}

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<void> init() async {
    await _messaging.setAutoInitEnabled(true);
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }
    if (kIsWeb) {
      // Web requires VAPID key configuration in Firebase console.
      return;
    }
    await _messaging.getToken();
  }
}
