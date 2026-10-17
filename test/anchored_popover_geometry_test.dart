import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/widgets/anchored_popover_geometry.dart';

void main() {
  for (final height in [360.0, 768.0, 1080.0]) {
    for (final maxHeight in [420.0, 480.0]) {
      test(
        'rail utility popover fits viewport $height with maximum $maxHeight',
        () {
          final rect = anchoredPopoverRect(
            viewport: Size(1280, height),
            anchor: Rect.fromLTWH(24, height - 60, 48, 48),
            preferredWidth: 400,
            maxHeight: maxHeight,
            openBesideAnchor: true,
          );
          expect(rect.left, greaterThanOrEqualTo(72));
          expect(rect.top, greaterThanOrEqualTo(12));
          expect(rect.right, lessThanOrEqualTo(1268));
          expect(rect.bottom, lessThanOrEqualTo(height - 12));
        },
      );
    }
  }

  test('header popover stays below its button when there is room', () {
    final rect = anchoredPopoverRect(
      viewport: const Size(1280, 800),
      anchor: const Rect.fromLTWH(1150, 8, 48, 48),
      preferredWidth: 400,
      maxHeight: 480,
    );
    expect(rect.left, 798);
    expect(rect.top, 66);
  });
}
