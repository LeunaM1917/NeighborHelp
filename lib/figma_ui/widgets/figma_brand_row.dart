import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';

/// Header / footer logotype: optional mark + "Neighbor" (navy) + "Help" (green).
/// When [logoAssetPath] is set, that image replaces the gradient placeholder mark.
class FigmaBrandRow extends StatelessWidget {
  const FigmaBrandRow({
    super.key,
    required this.logoHeight,
    required this.titleFontSize,
    this.logoAssetPath,
    this.onTap,
    this.constrained = false,
    this.showTitle = true,
  });

  final double logoHeight;
  final double titleFontSize;
  /// Asset key from pubspec (e.g. `branding/nav_logo.png`).
  final String? logoAssetPath;
  final VoidCallback? onTap;
  /// When true, title ellipsizes so the row fits narrow app bars (mobile).
  final bool constrained;
  /// When false, only the logo mark is shown (e.g. full wordmark image).
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      fontSize: titleFontSize,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final Widget mark = logoAssetPath != null && !showTitle
        ? Image.asset(
            logoAssetPath!,
            height: logoHeight,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _GradientMark(logoHeight: logoHeight),
          )
        : SizedBox(
            height: logoHeight,
            child: AspectRatio(
              aspectRatio: 1,
              child: logoAssetPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        logoAssetPath!,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => _GradientMark(logoHeight: logoHeight),
                      ),
                    )
                  : _GradientMark(logoHeight: logoHeight),
            ),
          );
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Neighbor', style: titleStyle.copyWith(color: FigmaColors.navy)),
          TextSpan(text: 'Help', style: titleStyle.copyWith(color: FigmaColors.green)),
        ],
      ),
      maxLines: 1,
      overflow: constrained ? TextOverflow.ellipsis : TextOverflow.visible,
      softWrap: !constrained,
    );
    final row = Row(
      mainAxisSize: constrained ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (constrained && !showTitle) Expanded(child: mark) else mark,
        if (showTitle) ...[
          SizedBox(width: constrained ? 8 : 12),
          if (constrained) Expanded(child: title) else title,
        ],
      ],
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: FigmaColors.gray100.withValues(alpha: 0.65),
          splashColor: FigmaColors.tintBlue.withValues(alpha: 0.28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: row,
          ),
        ),
      ),
    );
  }
}

class _GradientMark extends StatelessWidget {
  const _GradientMark({required this.logoHeight});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FigmaColors.navy, FigmaColors.green],
        ),
      ),
      child: Icon(Icons.groups_2_rounded, color: Colors.white.withValues(alpha: 0.92), size: logoHeight * 0.55),
    );
  }
}
