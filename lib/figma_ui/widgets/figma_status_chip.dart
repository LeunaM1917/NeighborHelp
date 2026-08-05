import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_colors.dart';

class FigmaStatusChip extends StatelessWidget {
  const FigmaStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  (Color, Color) _colors(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'milestone complete':
        return (FigmaColors.tintGreen, FigmaColors.green);
      case 'active':
        return (FigmaColors.tintGreen, FigmaColors.green);
      case 'ended':
        return (FigmaColors.gray100, FigmaColors.gray700);
      case 'cancelled':
      case 'canceled':
        return (FigmaColors.red50, FigmaColors.red600);
      case 'in progress':
      case 'accepted':
        return (FigmaColors.tintBlue, FigmaColors.navy);
      default:
        return (FigmaColors.gray100, FigmaColors.gray700);
    }
  }
}
