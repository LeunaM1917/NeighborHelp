import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Backward-compatible Figma palette — maps to unified [AppColors].
abstract final class FigmaColors {
  static const Color navy = AppColors.navy;
  static const Color navyHover = AppColors.navyHover;
  static const Color green = AppColors.green;
  static const Color greenHover = AppColors.greenHover;
  static const Color tintBlue = AppColors.tintBlue;
  static const Color tintGreen = AppColors.tintGreen;
  static const Color tintGreen2 = AppColors.tintGreen2;
  static const Color tintGreen3 = AppColors.tintGreen2;
  static const Color connectorLine = AppColors.connectorLine;
  static const Color footerNeighbor = AppColors.footerNeighbor;
  static const Color footerHelp = AppColors.footerHelp;

  static const Color gray50 = AppColors.gray50;
  static const Color gray100 = AppColors.gray100;
  static const Color gray200 = AppColors.gray200;
  static const Color gray300 = AppColors.gray300;
  static const Color gray400 = AppColors.gray400;
  static const Color gray500 = AppColors.gray500;
  static const Color gray600 = AppColors.gray600;
  static const Color gray700 = AppColors.gray700;
  static const Color gray800 = AppColors.gray800;
  static const Color gray900 = AppColors.gray900;
  static const Color gray900Footer = AppColors.gray900;

  static const Color white = AppColors.white;
  static const Color orange50 = AppColors.orange50;
  static const Color orange600 = AppColors.orange600;
  static const Color purple50 = AppColors.purple50;
  static const Color purple600 = AppColors.purple600;
  static const Color red50 = AppColors.red50;
  static const Color red600 = AppColors.red600;
  static const Color indigo50 = AppColors.indigo50;
  static const Color indigo600 = AppColors.indigo600;
  static const Color yellow50 = AppColors.yellow50;
  static const Color yellow500 = AppColors.yellow500;
  static const Color blueGoogle = AppColors.blueGoogle;
  static const Color purple100 = AppColors.purple50;
}

/// Theme-aware helpers for marketing / shell surfaces.
extension FigmaColorsContext on BuildContext {
  ColorScheme get nhColors => Theme.of(this).colorScheme;

  Color get nhPageBg => nhColors.surfaceContainerLow;

  Color get nhCard => nhColors.surface;

  Color get nhBorder => nhColors.outline;

  Color get nhInk => nhColors.onSurface;

  Color get nhInkSecondary => nhColors.onSurfaceVariant;
}
