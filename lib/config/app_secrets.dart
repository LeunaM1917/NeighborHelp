/// Google / Firebase API keys loaded at compile time.
///
/// Copy [secrets.example.json] to `secrets.local.json` in the repo root, fill in values,
/// run `scripts/sync-secrets.ps1`, then build/run with:
/// `flutter run --dart-define-from-file=secrets.local.json`
class AppSecrets {
  static const firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );

  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: '',
  );

  static const googleMapsWebApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_WEB_API_KEY',
    defaultValue: '',
  );

  static const googleMapsAndroidApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_ANDROID_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      firebaseWebApiKey.isNotEmpty &&
      firebaseAndroidApiKey.isNotEmpty &&
      googleMapsWebApiKey.isNotEmpty &&
      googleMapsAndroidApiKey.isNotEmpty;
}
