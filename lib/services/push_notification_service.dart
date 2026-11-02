import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/functions_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final PushNotificationService _shared = PushNotificationService._();
  factory PushNotificationService() => _shared;
  PushNotificationService._();
  final _messaging = FirebaseMessaging.instance;
  bool _started = false;
  bool _canRegister = false;
  String? _token;
  static const _vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

  Future<void> init() async {
    if (_started) return;
    _started = true;
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      try { await _register(requestPermission: false); } catch (e) { debugPrint('Push registration unavailable: $e'); }
    });
    _messaging.onTokenRefresh.listen((token) async {
      if (!_canRegister) return;
      _token = token;
      try { await _saveToken(token); } catch (e) { debugPrint('Push token refresh unavailable: $e'); }
    });
  }

  Future<bool> enable() => _register(requestPermission: true);

  Future<bool> _register({required bool requestPermission}) async {
    if (FirebaseAuth.instance.currentUser == null || (kIsWeb && _vapidKey.isEmpty)) return false;
    final settings = requestPermission ? await _messaging.requestPermission() : await _messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized && settings.authorizationStatus != AuthorizationStatus.provisional) return false;
    final token = await _messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
    if (token == null) return false;
    _canRegister = true;
    _token = token;
    await _saveToken(token);
    return true;
  }

  Future<void> _saveToken(String token) async {
    if (FirebaseAuth.instance.currentUser == null || !_canRegister) return;
    await FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion).httpsCallable('registerPushDevice').call({
      'token': token, 'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
  }

  Future<void> unregister() async {
    final uid = FirebaseAuth.instance.currentUser?.uid, token = _token;
    _canRegister = false;
    _token = null;
    if (uid == null || token == null) return;
    await FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion).httpsCallable('registerPushDevice').call({'action': 'unregister', 'token': token});
    await _messaging.deleteToken();
  }
}
