import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'marketplace_ui.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message, this.showBrand = false});

  final String? message;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBrand) ...[
            const BrandLockup(compact: true, subtitle: null),
            const SizedBox(height: 28),
          ],
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
