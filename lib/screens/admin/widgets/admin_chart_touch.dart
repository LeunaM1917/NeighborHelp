import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';

/// High-contrast bar chart tooltips for admin dashboards (readable on hover).
BarTouchData adminBarChartTouchData({
  required List<String> rodLabels,
  required List<Color> rodColors,
}) {
  return BarTouchData(
    enabled: true,
    handleBuiltInTouches: true,
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => FigmaColors.white,
      tooltipBorder: const BorderSide(color: FigmaColors.gray300, width: 1),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tooltipMargin: 10,
      tooltipRoundedRadius: 8,
      direction: TooltipDirection.auto,
      getTooltipItem: (group, groupIndex, rod, rodIndex) {
        final label = rodIndex < rodLabels.length ? rodLabels[rodIndex] : 'Count';
        final color = rodIndex < rodColors.length ? rodColors[rodIndex] : FigmaColors.gray900;
        final value = rod.toY.round();
        return BarTooltipItem(
          '$label: $value',
          GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          children: [
            TextSpan(
              text: '\n${value == 1 ? '1 booking' : '$value bookings'}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: FigmaColors.gray600,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Pie/donut hover and tap — updates [onSectionIndex] with the touched slice index, or null.
PieTouchData adminPieChartTouchData({
  required ValueChanged<int?> onSectionIndex,
}) {
  return PieTouchData(
    enabled: true,
    mouseCursorResolver: (event, response) {
      return response?.touchedSection != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic;
    },
    touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
      if (!event.isInterestedForInteractions ||
          response == null ||
          response.touchedSection == null) {
        onSectionIndex(null);
        return;
      }
      onSectionIndex(response.touchedSection!.touchedSectionIndex);
    },
  );
}

/// Floating tooltip shown above admin pie/donut charts on hover.
class AdminPieChartTooltip extends StatelessWidget {
  const AdminPieChartTooltip({
    super.key,
    required this.label,
    required this.value,
    required this.percentLabel,
    required this.color,
  });

  final String label;
  final int value;
  final String percentLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FigmaColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FigmaColors.gray300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
            Text(
              '$value ($percentLabel)',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: FigmaColors.gray600),
            ),
          ],
        ),
      ),
    );
  }
}
