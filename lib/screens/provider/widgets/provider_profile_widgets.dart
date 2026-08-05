import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../figma_ui/figma_colors.dart';
import '../../../models/app_user.dart';
import '../../../models/provider.dart';
import '../../../models/service.dart';
import '../provider_profile_completion.dart';
import '../../../services/identity_verification_service.dart';
import '../../../models/philippine_government_id_type.dart';
import '../provider_government_id_picker_dialog.dart';
import '../../../theme/mobile_layout.dart';
import '../../../theme/provider_theme.dart';
import '../../../theme/role_theme.dart';
import '../../../widgets/member_profile/member_profile_kit.dart';

class ProviderProfilePanel extends StatelessWidget {
  const ProviderProfilePanel({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.showHeader = true,
  });

  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            )
          else if (trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(alignment: Alignment.centerRight, child: trailing!),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class ProviderProfileSummaryCard extends StatelessWidget {
  const ProviderProfileSummaryCard({
    super.key,
    required this.appUser,
    required this.profile,
    required this.memberSince,
    required this.rating,
    required this.reviewCount,
    required this.activeServices,
    required this.responseRatePct,
    this.onEditPhoto,
  });

  final AppUser appUser;
  final ServiceProviderProfile? profile;
  final String memberSince;
  final double rating;
  final int reviewCount;
  final int activeServices;
  final int responseRatePct;
  final VoidCallback? onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final verified = profile?.isVerifiedProvider ?? false;
    final statusLabel = verified ? 'Approved' : (profile?.verificationStatus ?? 'Pending');

    return ProviderProfilePanel(
      title: '',
      showHeader: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: rc.tint,
                backgroundImage:
                    appUser.profilePhotoUrl != null ? NetworkImage(appUser.profilePhotoUrl!) : null,
                child: appUser.profilePhotoUrl == null
                    ? Text(
                        _initials(appUser.fullName),
                        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: rc.primary),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: FigmaColors.navy,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onEditPhoto,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.photo_camera_outlined, size: 18, color: FigmaColors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            appUser.fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 4),
          Text('Service Provider', style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: verified ? FigmaColors.tintBlue : FigmaColors.orange50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verified ? Icons.check_circle : Icons.schedule,
                  size: 16,
                  color: verified ? FigmaColors.navy : FigmaColors.orange600,
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: verified ? FigmaColors.navy : FigmaColors.orange600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Member since $memberSince', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
          const SizedBox(height: 20),
          _StatsGrid(
            rating: rating,
            reviewCount: reviewCount,
            completedJobs: profile?.completedBookings ?? 0,
            activeServices: activeServices,
            responseRatePct: responseRatePct,
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.activeServices,
    required this.responseRatePct,
  });

  final double rating;
  final int reviewCount;
  final int completedJobs;
  final int activeServices;
  final int responseRatePct;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatBox(icon: Icons.star_rounded, iconColor: const Color(0xFFEAB308), label: rating > 0 ? rating.toStringAsFixed(1) : '—', sub: 'Rating ($reviewCount reviews)')),
            const SizedBox(width: 10),
            Expanded(child: _StatBox(icon: Icons.check_circle_outline, iconColor: FigmaColors.navy, label: '$completedJobs', sub: 'Completed Jobs')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatBox(icon: Icons.event_note_outlined, iconColor: FigmaColors.navy, label: '$activeServices', sub: 'Active Services')),
            const SizedBox(width: 10),
            Expanded(child: _StatBox(icon: Icons.show_chart, iconColor: FigmaColors.purple600, label: '$responseRatePct%', sub: 'Response Rate')),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.iconColor, required this.label, required this.sub});

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.inter(fontSize: 10, color: FigmaColors.gray600, height: 1.3)),
        ],
      ),
    );
  }
}

class ProviderVerificationTrustCard extends StatelessWidget {
  const ProviderVerificationTrustCard({
    super.key,
    required this.profile,
  });

  final ServiceProviderProfile? profile;

  @override
  Widget build(BuildContext context) {
    final verified = profile?.isVerifiedProvider ?? false;
    final awaitingAdmin = profile?.isAwaitingAdminApproval ?? false;
    final inReview = profile?.isVerificationInReview ?? false;
    final declined = profile?.isVerificationDeclined ?? false;

    final idLabel = profile?.governmentIdTypeLabel ?? '';
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
      idSubtitle = 'Choose National ID, Passport, Driver\'s license, or Residence permit on Didit';
    }

