import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/identity_verification.dart';
import '../../../utils/identity_verification_issues.dart';

class AdminVerificationDetailsDialog extends StatelessWidget {
  const AdminVerificationDetailsDialog({
    super.key,
    required this.name,
    required this.verification,
    required this.onRefresh,
  });

  final String name;
  final IdentityVerification verification;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verification details'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Status: ${verification.verificationStatus}'),
            if (verification.governmentIdTypeLabel.isNotEmpty)
              Text('Document: ${verification.governmentIdTypeLabel}'),
            const SizedBox(height: 16),
            ...identityVerificationIssues(verification).map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(issue),
              ),
            ),
            if (verification.verificationIssueCodes.isNotEmpty)
              const Text(
                'These are saved ID Analyzer warnings. The current approval status is shown above.',
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onRefresh();
        },
        child: const Text('Refresh ID Analyzer'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}
