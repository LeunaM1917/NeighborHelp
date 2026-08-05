import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_breakpoints.dart';

/// Layout helpers for Android/iOS builds and narrow viewports.
abstract final class MobileLayout {
  /// True when running the installed app (not Flutter web).
  static bool get isNativePlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static bool isNativeApp(BuildContext context) => isNativePlatform;

  /// Native app or compact window — use mobile chrome (bottom nav, sheets, etc.).
  static bool useMobileChrome(BuildContext context) =>
      isNativeApp(context) || AdaptiveBreakpoints.isCompact(context);

  /// Marketing footers are hidden on native apps to save vertical space.
  static bool hideMarketingFooter(BuildContext context) => isNativeApp(context);

  /// Popovers become bottom sheets on native / compact layouts.
  static bool useBottomSheets(BuildContext context) => useMobileChrome(context);

  static double heroVerticalPadding(BuildContext context) =>
      isNativeApp(context) ? 24 : 40;

  static double pageBottomPadding(BuildContext context) =>
      isNativeApp(context) ? 24 : 48;
}