    return ProviderProfilePanel(
      title: 'Verification & Trust',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrustRow(
            done: verified,
            title: 'Government ID verified',
            subtitle: idSubtitle,
          ),
          if (!verified && !awaitingAdmin) ...[
            const SizedBox(height: 16),
            ProviderVerifyIdentityButton(
              subject: VerificationSubject.provider,
              governmentIdTypeCode: profile?.governmentIdTypeCode ?? '',
              governmentIdTypeLabel: profile?.governmentIdTypeLabel ?? '',
              inReview: inReview,
              declined: declined,
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ProviderVerificationDetailsDialog.open(context, profile: profile),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View verification details',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy),
                ),
                const Icon(Icons.chevron_right, size: 18, color: FigmaColors.navy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only verification summary (not profile settings).
class ProviderVerificationDetailsDialog extends StatelessWidget {
  const ProviderVerificationDetailsDialog({super.key, required this.profile});

  final ServiceProviderProfile? profile;

  static Future<void> open(BuildContext context, {required ServiceProviderProfile? profile}) {
    final body = ProviderVerificationDetailsDialog(profile: profile);
    if (MobileLayout.useMobileChrome(context)) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => providerThemed(
            Scaffold(
              backgroundColor: FigmaColors.gray50,
              appBar: AppBar(
                backgroundColor: FigmaColors.white,
                foregroundColor: FigmaColors.gray900,
                elevation: 0,
                title: Text('Verification details', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: body,
              ),
            ),
          ),
        ),
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => providerThemed(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: FigmaColors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Verification details',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final verified = p?.isVerifiedProvider ?? false;
    final awaitingAdmin = p?.isAwaitingAdminApproval ?? false;
    final inReview = p?.isVerificationInReview ?? false;
    final declined = p?.isVerificationDeclined ?? false;
    final idLabel = p?.governmentIdTypeLabel ?? '';
    final idCode = p?.governmentIdTypeCode ?? '';

    String statusLabel;
    Color statusBg;
    Color statusFg;
    if (verified) {
      statusLabel = 'Verified';
      statusBg = FigmaColors.tintBlue;
      statusFg = FigmaColors.navy;
    } else if (awaitingAdmin) {
      statusLabel = 'Awaiting admin';
      statusBg = FigmaColors.tintBlue;
      statusFg = FigmaColors.navy;
    } else if (inReview) {
      statusLabel = 'In review';
      statusBg = FigmaColors.orange50;
      statusFg = FigmaColors.orange600;
    } else if (declined) {
      statusLabel = 'Failed';
      statusBg = FigmaColors.orange50;
      statusFg = FigmaColors.orange600;
    } else {
      statusLabel = p?.verificationStatus ?? 'Pending';
      statusBg = FigmaColors.gray100;
      statusFg = FigmaColors.gray700;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FigmaColors.gray50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: FigmaColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: statusFg)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _detailSection(
          title: 'Government ID',
          rows: [
            _DetailRow(
              label: 'Status',
              value: verified
                  ? 'Verified'
                  : (awaitingAdmin
                      ? 'Didit approved — awaiting admin'
                      : (inReview ? 'In review on Didit' : (declined ? 'Failed' : 'Not verified'))),
            ),
            if (p?.diditStatus.isNotEmpty == true) _DetailRow(label: 'Didit status', value: p!.diditStatus),
            if (idLabel.isNotEmpty) _DetailRow(label: 'ID type', value: idLabel),
            if (idCode.isNotEmpty && idLabel.isEmpty) _DetailRow(label: 'ID type', value: idCode),
            if (p?.verificationProvider.isNotEmpty == true)
              _DetailRow(label: 'Provider', value: p!.verificationProvider),
          ],
        ),
        if (p != null && !verified && !awaitingAdmin) ...[
          const SizedBox(height: 16),
          const SizedBox(height: 20),
          ProviderVerifyIdentityButton(
            subject: VerificationSubject.provider,
            governmentIdTypeCode: p.governmentIdTypeCode,
            governmentIdTypeLabel: p.governmentIdTypeLabel,
            inReview: inReview,
            declined: declined,
          ),
        ],
      ],
    );
  }

  Widget _detailSection({required String title, required List<Widget> rows}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
        ),
        Expanded(
          child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900)),
        ),
      ],
    );
  }
}

