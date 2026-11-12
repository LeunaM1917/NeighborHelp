import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/provider_theme.dart';

/// Consistent, keyboard-aware frame for provider profile section editors.
class ProviderProfileEditorDialog extends StatelessWidget {
  const ProviderProfileEditorDialog({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;
  static const closeKey = ValueKey('provider-profile-editor-close');
  static const surfaceKey = ValueKey('provider-profile-editor-surface');

  static Future<bool?> open(
    BuildContext context, {
    required String title,
    required Widget child,
  }) => showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) =>
        providerThemed(ProviderProfileEditorDialog(title: title, child: child)),
  );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: FigmaColors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      key: surfaceKey,
      width: 720,
      height: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 72, 20),
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: FigmaColors.navy,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: closeKey,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: FigmaColors.gray600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: FigmaColors.gray200),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
