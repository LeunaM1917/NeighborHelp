import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData neighborHelpTheme({Brightness brightness = Brightness.light, TargetPlatform? platform}) {
  final scheme = brightness == Brightness.dark ? AppColors.darkScheme() : AppColors.lightScheme();
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final isCupertino = resolvedPlatform == TargetPlatform.iOS || resolvedPlatform == TargetPlatform.macOS;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLow,
    visualDensity: isCupertino ? VisualDensity.adaptivePlatformDensity : VisualDensity.standard,
    splashFactory: isCupertino ? NoSplash.splashFactory : InkRipple.splashFactory,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values)
          p: isCupertino && (p == TargetPlatform.iOS || p == TargetPlatform.macOS)
              ? const CupertinoPageTransitionsBuilder()
              : const FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  final borderRadius = isCupertino ? 10.0 : 8.0;
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(borderRadius),
    borderSide: BorderSide(color: scheme.outline),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius + 2),
        side: BorderSide(color: scheme.outline),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: scheme.onSurface),
      side: BorderSide(color: scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant, fontSize: 14),
      floatingLabelStyle: GoogleFonts.inter(color: scheme.primary, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.outline,
        disabledForegroundColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.secondary,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 72,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      selectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.primary,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      textStyle: GoogleFonts.inter(fontSize: 14, color: scheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: GoogleFonts.inter(color: scheme.onInverseSurface, fontSize: 14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      subtitleTextStyle: GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
    ),
  );
}

ThemeData neighborHelpLightTheme({TargetPlatform? platform}) =>
    neighborHelpTheme(brightness: Brightness.light, platform: platform);

ThemeData neighborHelpDarkTheme({TargetPlatform? platform}) =>
    neighborHelpTheme(brightness: Brightness.dark, platform: platform);
