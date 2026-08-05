import 'package:flutter/material.dart';

import '../figma_ui/figma_colors.dart';

/// Selectable work-style labels shown on the provider overview (profile "traits").
abstract final class ProviderProfileTraits {
  static const maxBioLength = 500;

  static const options = <ProviderTraitOption>[
    ProviderTraitOption('Reliable', FigmaColors.tintBlue, FigmaColors.navy),
    ProviderTraitOption('On-time', FigmaColors.tintBlue, FigmaColors.navy),
    ProviderTraitOption('Friendly', FigmaColors.purple50, FigmaColors.purple600),
    ProviderTraitOption('Detail-oriented', FigmaColors.orange50, FigmaColors.orange600),
    ProviderTraitOption('Professional', FigmaColors.tintBlue, FigmaColors.navy),
    ProviderTraitOption('Great communicator', FigmaColors.purple50, FigmaColors.purple600),
    ProviderTraitOption('Flexible', FigmaColors.tintBlue, FigmaColors.navy),
  ];

  static List<String> normalize(List<String> raw) {
    final allowed = options.map((o) => o.label).toSet();
    return raw.where(allowed.contains).toList();
  }
}

class ProviderTraitOption {
  const ProviderTraitOption(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}
