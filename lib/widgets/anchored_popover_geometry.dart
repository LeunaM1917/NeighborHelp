import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps utility popovers visible beside the rail or below a header button.
Rect anchoredPopoverRect({
  required Size viewport,
  required Rect anchor,
  required double preferredWidth,
  required double maxHeight,
  bool openBesideAnchor = false,
}) {
  const margin = 12.0;
  final width = math.min(
    preferredWidth,
    math.max(0.0, viewport.width - margin * 2),
  );
  final height = math.min(
    maxHeight,
    math.max(0.0, viewport.height - margin * 2),
  );
  final desiredLeft = openBesideAnchor
      ? anchor.right + margin
      : anchor.right - width;
  final desiredTop = openBesideAnchor
      ? anchor.bottom - height
      : anchor.bottom + 10 + height <= viewport.height - margin
      ? anchor.bottom + 10
      : anchor.top - height - 10;
  return Rect.fromLTWH(
    desiredLeft.clamp(
      margin,
      math.max(margin, viewport.width - width - margin),
    ),
    desiredTop.clamp(
      margin,
      math.max(margin, viewport.height - height - margin),
    ),
    width,
    height,
  );
}
