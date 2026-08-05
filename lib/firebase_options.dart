import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for NeighborHelp (`neighborhelp-63771`).
///
/// Regenerate anytime with: `dart pub global activate flutterfire_cli` then `flutterfire configure`.
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
    apiKey: 'AIzaSyDUQ1heNiWueMx0ImzV5OFwbOC4fzMGTlI',
    appId: '1:181576858549:web:5985a881da4dc32ca2f7fc',
    messagingSenderId: '181576858549',
    projectId: 'neighborhelp-63771',
    authDomain: 'neighborhelp-63771.firebaseapp.com',
    storageBucket: 'neighborhelp-63771.firebasestorage.app',
    measurementId: 'G-0TY9PHKJK1',
  );

  /// Values from `android/app/google-services.json` (must match registered Android app).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZINwfR0mbMrme9doWkSoNp7-fMnWV1sQ',
    appId: '1:181576858549:android:f2861176c57c201ca2f7fc',
    messagingSenderId: '181576858549',
    projectId: 'neighborhelp-63771',
    storageBucket: 'neighborhelp-63771.firebasestorage.app',
  );
}
