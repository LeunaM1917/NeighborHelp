import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Primary UI colors per signed-in role.
abstract final class RoleTheme {
  static const customer = RolePalette(
    primary: AppColors.green,
    primaryHover: AppColors.greenHover,
    tint: AppColors.tintGreen,
    onPrimary: AppColors.white,
    badgeLabel: 'Customer',
  );

  static const provider = RolePalette(
    primary: AppColors.navy,
    primaryHover: AppColors.navyHover,
    tint: AppColors.tintBlue,
    onPrimary: AppColors.white,
    badgeLabel: 'Provider',
  );

  static const admin = RolePalette(
    primary: AppColors.navy,
    primaryHover: AppColors.navyHover,
    tint: AppColors.tintBlue,
    onPrimary: AppColors.white,
    badgeLabel: 'Admin',
  );

  static const verificationAgency = RolePalette(
    primary: AppColors.navy,
    primaryHover: AppColors.navyHover,
    tint: AppColors.tintBlue,
    onPrimary: AppColors.white,
    badgeLabel: 'Verification Agency',
  );

  static RolePalette forBadge(String roleBadge) {
    return switch (roleBadge.toLowerCase()) {
      'provider' => provider,
      'administrator' || 'admin' || 'admin console' => admin,
      'verification agency' || 'agency' || 'verifier' => verificationAgency,
      _ => customer,
    };
  }
}

class RolePalette {
  const RolePalette({
    required this.primary,
    required this.primaryHover,
    required this.tint,
    required this.onPrimary,
    required this.badgeLabel,
  });

  final Color primary;
  final Color primaryHover;
  final Color tint;
  final Color onPrimary;
  final String badgeLabel;
}

/// Provides [RolePalette] to the signed-in customer / provider / admin shell.
class RoleThemeScope extends InheritedWidget {
  const RoleThemeScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final RolePalette palette;

  static RolePalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RoleThemeScope>();
    assert(scope != null, 'RoleThemeScope not found');
    return scope!.palette;
  }

  static RolePalette? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RoleThemeScope>()?.palette;
  }

  @override
  bool updateShouldNotify(RoleThemeScope oldWidget) => palette != oldWidget.palette;
}

extension RoleThemeContext on BuildContext {
  RolePalette get roleColors => RoleThemeScope.maybeOf(this) ?? RoleTheme.customer;
}