/// Opens PH government ID picker, then launches the Didit hosted verification flow.
class ProviderVerifyIdentityButton extends StatefulWidget {
  const ProviderVerifyIdentityButton({
    super.key,
    this.subject = VerificationSubject.provider,
    this.governmentIdTypeCode = '',
    this.governmentIdTypeLabel = '',
    this.inReview = false,
    this.declined = false,
    this.identityService,
    this.callbackUrl,
  });

  final VerificationSubject subject;
  final String governmentIdTypeCode;
  final String governmentIdTypeLabel;
  final bool inReview;
  final bool declined;
  final IdentityVerificationService? identityService;
  final String? callbackUrl;

  @override
  State<ProviderVerifyIdentityButton> createState() => _ProviderVerifyIdentityButtonState();
}

class _ProviderVerifyIdentityButtonState extends State<ProviderVerifyIdentityButton> {
  late final IdentityVerificationService _service =
      widget.identityService ?? IdentityVerificationService();
  bool _busy = false;

  Future<void> _start() async {
    if (_busy) return;

    // One in-app step: pick PH government ID, then open Didit (no extra app dialogs).
    PhilippineGovernmentIdType? idType;
    if (widget.inReview && widget.governmentIdTypeCode.isNotEmpty) {
      final code = widget.governmentIdTypeCode;
      final label = widget.governmentIdTypeLabel;
      idType = PhilippineGovernmentIdType(
        label: label.isNotEmpty ? label : code,
        diditCode: code,
      );
    } else {
      idType = await ProviderGovernmentIdPickerDialog.open(
        context,
        initialCode: widget.governmentIdTypeCode.isNotEmpty ? widget.governmentIdTypeCode : null,
      );
      if (idType == null || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final callbackUrl = widget.callbackUrl ?? (kIsWeb ? Uri.base.toString() : null);
      final launched = await _service.startGovernmentIdVerification(
        documentType: idType.diditCode,
        documentLabel: idType.label,
        callbackUrl: callbackUrl,
        subject: widget.subject,
      );
      if (!mounted) return;
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complete ${idType.label} on Didit (the page that just opened). '
              'After Didit approves, a NeighborHelp admin will review and grant your verified badge.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Didit verification page. Allow pop-ups and try again.')),
        );
      }
    } on VerificationStartException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('Verification start failed: $e\n$st');
      if (!mounted) return;
      final msg = e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')
          ? 'Network blocked verification. Allow cloudfunctions.net and retry.'
          : 'Could not start verification. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy
        ? 'Starting…'
        : widget.declined
            ? 'Retry verification'
            : widget.inReview
                ? 'Continue on Didit'
                : 'Verify government ID';

    final leading = _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
          )
        : Icon(
            widget.inReview ? Icons.open_in_new_rounded : Icons.badge_outlined,
            size: 20,
            color: FigmaColors.white,
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _start,
        style: FilledButton.styleFrom(
          backgroundColor: FigmaColors.navy,
          foregroundColor: FigmaColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.done, required this.title, required this.subtitle});

  final bool done;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? FigmaColors.navy : FigmaColors.gray400, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray600)),
            ],
          ),
        ),
      ],
    );
  }
}

class ProviderBusinessProfileCard extends StatelessWidget {
  const ProviderBusinessProfileCard({
    super.key,
    required this.appUser,
    required this.profile,
    required this.memberSince,
    required this.onEdit,
  });

  final AppUser appUser;
  final ServiceProviderProfile profile;
  final String memberSince;
  final VoidCallback onEdit;

  static const _tags = [
    ('Reliable', FigmaColors.tintBlue, FigmaColors.navy),
    ('On-time', FigmaColors.tintBlue, FigmaColors.navy),
    ('Friendly', FigmaColors.purple50, FigmaColors.purple600),
    ('Detail-oriented', FigmaColors.orange50, FigmaColors.orange600),
  ];

