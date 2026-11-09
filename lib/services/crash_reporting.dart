import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashReporting {
  static const _configured = bool.fromEnvironment('CRASH_REPORTING_ENABLED');
  static bool _emulators = false, _ready = false;
  static bool get available =>
      _ready &&
      !_emulators &&
      _configured &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static final consent = ValueNotifier<bool>(false);
  static String safeDescription(Object error) =>
      'Unhandled ${error.runtimeType}';
  static Future<void> initialize({required bool useEmulators}) async {
    _emulators = useEmulators;
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    try {
      if (useEmulators || !_configured) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          false,
        );
        await FirebaseCrashlytics.instance.deleteUnsentReports();
        consent.value = false;
        return;
      }
      final savedConsent =
          (await SharedPreferences.getInstance()).getBool(
            'share_crash_diagnostics',
          ) ??
          false;
      // A successfully disabled native SDK wins if app-preference persistence failed.
      final allowed =
          savedConsent &&
          FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        allowed,
      );
      if (!allowed) await FirebaseCrashlytics.instance.deleteUnsentReports();
      consent.value = allowed;
      _ready = true;
      final previousFlutter = FlutterError.onError;
      FlutterError.onError = (details) {
        previousFlutter?.call(details);
        _record(details.exception, details.stack);
      };
      final previousPlatform = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        _record(error, stack);
        return previousPlatform?.call(error, stack) ?? false;
      };
    } catch (_) {
      _ready = false;
      consent.value = false;
      try {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          false,
        );
      } catch (_) {
        /* App error reporting remains disabled. */
      }
    }
  }

  static void _record(Object error, StackTrace? stack) {
    if (!available || !consent.value) return;
    // Raw exceptions can contain chat, addresses or transaction references.
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(StateError(safeDescription(error)), stack, fatal: true)
          .catchError((_) {}),
    );
  }

  static Future<void> setConsent(bool enabled) async {
    if (!enabled) consent.value = false;
    if (!available) return;
    if (!enabled) {
      await revokeConsent(
        savePreference: () async {
          await (await SharedPreferences.getInstance()).setBool(
            'share_crash_diagnostics',
            false,
          );
        },
        disableNative: () =>
            FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false),
        deleteUnsent: () => FirebaseCrashlytics.instance.deleteUnsentReports(),
      );
      return;
    }
    await (await SharedPreferences.getInstance()).setBool(
      'share_crash_diagnostics',
      enabled,
    );
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    consent.value = enabled;
  }

  @visibleForTesting
  static Future<void> revokeConsent({
    required Future<void> Function() savePreference,
    required Future<void> Function() disableNative,
    required Future<void> Function() deleteUnsent,
  }) async {
    consent.value = false;
    // Attempt every safeguard even when a platform or storage operation fails.
    await Future.wait<void>([
      Future.sync(disableNative),
      Future.sync(deleteUnsent),
      Future.sync(savePreference),
    ]);
  }
}
