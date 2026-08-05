import 'package:flutter/material.dart';

/// M3-inspired window size classes for adaptive layout.
enum AppWindowSizeClass {
  compact,
  medium,
  expanded,
}

abstract final class AdaptiveBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  /// Marketing header switches to desktop nav (matches original Figma layout).
  static const double marketingNav = 768;

  static AppWindowSizeClass sizeClassOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= expanded) return AppWindowSizeClass.expanded;
    if (width >= medium) return AppWindowSizeClass.medium;
    return AppWindowSizeClass.compact;
  }

  static bool isExpanded(BuildContext context) =>
      sizeClassOf(context) == AppWindowSizeClass.expanded;

  static bool isCompact(BuildContext context) =>
      sizeClassOf(context) == AppWindowSizeClass.compact;
}
