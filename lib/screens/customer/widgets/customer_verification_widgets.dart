import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../services/identity_verification_service.dart';
import '../../provider/widgets/provider_profile_widgets.dart';
import '../../../widgets/member_profile/member_profile_kit.dart';

/// Government ID verification for customers (Didit + admin badge).
class CustomerVerificationTrustCard extends StatelessWidget {
  const CustomerVerificationTrustCard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final v = user.identityVerification;
    final verified = user.isVerifiedCustomer;
    final awaitingAdmin = user.isAwaitingVerificationApproval;
    final inReview = user.isVerificationInReview;
    final declined = user.isVerificationDeclined;

    final idLabel = v.governmentIdTypeLabel;
    final String idSubtitle;
    if (verified) {
      idSubtitle = idLabel.isNotEmpty ? '$idLabel verified' : 'Government ID verified';
    } else if (awaitingAdmin) {
      idSubtitle = idLabel.isNotEmpty
          ? '$idLabel verified by Didit — awaiting admin approval'
          : 'Didit check complete — awaiting admin approval';
    } else if (inReview) {
      idSubtitle = idLabel.isNotEmpty ? '$idLabel — finish on Didit' : 'Complete verification on Didit';
    } else if (declined) {
      idSubtitle = idLabel.isNotEmpty ? '$idLabel — verification failed' : 'Verification failed — try again';
    } else {
      idSubtitle = 'Verify with National ID, Passport, Driver\'s license, or Residence permit on Didit';
    }

    return MemberProfileSectionCard(
      title: 'Verification & trust',
      icon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                verified ? Icons.check_circle : Icons.badge_outlined,
                size: 22,
                color: verified ? FigmaColors.green : FigmaColors.gray500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Government ID verified',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      idSubtitle,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!verified && !awaitingAdmin) ...[
            const SizedBox(height: 16),
            ProviderVerifyIdentityButton(
              subject: VerificationSubject.customer,
              governmentIdTypeCode: v.governmentIdTypeCode,
              governmentIdTypeLabel: v.governmentIdTypeLabel,
              inReview: inReview,
              declined: declined,
              callbackUrl: _customerVerificationCallbackUrl(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Didit return URL that keeps the customer shell after verification.
String? _customerVerificationCallbackUrl() {
  if (!kIsWeb) return null;
  final base = Uri.base;
  return base.replace(
    queryParameters: <String, String>{
      ...base.queryParameters,
      'nh_role': 'customer',
    },
  ).toString();
}
