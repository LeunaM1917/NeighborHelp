import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/service.dart';
import '../../theme/mobile_layout.dart';
import '../../theme/provider_theme.dart';
import '../../theme/role_theme.dart';
import 'provider_certification_dialog.dart';
import 'provider_education_dialog.dart';
import 'provider_employment_dialog.dart';
import 'provider_overview_settings_screen.dart';
import 'provider_portfolio_flow.dart';
import 'provider_profile_section_dialogs.dart';
import 'widgets/provider_dashboard_widgets.dart';

/// One weighted profile requirement (Upwork-style completion checklist).
class ProviderProfileRequirement {
  const ProviderProfileRequirement({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.weightPercent,
    required this.done,
    this.partial = false,
    this.progressDetail,
  });

  final ProviderProfileRequirementId id;
  final String title;
  final String subtitle;
  final int weightPercent;
  final bool done;
  final bool partial;
  final String? progressDetail;
}

enum ProviderProfileRequirementId {
  profilePhoto,
  overview,
  identity,
  education,
  employmentHistory,
  portfolio,
  certifications,
  otherExperiences,
  linkedAccounts,
  serviceArea,
  services,
  reviews,
}

typedef ProviderProfileRequirementHandler = void Function(ProviderProfileRequirementId id);

/// Opens the screen or tab where the provider can complete [id].
void navigateToProviderProfileRequirement(
  BuildContext context, {
  required ProviderProfileRequirementId id,
  required AppUser appUser,
  required ServiceProviderProfile? profile,
  ValueChanged<int>? onNavigateToTab,
}) {
  switch (id) {
    case ProviderProfileRequirementId.profilePhoto:
      if (profile != null) {
        ProviderOverviewSettingsScreen.open(context, appUser: appUser, profile: profile);
      } else {
        onNavigateToTab?.call(4);
      }
      return;
    case ProviderProfileRequirementId.identity:
      onNavigateToTab?.call(4);
      return;
    case ProviderProfileRequirementId.overview:
    case ProviderProfileRequirementId.serviceArea:
      if (profile != null) {
        ProviderOverviewSettingsScreen.open(context, appUser: appUser, profile: profile);
      } else {
        onNavigateToTab?.call(4);
      }
      return;
    case ProviderProfileRequirementId.services:
      onNavigateToTab?.call(1);
      return;
    case ProviderProfileRequirementId.reviews:
      onNavigateToTab?.call(4);
      return;
    case ProviderProfileRequirementId.education:
      if (profile == null) {
        onNavigateToTab?.call(4);
        return;
      }
      final edu = profile.effectiveEducationHistory;
      ProviderEducationDialog.open(
        context,
        providerId: profile.providerId,
        initial: edu.isNotEmpty ? edu.first : null,
        editIndex: edu.isNotEmpty ? 0 : null,
      );
      return;
    case ProviderProfileRequirementId.employmentHistory:
      if (profile == null) {
        onNavigateToTab?.call(4);
        return;
      }
      final jobs = profile.employmentHistory;
      ProviderEmploymentDialog.open(
        context,
        providerId: profile.providerId,
        initial: jobs.isNotEmpty ? jobs.first : null,
        editIndex: jobs.isNotEmpty ? 0 : null,
      );
      return;
    case ProviderProfileRequirementId.portfolio:
      if (profile == null) {
        onNavigateToTab?.call(4);
        return;
      }
      final stored = profile.portfolioProjects;
      ProviderPortfolioFlow.open(
        context,
        providerId: profile.providerId,
        initial: stored.isNotEmpty ? stored.first : profile.effectivePortfolioProjects.firstOrNull,
        editIndex: stored.isNotEmpty ? 0 : null,
      );
      return;
    case ProviderProfileRequirementId.certifications:
      if (profile == null) {
        onNavigateToTab?.call(4);
        return;
      }
      ProviderCertificationDialog.open(context, providerId: profile.providerId);
      return;
    case ProviderProfileRequirementId.otherExperiences:
      if (profile == null) {
        onNavigateToTab?.call(4);
        return;
      }
      ProviderOtherExperiencesDialog.open(
        context,
        providerId: profile.providerId,
        initialLines: profile.otherExperiences,
      );
      return;
    case ProviderProfileRequirementId.linkedAccounts:
      if (profile == null) {
        onNavigateToTab?.call(4);
        return;
      }
      ProviderLinkedAccountsDialog.open(
        context,
        providerId: profile.providerId,
        initial: profile.linkedAccounts,
      );
      return;
  }
}

