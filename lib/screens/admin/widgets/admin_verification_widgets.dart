import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/identity_verification.dart';
import '../../../models/provider.dart';
import 'admin_dashboard_widgets.dart';
import 'admin_providers_widgets.dart';

class AdminVerificationPageHeader extends StatelessWidget {
  const AdminVerificationPageHeader({
    super.key,
    this.title = 'Identity verification',
    this.subtitle = 'Monitor Didit ID checks. Primary approval is by the Verification Agency.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: FigmaColors.tintGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.verified_user_outlined, color: FigmaColors.green, size: 26),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.gray900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AdminVerificationStatCard extends StatelessWidget {
  const AdminVerificationStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.hint,
    required this.hintColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String value;
  final String label;
  final String hint;
  final Color hintColor;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
                ),
                const SizedBox(height: 2),
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray800)),
                const SizedBox(height: 2),
                Text(hint, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminVerificationEmptyState extends StatelessWidget {
  const AdminVerificationEmptyState({
    super.key,
    this.showPendingMessage = true,
    this.onNotifyTap,
  });

  final bool showPendingMessage;
  final VoidCallback? onNotifyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        children: [
          const _VerificationEmptyIllustration(),
          const SizedBox(height: 28),
          Text(
            showPendingMessage ? 'No pending verifications' : 'No applications found',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            showPendingMessage
                ? 'All provider applications have been reviewed. New submissions will appear here.'
                : 'Try adjusting your search or filters to find provider applications.',
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray500, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onNotifyTap,
            icon: const Icon(Icons.notifications_outlined, size: 18),
            label: Text(
              'Notify me of new applications',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.green,
              side: const BorderSide(color: FigmaColors.green),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationEmptyIllustration extends StatelessWidget {
  const _VerificationEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            right: 24,
            child: Icon(Icons.cloud_outlined, size: 36, color: FigmaColors.tintGreen.withValues(alpha: 0.6)),
          ),
          Positioned(
            top: 20,
            left: 16,
            child: Icon(Icons.eco_outlined, size: 28, color: FigmaColors.green.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Icon(Icons.eco_outlined, size: 22, color: FigmaColors.green.withValues(alpha: 0.25)),
          ),
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              color: FigmaColors.gray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FigmaColors.gray200),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.description_outlined, size: 64, color: FigmaColors.gray300),
                Positioned(
                  bottom: 28,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: FigmaColors.tintGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: FigmaColors.white, width: 3),
                    ),
                    child: const Icon(Icons.verified_user, color: FigmaColors.green, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _pendingDiditHint(IdentityVerification v) {
  if (v.isDeclined) return 'Didit declined';
  if (v.isInReview) return 'Didit in progress';
  if (v.diditStatus.isNotEmpty) return 'Didit: ${v.diditStatus}';
  return 'Awaiting Didit verification';
}

/// Compact chip for raw Didit session status on admin queues.
class AdminDiditStatusChip extends StatelessWidget {
  const AdminDiditStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;
    if (lower == 'approved') {
      bg = FigmaColors.tintGreen;
      fg = FigmaColors.green;
    } else if (lower == 'declined') {
      bg = FigmaColors.red50;
      fg = FigmaColors.red600;
    } else if (lower.contains('review') || lower.contains('progress')) {
      bg = FigmaColors.yellow50;
      fg = FigmaColors.orange600;
    } else {
      bg = FigmaColors.gray100;
      fg = FigmaColors.gray600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        'Didit: $status',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class AdminVerificationApplicationCard extends StatelessWidget {
  const AdminVerificationApplicationCard({
    super.key,
    required this.application,
    required this.onApprove,
    required this.onReject,
    required this.onRefreshDidit,
  });

  final AdminVerificationApplication application;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRefreshDidit;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final app = application;
    final name = app.displayName;
    final email = app.displayEmail;
    final photoUrl = app.photoUrl;
    final v = app.verification;
    final isPending = providerVerificationBucket(v.verificationStatus, v.isVerified) == 1;
    final canReview = app.canAdminReview;

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: app.isCustomer ? FigmaColors.tintBlue : FigmaColors.tintGreen,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null
              ? Text(
                  adminInitials(name),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: app.isCustomer ? FigmaColors.navy : FigmaColors.green,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              if (app.businessLabel.isNotEmpty)
                Text(app.businessLabel, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600)),
              Text(email, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: app.isCustomer ? FigmaColors.tintBlue : FigmaColors.tintGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      app.isCustomer ? 'Customer' : 'Provider',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: app.isCustomer ? FigmaColors.navy : FigmaColors.green,
                      ),
                    ),
                  ),
                  if (!app.isCustomer && app.profile!.serviceArea.isNotEmpty)
                    Text(app.profile!.serviceArea, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
                  AdminProviderVerificationChip(status: v.verificationStatus),
                  if (v.diditStatus.isNotEmpty) AdminDiditStatusChip(status: v.diditStatus),
                  Text(
                    'Submitted ${dateFmt.format(app.submittedAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isPending && canReview) ...[
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.red600,
              side: const BorderSide(color: FigmaColors.red600),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: onApprove,
            style: FilledButton.styleFrom(
              backgroundColor: FigmaColors.green,
              foregroundColor: FigmaColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Approve', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ] else if (isPending) ...[
          Text(
            _pendingDiditHint(v),
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, fontWeight: FontWeight.w500),
          ),
          OutlinedButton.icon(
            onPressed: onRefreshDidit,
            icon: const Icon(Icons.sync, size: 16),
            style: OutlinedButton.styleFrom(
              foregroundColor: FigmaColors.navy,
              side: const BorderSide(color: FigmaColors.gray300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            label: Text('Refresh Didit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ]
        else
          Text(
            'Reviewed',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, fontWeight: FontWeight.w600),
          ),
      ],
    );

    return Container(
      key: ValueKey(app.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}

class AdminVerificationApplicationsList extends StatelessWidget {
  const AdminVerificationApplicationsList({
    super.key,
    required this.applications,
    required this.onApprove,
    required this.onReject,
    required this.onRefreshDidit,
  });

  final List<AdminVerificationApplication> applications;
  final void Function(AdminVerificationApplication application) onApprove;
  final void Function(AdminVerificationApplication application) onReject;
  final void Function(AdminVerificationApplication application) onRefreshDidit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_outlined, size: 22, color: FigmaColors.gray700),
              const SizedBox(width: 8),
              Text(
                'Applications (${applications.length})',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final app in applications)
            AdminVerificationApplicationCard(
              application: app,
              onApprove: () => onApprove(app),
              onReject: () => onReject(app),
              onRefreshDidit: () => onRefreshDidit(app),
            ),
        ],
      ),
    );
  }
}

class AdminVerificationApplication {
  const AdminVerificationApplication.provider({
    required this.profile,
    required this.user,
    required this.businessLabel,
  }) : customer = null;

  const AdminVerificationApplication.customer({
    required this.customer,
    required this.businessLabel,
  })  : profile = null,
        user = null;

  final ServiceProviderProfile? profile;
  final AppUser? user;
  final AppUser? customer;
  final String businessLabel;

  bool get isCustomer => customer != null;

  String get id => isCustomer ? 'customer-${customer!.userId}' : 'provider-${profile!.providerId}';

  String get displayName {
    if (isCustomer) {
      final n = customer!.fullName.trim();
      return n.isNotEmpty ? n : 'Customer';
    }
    final fromUser = (user?.fullName ?? '').trim();
    if (fromUser.isNotEmpty) return fromUser;
    return 'Provider ${profile!.providerId}';
  }

  String get displayEmail {
    if (isCustomer) return customer!.email;
    final email = (user?.email ?? '').trim();
    return email.isNotEmpty ? email : 'No linked user account';
  }

  String? get photoUrl => isCustomer ? customer!.profilePhotoUrl : user?.profilePhotoUrl;

  bool get canAdminReview =>
      isCustomer
          ? (customer?.canAdminReviewVerification ?? false)
          : (profile?.canAdminReviewVerification ?? false);

  IdentityVerification get verification =>
      isCustomer
          ? customer!.identityVerification
          : IdentityVerification(
              isVerified: profile!.isVerified,
              verificationStatus: profile!.verificationStatus,
              diditStatus: profile!.diditStatus,
              verificationProvider: profile!.verificationProvider,
              governmentIdTypeCode: profile!.governmentIdTypeCode,
              governmentIdTypeLabel: profile!.governmentIdTypeLabel,
            );

  DateTime get submittedAt =>
      isCustomer ? customer!.updatedAt.toDate() : profile!.createdAt.toDate();
}

bool verificationStatusMatchesFilter(ServiceProviderProfile p, String filter) {
  return identityVerificationMatchesFilter(
    IdentityVerification(
      isVerified: p.isVerified,
      verificationStatus: p.verificationStatus,
      diditStatus: p.diditStatus,
    ),
    filter,
  );
}

bool customerVerificationMatchesFilter(AppUser u, String filter) {
  return identityVerificationMatchesFilter(u.identityVerification, filter);
}

bool identityVerificationMatchesFilter(IdentityVerification v, String filter) {
  if (filter == 'All status') return true;
  final bucket = providerVerificationBucket(v.verificationStatus, v.isVerified);
  return switch (filter) {
    'Pending' => bucket == 1,
    'Approved' => bucket == 0,
    'Rejected' => bucket == 2,
    _ => true,
  };
}

bool isTimestampThisMonth(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month;
}