  @override
  Widget build(BuildContext context) {
    final verified = profile.isVerifiedProvider;

    return ProviderProfilePanel(
      title: 'Business Profile',
      trailing: MemberProfileSectionEditButton(onPressed: onEdit),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 560;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: verified ? FigmaColors.tintBlue : FigmaColors.orange50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      verified ? 'Approved' : profile.verificationStatus,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: verified ? FigmaColors.navy : FigmaColors.orange600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Service area', profile.serviceArea.isNotEmpty ? profile.serviceArea : '—'),
              _detailRow('Service radius', '${profile.serviceRadiusKm.toStringAsFixed(0)} km'),
              _detailRow('Rating', profile.averageRating > 0 ? profile.averageRating.toStringAsFixed(1) : '—'),
              _detailRow('Completed jobs', '${profile.completedBookings}'),
              _detailRow('Verification', verified ? 'Verified' : profile.verificationStatus),
              _detailRow('Member since', memberSince),
            ],
          );

          final about = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About me', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800)),
              const SizedBox(height: 8),
              Text(
                profile.bio.isNotEmpty
                    ? profile.bio
                    : 'Tell customers about your experience and what makes your service stand out.',
                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.45),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: t.$2, borderRadius: BorderRadius.circular(20)),
                      child: Text(t.$1, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: t.$3)),
                    ),
                ],
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 20), about],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 24),
              Expanded(child: about),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class ProviderAvailabilityCard extends StatelessWidget {
  const ProviderAvailabilityCard({
    super.key,
    required this.workingDays,
    required this.workingHours,
    required this.serviceMode,
    required this.onEdit,
  });

  final String workingDays;
  final String workingHours;
  final String serviceMode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ProviderProfilePanel(
      title: 'Availability & Preferences',
      trailing: MemberProfileSectionEditButton(onPressed: onEdit),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 520;
          final list = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _availRow('Working days', workingDays),
              _availRow('Working hours', workingHours),
              _availRow('Service mode', serviceMode),
            ],
          );
          final highlight = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FigmaColors.tintBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.navy.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usually responds within 1 hour',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FigmaColors.navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Excellent response time',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: FigmaColors.white),
                  ),
                ),
              ],
            ),
          );
          if (!wide) {
            return Column(children: [list, const SizedBox(height: 16), highlight]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: list),
              const SizedBox(width: 20),
              Expanded(child: highlight),
            ],
          );
        },
      ),
    );
  }

  Widget _availRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500))),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class ProviderReviewsPreviewCard extends StatelessWidget {
  const ProviderReviewsPreviewCard({
    super.key,
    required this.rating,
    required this.reviewCount,
    required this.onViewAll,
  });

  final double rating;
  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final countLabel = reviewCount == 1 ? '1 review' : '$reviewCount reviews';
    return ProviderProfilePanel(
      title: 'Reviews & Ratings',
      trailing: TextButton(
        onPressed: onViewAll,
        child: Text('View all reviews', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FigmaColors.navy)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : '—',
                style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      // Round to nearest star so 4.6→5 and 3.6→4 (not all five).
                      final filled = rating.round() >= i + 1;
                      return Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 22,
                        color: const Color(0xFFEAB308),
                      );
                    }),
                  ),
                  Text(
                    reviewCount > 0 ? countLabel : 'No reviews yet',
                    style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProviderProfileCompletionCard extends StatelessWidget {
  const ProviderProfileCompletionCard({
    super.key,
    required this.percent,
    required this.onTap,
  });

  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProviderProfilePanel(
      title: 'Profile Progress',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(
                          value: percent / 100,
                          strokeWidth: 5,
                          backgroundColor: FigmaColors.gray200,
                          color: FigmaColors.navy,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text('$percent%', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileCompletionEncouragement(percent),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to see what’s left',
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: FigmaColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int completionPercent({
  required AppUser appUser,
  required ServiceProviderProfile? profile,
  required List<ServiceListing> services,
  required int reviewCount,
}) {
  final items = buildProviderProfileRequirements(
    appUser: appUser,
    profile: profile,
    services: services,
    reviewCount: reviewCount,
  );
  return weightedProfileCompletionPercent(items);
}

int computeResponseRate({
  required int acceptedBookings,
  required int totalBookings,
}) {
  if (totalBookings == 0) return acceptedBookings > 0 ? 100 : 0;
  final rate = ((acceptedBookings / totalBookings) * 100).round();
  return rate.clamp(0, 100);
}