List<ProviderProfileRequirement> buildProviderProfileRequirements({
  required AppUser appUser,
  required ServiceProviderProfile? profile,
  required List<ServiceListing> services,
  required int reviewCount,
}) {
  final p = profile;
  final hasPhoto = appUser.profilePhotoUrl?.trim().isNotEmpty == true;
  final bio = p?.bio.trim() ?? '';
  final hasBio = bio.length >= 20;
  final verified = p?.isVerifiedProvider ?? false;
  final hasEducation = p?.hasEducation ?? false;
  final hasEmployment = p?.hasEmployment ?? false;
  final hasPortfolio = p?.hasPortfolio ?? false;
  // Optional for soft services; required only when publishing cert-gated jobs.
  final hasCerts = p?.hasApprovedCertifications ?? false;
  final hasOther = p?.otherExperiences.isNotEmpty ?? false;
  final hasLinked = p?.linkedAccounts.isNotEmpty ?? false;
  final hasArea = p?.serviceArea.trim().isNotEmpty ?? false;
  final hasService = services.isNotEmpty;
  const reviewGoal = 5;
  final reviewDone = reviewCount.clamp(0, reviewGoal);

  return [
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.profilePhoto,
      title: 'Profile photo',
      subtitle: 'A friendly photo helps customers trust you',
      weightPercent: 8,
      done: hasPhoto,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.overview,
      title: 'Overview',
      subtitle: 'Short bio about your experience and services',
      weightPercent: 12,
      done: hasBio,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.identity,
      title: 'Identity verification',
      subtitle: 'Government ID check for a verified badge',
      weightPercent: 12,
      done: verified,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.education,
      title: 'Education',
      subtitle: 'Schools, degrees, or training programs',
      weightPercent: 8,
      done: hasEducation,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.employmentHistory,
      title: 'Employment history',
      subtitle: 'Past jobs and roles relevant to your services',
      weightPercent: 12,
      done: hasEmployment,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.portfolio,
      title: 'Portfolio',
      subtitle: 'Photos or links showing your past work',
      weightPercent: 10,
      done: hasPortfolio,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.certifications,
      title: 'Certifications (for technical services)',
      subtitle: 'Needed only for Electrical / Plumbing / Aircon-type jobs — agency authenticates',
      weightPercent: 6,
      done: hasCerts,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.otherExperiences,
      title: 'Other experiences',
      subtitle: 'Volunteering, awards, or community work',
      weightPercent: 6,
      done: hasOther,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.linkedAccounts,
      title: 'Linked accounts',
      subtitle: 'Social profiles customers can review',
      weightPercent: 6,
      done: hasLinked,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.serviceArea,
      title: 'Service area',
      subtitle: 'Where you are available to work',
      weightPercent: 6,
      done: hasArea,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.services,
      title: 'List your services',
      subtitle: 'At least one active service customers can book',
      weightPercent: 8,
      done: hasService,
    ),
    ProviderProfileRequirement(
      id: ProviderProfileRequirementId.reviews,
      title: 'Get 5 reviews',
      subtitle: 'Build trust with completed job feedback',
      weightPercent: 10,
      done: reviewCount >= reviewGoal,
      partial: reviewCount > 0 && reviewCount < reviewGoal,
      progressDetail: '$reviewDone / $reviewGoal',
    ),
  ];
}

int weightedProfileCompletionPercent(List<ProviderProfileRequirement> items) {
  if (items.isEmpty) return 0;
  var earned = 0;
  for (final item in items) {
    if (item.done) earned += item.weightPercent;
  }
  return earned.clamp(0, 100);
}

String profileCompletionEncouragement(int percent) {
  if (percent >= 100) return 'Well done!';
  if (percent >= 75) return 'Almost there!';
  if (percent >= 40) return 'Keep going!';
  return 'Complete your profile to get more bookings.';
}

