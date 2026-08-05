import 'package:flutter/material.dart';

class AppShellTab {
  const AppShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.shortLabel,
  });

  final String label;
  /// Shorter label for bottom navigation on phones (defaults to [label]).
  final String? shortLabel;
  final IconData icon;
  final IconData selectedIcon;

  String navLabel({required bool compact}) {
    if (compact && shortLabel != null) return shortLabel!;
    return label;
  }
}
