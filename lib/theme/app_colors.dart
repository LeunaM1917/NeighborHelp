import 'package:flutter/material.dart';

/// Single source of truth for NeighborHelp brand colors (Figma landing palette).
abstract final class AppColors {
  // Brand
  static const Color navy = Color(0xFF1E3A5F);
  static const Color navyHover = Color(0xFF152D47);
  static const Color green = Color(0xFF4A7C2C);
  static const Color greenHover = Color(0xFF3D6624);

  // Tints
  static const Color tintBlue = Color(0xFFE8EEF5);
  static const Color tintGreen = Color(0xFFE8F4E0);
  static const Color tintGreen2 = Color(0xFFC8E6B8);

  // Neutrals (light)
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerContainer = Color(0xFFFEF2F2);

  // Accent palettes (categories, stats)
  static const Color orange50 = Color(0xFFFFF7ED);
  static const Color orange600 = Color(0xFFEA580C);
  static const Color purple50 = Color(0xFFFAF5FF);
  static const Color purple600 = Color(0xFF9333EA);
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red600 = Color(0xFFDC2626);
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color yellow50 = Color(0xFFFEFCE8);
  static const Color yellow500 = Color(0xFFEAB308);

  // Footer / brand accents
  static const Color footerNeighbor = Color(0xFF6B9BD1);
  static const Color footerHelp = Color(0xFF7FB857);
  static const Color connectorLine = Color(0xFFC5D8ED);
  static const Color blueGoogle = Color(0xFF4285F4);

  // Dark surfaces
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceContainer = Color(0xFF1F2937);
  static const Color darkSurfaceContainerHigh = Color(0xFF374151);
  static const Color darkOnSurface = Color(0xFFF3F4F6);
  static const Color darkOnSurfaceVariant = Color(0xFF9CA3AF);
  static const Color darkOutline = Color(0xFF4B5563);
  static const Color darkPrimary = Color(0xFF93B4D9);
  static const Color darkPrimaryContainer = Color(0xFF152D47);
  static const Color darkSecondary = Color(0xFF9FD67A);
  static const Color darkSecondaryContainer = Color(0xFF2D4A1A);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: navy,
      onPrimary: white,
      primaryContainer: tintBlue,
      onPrimaryContainer: navy,
      secondary: green,
      onSecondary: white,
      secondaryContainer: tintGreen,
      onSecondaryContainer: greenHover,
      tertiary: footerNeighbor,
      onTertiary: white,
      tertiaryContainer: tintBlue,
      onTertiaryContainer: navy,
      error: danger,
      onError: white,
      errorContainer: dangerContainer,
      onErrorContainer: red600,
      surface: white,
      onSurface: gray900,
      onSurfaceVariant: gray600,
      outline: gray200,
      outlineVariant: gray300,
      shadow: Color(0x1A000000),
      scrim: Color(0x66000000),
      inverseSurface: gray900,
      onInverseSurface: gray100,
      inversePrimary: darkPrimary,
      surfaceContainerHighest: gray100,
      surfaceContainerHigh: gray50,
      surfaceContainer: white,
      surfaceContainerLow: gray50,
      surfaceContainerLowest: white,
      surfaceBright: white,
      surfaceDim: gray100,
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: navyHover,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: tintBlue,
      secondary: darkSecondary,
      onSecondary: greenHover,
      secondaryContainer: darkSecondaryContainer,
      onSecondaryContainer: tintGreen,
      tertiary: footerNeighbor,
      onTertiary: navyHover,
      tertiaryContainer: Color(0xFF1E3A5F),
      onTertiaryContainer: tintBlue,
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: darkSurface,
      onSurface: darkOnSurface,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: gray700,
      shadow: Color(0x66000000),
      scrim: Color(0x99000000),
      inverseSurface: gray100,
      onInverseSurface: gray900,
      inversePrimary: navy,
      surfaceContainerHighest: darkSurfaceContainerHigh,
      surfaceContainerHigh: darkSurfaceContainer,
      surfaceContainer: darkSurfaceContainer,
      surfaceContainerLow: Color(0xFF1A2332),
      surfaceContainerLowest: darkSurface,
      surfaceBright: darkSurfaceContainerHigh,
      surfaceDim: darkSurface,
    );
  }
}
