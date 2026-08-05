import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'figma_colors.dart';

/// Horizontally centers [child] with max width [maxWidth] without using [Center],
/// which expands to infinite height and breaks inside scrollables / unbounded columns.
class FigmaNarrowContent extends StatelessWidget {
  const FigmaNarrowContent({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = math.min(maxWidth, c.maxWidth);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: w),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// `max-w-7xl` (1280px) + horizontal padding `px-4 sm:px-6 lg:px-8`.
class FigmaWideContainer extends StatelessWidget {
  const FigmaWideContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = c.maxWidth >= 1024 ? 32.0 : c.maxWidth >= 640 ? 24.0 : 16.0;
        final inner = math.max(0.0, c.maxWidth - 2 * pad);
        final maxContent = math.min(1280.0, inner);
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Equal-width [Wrap] rows: children share the same cell width (like a grid) while
/// height is intrinsic. Use instead of [GridView] + fixed [mainAxisExtent] when
/// card body text length varies (avoids bottom overflow stripes).
class FigmaWrapCardGrid extends StatelessWidget {
  const FigmaWrapCardGrid({
    super.key,
    required this.maxWidth,
    required this.columns,
    this.gap = 32,
    required this.children,
  });

  /// Typically [LayoutBuilder] `constraints.maxWidth` for the padded content area.
  final double maxWidth;
  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cols = columns.clamp(1, 24);
    final safeW = (maxWidth.isFinite && maxWidth > 0) ? maxWidth : 320.0;
    final inner = safeW - gap * (cols - 1);
    final cellW = cols > 0 && inner > 0 ? inner / cols : safeW;
    final w = cellW > 0 ? cellW : safeW;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final child in children) SizedBox(width: w, child: child)],
    );
  }
}

/// Hero gradient `from-[#e8eef5] to-white`.
class FigmaHeroGradientBackground extends StatelessWidget {
  const FigmaHeroGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FigmaColors.tintBlue, FigmaColors.white],
        ),
      ),
      child: child,
    );
  }
}

/// CTA section `from-[#1e3a5f] to-[#152d47]`.
class FigmaNavyCtaGradient extends StatelessWidget {
  const FigmaNavyCtaGradient({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FigmaColors.navy, FigmaColors.navyHover],
        ),
      ),
      child: child,
    );
  }
}
