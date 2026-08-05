import 'package:flutter/widgets.dart';

/// Keys must match [pubspec.yaml] `flutter: assets:` entries./// Use paths **without** a leading `assets/` segment so Flutter Web does not
/// request `assets/assets/...` (404).
abstract final class FigmaMarketingAssets {
  static const navLogo = 'branding/nav_logo.png';
  static const footerLogo = 'branding/footer_logo.jpg';

  /// In-app header mark (icon only — pair with [FigmaBrandRow] title text).
  static String appLogoFor(BuildContext context) => navLogo;

  /// Full wordmark image used in marketing footer — not the compact app bar.
  static bool logoIncludesWordmark(String assetPath) => assetPath == footerLogo;
}
