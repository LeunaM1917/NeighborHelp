import 'package:flutter/material.dart';

import 'role_theme.dart';

/// Provider brand colors (navy). Use on all provider screens and dialogs.
abstract final class ProviderTheme {
  static const RolePalette palette = RoleTheme.provider;
}

extension ProviderThemeContext on BuildContext {
  /// Navy provider palette — never falls back to customer green.
  RolePalette get providerColors => RoleThemeScope.maybeOf(this) ?? RoleTheme.provider;
}

/// Ensures [child] uses provider navy theme (for dialogs and pushed routes).
Widget providerThemed(Widget child) {
  return RoleThemeScope(palette: RoleTheme.provider, child: child);
}
