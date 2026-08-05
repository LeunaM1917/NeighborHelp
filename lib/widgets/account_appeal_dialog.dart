import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/support_config.dart';
import '../figma_ui/figma_colors.dart';
import '../models/account_status.dart';

/// Explains how to email support to appeal a suspended or deactivated account.
Future<void> showAccountAppealDialog(
  BuildContext context, {
  required AccountStatus status,
  String? userEmail,
  String? userName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _AccountAppealDialog(
      status: status,
      userEmail: userEmail,
      userName: userName,
    ),
  );
}

class _AccountAppealDialog extends StatelessWidget {
  const _AccountAppealDialog({
    required this.status,
    this.userEmail,
    this.userName,
  });

  final AccountStatus status;
  final String? userEmail;
  final String? userName;

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: SupportConfig.appealEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support email copied')),
      );
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    final uri = SupportConfig.appealMailto(userEmail: userEmail, userName: userName);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email ${SupportConfig.appealEmail} manually')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.lock_outline, color: colorScheme.error, size: 32),
      title: Text(
        status.blockedTitle,
        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your account cannot be used right now. To request a review and possible reinstatement, '
              'email our support team with your full name and the email on this account.',
              style: GoogleFonts.inter(fontSize: 14, height: 1.45, color: FigmaColors.gray700),
            ),
            const SizedBox(height: 16),
            Text(
              'Appeal email',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray600),
            ),
            const SizedBox(height: 6),
            SelectableText(
              SupportConfig.appealEmail,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: FigmaColors.navy,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _copyEmail(context),
          child: const Text('Copy email'),
        ),
        FilledButton.icon(
          onPressed: () => _openEmail(context),
          icon: const Icon(Icons.mail_outline, size: 18),
          label: const Text('Open email app'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
