import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/role_theme.dart';
import 'app_shell_tab.dart';

/// Shared desktop navigation for signed-in customer and provider workspaces.
/// Destinations and navigation behavior remain owned by the role's shell.
class AppShellSidebar extends StatelessWidget {
  const AppShellSidebar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    required this.roleBadge,
    this.iconBuilder,
  });

  static const double width = 248;

  final List<AppShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final String roleBadge;
  final Widget Function(int index, bool selected)? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final role = context.roleColors;

    return Material(
      color: colors.surface,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.outline)),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${roleBadge.toUpperCase()} WORKSPACE',
                style: GoogleFonts.inter(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Semantics(
                  selected: i == currentIndex,
                  child: ListTile(
                    selected: i == currentIndex,
                    selectedTileColor: role.tint,
                    selectedColor: role.primary,
                    textColor: colors.onSurfaceVariant,
                    iconColor: colors.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    minTileHeight: 48,
                    horizontalTitleGap: 12,
                    leading:
                        iconBuilder?.call(i, i == currentIndex) ??
                        Icon(
                          i == currentIndex
                              ? tabs[i].selectedIcon
                              : tabs[i].icon,
                          size: 20,
                        ),
                    title: Text(
                      tabs[i].label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: i == currentIndex
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    onTap: () => onTabChanged(i),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
