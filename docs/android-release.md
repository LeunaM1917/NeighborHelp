# Android release

Release builds use `android/key.properties`, which is ignored by Git. The current signing key and a backup of its properties are stored privately under the Windows user's `.neighborhelp/android-release` directory. Back up that directory securely: future updates must use the same signing key. Never commit or upload the key, passwords, or local secrets.

Build and stage a signed, universal APK from the repository root. Increase the version and build number for each release:

```powershell
$env:DEBUG = ''
flutter build apk --release --build-name=1.0.1 --build-number=2026111301 --dart-define-from-file=secrets.local.json
powershell -ExecutionPolicy Bypass -File scripts/stage-android-download.ps1
flutter build web --release --dart-define-from-file=secrets.local.json --no-wasm-dry-run
firebase deploy --only hosting --project neighborhelp-63771
```

The staging script checks the APK's package, version and release signature, then places the APK, checksum and release metadata in the ignored `web/downloads` directory. Flutter copies these files into subsequent web builds on this computer, keeping published downloads available. Retain those artifacts or restore them before deploying from another checkout.

The current APK supports Android 7.0 (API 24) and newer and includes ARMv7, ARM64 and x86-64. This is a direct installation release, not a Google Play submission. An earlier debug-signed installation must be removed before installing the first release-signed APK; later releases can update it using the same release key.
