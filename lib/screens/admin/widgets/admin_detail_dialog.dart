import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';

/// One action button in an admin record detail dialog.
class AdminDetailAction {
  const AdminDetailAction({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final bool destructive;
}

/// Opens a scrollable detail dialog for any admin table row.
Future<void> showAdminRecordDetailDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<Widget> body,
  List<AdminDetailAction> actions = const [],
  double maxWidth = 520,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
          ],
        ],
      ),
      content: SizedBox(
        width: maxWidth,
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        for (final action in actions)
          if (action.filled)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                action.onPressed();
              },
              style: FilledButton.styleFrom(
                backgroundColor: action.destructive ? FigmaColors.red600 : FigmaColors.green,
                foregroundColor: FigmaColors.white,
              ),
              child: Text(action.label),
            )
          else
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                action.onPressed();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: action.destructive ? FigmaColors.red600 : FigmaColors.gray800,
                side: BorderSide(color: action.destructive ? FigmaColors.red600 : FigmaColors.gray300),
              ),
              child: Text(action.label),
            ),
      ],
    ),
  );
}

Widget adminDetailLine(String label, String value) {
  if (value.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray800, height: 1.4),
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

/// Makes a table cell open the row detail dialog on tap (shows link styling).
class AdminTableDetailTap extends StatelessWidget {
  const AdminTableDetailTap({
    super.key,
    required this.onOpen,
    required this.child,
    this.tooltip = 'View details',
  });

  final VoidCallback onOpen;
  final Widget child;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: child,
        ),
      ),
    );
  }
}

/// Compact "View" control used in admin table action columns.
class AdminTableViewButton extends StatelessWidget {
  const AdminTableViewButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FigmaColors.gray800,
        side: const BorderSide(color: FigmaColors.gray300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text('View', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
