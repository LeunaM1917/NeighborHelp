import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'config/app_secrets.dart';

/// Firebase options for NeighborHelp (`neighborhelp-63771`).
///
/// API keys come from `--dart-define-from-file=secrets.local.json` (see [AppSecrets]).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  /// Web `apiKey` must stay the Firebase **Browser** key (Project settings → Web app — copy exactly;
  /// a wrong `l` vs `I` breaks Auth). Maps-only restrictions on that key also break Auth.
  /// Maps uses the separate key in `web/index.html` only.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: AppSecrets.firebaseWebApiKey,
    appId: '1:181576858549:web:5985a881da4dc32ca2f7fc',
    messagingSenderId: '181576858549',
    projectId: 'neighborhelp-63771',
    authDomain: 'neighborhelp-63771.firebaseapp.com',
    storageBucket: 'neighborhelp-63771.firebasestorage.app',
    measurementId: 'G-0TY9PHKJK1',
  );

  /// Values from `android/app/google-services.json` (must match registered Android app).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: AppSecrets.firebaseAndroidApiKey,
    appId: '1:181576858549:android:f2861176c57c201ca2f7fc',
    messagingSenderId: '181576858549',
    projectId: 'neighborhelp-63771',
    storageBucket: 'neighborhelp-63771.firebasestorage.app',
  );
}