/// Compact dashboard card: circular progress + opens full checklist.
class ProviderProfileProgressPanel extends StatelessWidget {
  const ProviderProfileProgressPanel({
    super.key,
    required this.appUser,
    required this.profile,
    required this.services,
    required this.reviewCount,
    required this.onRequirementTap,
  });

  final AppUser appUser;
  final ServiceProviderProfile? profile;
  final List<ServiceListing> services;
  final int reviewCount;
  final ProviderProfileRequirementHandler onRequirementTap;

  @override
  Widget build(BuildContext context) {
    final items = buildProviderProfileRequirements(
      appUser: appUser,
      profile: profile,
      services: services,
      reviewCount: reviewCount,
    );
    final pct = weightedProfileCompletionPercent(items);
    final incomplete = items.where((i) => !i.done).length;

    return ProviderDashboardPanel(
      title: 'Profile Progress',
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showProviderProfileCompletionDialog(
            context,
            appUser: appUser,
            profile: profile,
            services: services,
            reviewCount: reviewCount,
            onRequirementTap: onRequirementTap,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _ProfileCompletionRing(
                  percent: pct,
                  photoUrl: appUser.profilePhotoUrl,
                  name: appUser.fullName,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$pct% complete',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        incomplete == 0
                            ? profileCompletionEncouragement(pct)
                            : '$incomplete item${incomplete == 1 ? '' : 's'} left — tap to finish',
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.35),
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

class _ProfileCompletionRing extends StatelessWidget {
  const _ProfileCompletionRing({
    required this.percent,
    required this.photoUrl,
    required this.name,
  });

  final int percent;
  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final initials = _initials(name);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 5,
              backgroundColor: FigmaColors.gray200,
              color: FigmaColors.navy,
              strokeCap: StrokeCap.round,
            ),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: FigmaColors.gray200,
            backgroundImage: photoUrl?.trim().isNotEmpty == true ? NetworkImage(photoUrl!.trim()) : null,
            child: photoUrl?.trim().isNotEmpty == true
                ? null
                : Text(initials, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray700)),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

void _completionItemTap(
  BuildContext dialogContext,
  ProviderProfileRequirementId id,
  ProviderProfileRequirementHandler handler,
) {
  Navigator.pop(dialogContext);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    handler(id);
  });
}

Future<void> showProviderProfileCompletionDialog(
  BuildContext context, {
  required AppUser appUser,
  required ServiceProviderProfile? profile,
  required List<ServiceListing> services,
  required int reviewCount,
  required ProviderProfileRequirementHandler onRequirementTap,
}) {
  final items = buildProviderProfileRequirements(
    appUser: appUser,
    profile: profile,
    services: services,
    reviewCount: reviewCount,
  );
  final pct = weightedProfileCompletionPercent(items);

  if (MobileLayout.useBottomSheets(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => providerThemed(
        DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (_, scrollController) => _ProfileCompletionSheet(
            appUser: appUser,
            percent: pct,
            items: items,
            scrollController: scrollController,
            onRequirementTap: (id) => _completionItemTap(ctx, id, onRequirementTap),
            onClose: () => Navigator.pop(ctx),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 560),
          child: _ProfileCompletionDialog(
            appUser: appUser,
            percent: pct,
            items: items,
            onRequirementTap: (id) => _completionItemTap(ctx, id, onRequirementTap),
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    ),
  );
}

class _ProfileCompletionDialog extends StatelessWidget {
  const _ProfileCompletionDialog({
    required this.appUser,
    required this.percent,
    required this.items,
    required this.onRequirementTap,
    required this.onClose,
  });

  final AppUser appUser;
  final int percent;
  final List<ProviderProfileRequirement> items;
  final ValueChanged<ProviderProfileRequirementId> onRequirementTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: FigmaColors.white,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileCompletionSidebar(appUser: appUser, percent: percent),
                Expanded(child: _ProfileCompletionChecklist(items: items, onTap: onRequirementTap)),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: FigmaColors.gray600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCompletionSheet extends StatelessWidget {
  const _ProfileCompletionSheet({
    required this.appUser,
    required this.percent,
    required this.items,
    required this.scrollController,
    required this.onRequirementTap,
    required this.onClose,
  });

  final AppUser appUser;
  final int percent;
  final List<ProviderProfileRequirement> items;
  final ScrollController scrollController;
  final ValueChanged<ProviderProfileRequirementId> onRequirementTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: FigmaColors.gray300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(
              children: [
                _ProfileCompletionRing(
                  percent: percent,
                  photoUrl: appUser.profilePhotoUrl,
                  name: appUser.fullName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$percent% complete', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(
                        profileCompletionEncouragement(percent),
                        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _ProfileCompletionChecklist(
              items: items,
              onTap: onRequirementTap,
              scrollController: scrollController,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCompletionSidebar extends StatelessWidget {
  const _ProfileCompletionSidebar({required this.appUser, required this.percent});

  final AppUser appUser;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: FigmaColors.gray50,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: percent / 100,
                    strokeWidth: 8,
                    backgroundColor: FigmaColors.gray200,
                    color: FigmaColors.navy,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                CircleAvatar(
                  radius: 46,
                  backgroundColor: FigmaColors.gray200,
                  backgroundImage: appUser.profilePhotoUrl?.trim().isNotEmpty == true
                      ? NetworkImage(appUser.profilePhotoUrl!.trim())
                      : null,
                  child: appUser.profilePhotoUrl?.trim().isNotEmpty == true
                      ? null
                      : Text(
                          _initials(appUser.fullName),
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$percent% complete',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: FigmaColors.gray900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            profileCompletionEncouragement(percent),
            style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileCompletionChecklist extends StatefulWidget {
  const _ProfileCompletionChecklist({
    required this.items,
    required this.onTap,
    this.scrollController,
  });

  final List<ProviderProfileRequirement> items;
  final ValueChanged<ProviderProfileRequirementId> onTap;
  final ScrollController? scrollController;

  @override
  State<_ProfileCompletionChecklist> createState() => _ProfileCompletionChecklistState();
}

class _ProfileCompletionChecklistState extends State<_ProfileCompletionChecklist> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final pending = widget.items.where((i) => !i.done).toList();
    final completed = widget.items.where((i) => i.done).toList();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Text(
          'Complete your profile',
          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: rc.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'A complete profile helps customers trust you and improves your visibility in search.',
          style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600, height: 1.45),
        ),
        const SizedBox(height: 20),
        for (final item in pending) ...[
          _RequirementTile(item: item, onTap: () => widget.onTap(item.id)),
          const Divider(height: 1, color: FigmaColors.gray100),
        ],
        if (completed.isNotEmpty) ...[
          InkWell(
            onTap: () => setState(() => _showCompleted = !_showCompleted),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(
                    _showCompleted ? 'Hide completed (${completed.length})' : 'Show completed (${completed.length})',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray800),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showCompleted ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: FigmaColors.gray600,
                  ),
                ],
              ),
            ),
          ),
          if (_showCompleted) ...[
            Text(
              'Nicely done! These items are checked off the list.',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
            ),
            const SizedBox(height: 8),
            for (final item in completed) ...[
              _RequirementTile(item: item, onTap: () => widget.onTap(item.id), completedStyle: true),
              const Divider(height: 1, color: FigmaColors.gray100),
            ],
          ],
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              backgroundColor: FigmaColors.navy,
              foregroundColor: FigmaColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({
    required this.item,
    required this.onTap,
    this.completedStyle = false,
  });

  final ProviderProfileRequirement item;
  final VoidCallback onTap;
  final bool completedStyle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: item.done
                    ? const Icon(Icons.check_circle, color: FigmaColors.navy, size: 22)
                    : Icon(
                        item.partial ? Icons.radio_button_checked : Icons.circle_outlined,
                        color: item.partial ? FigmaColors.gray500 : FigmaColors.gray400,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: completedStyle ? FigmaColors.gray700 : FigmaColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (!item.done && item.weightPercent > 0)
                Text(
                  '+${item.weightPercent}%',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.navy),
                )
              else if (item.progressDetail != null)
                Text(
                  item.progressDetail!,
                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
