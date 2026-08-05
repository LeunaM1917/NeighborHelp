import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Backward-compatible aliases — prefer [Theme.of(context).colorScheme] in new code.
abstract final class ProviderTokens {
  static const Color green = AppColors.green;
  static const Color greenPressed = AppColors.greenHover;
  static const Color ink = AppColors.gray900;
  static const Color inkSecondary = AppColors.gray600;
  static const Color pageBg = AppColors.gray50;
  static const Color card = AppColors.white;
  static const Color border = AppColors.gray200;
  static const Color greenTint = AppColors.tintGreen;
  static const Color danger = AppColors.danger;
}
