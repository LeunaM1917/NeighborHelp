import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/provider.dart';
import '../../models/provider_certification.dart';
import '../../models/provider_portfolio_project.dart';
import '../../models/review.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../theme/role_theme.dart';
import '../../utils/review_sentiment.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/provider_profile_builder.dart';
import '../../widgets/member_profile/member_profile_kit.dart';
import '../provider/provider_availability_screen.dart';
import '../../models/provider_weekly_availability.dart';
import '../provider/provider_profile_completion.dart';
import '../provider/provider_education_dialog.dart';
import '../provider/provider_employment_dialog.dart';
import '../provider/provider_certification_dialog.dart';
import '../provider/provider_portfolio_flow.dart';
import '../provider/provider_overview_settings_screen.dart';
import '../provider/provider_reviews_screen.dart';
import '../provider/widgets/provider_profile_widgets.dart';

/// Self profile layout for the provider tab.
class SelfProviderProfileBody extends StatefulWidget {
  const SelfProviderProfileBody({
    super.key,
    required this.appUser,
    this.onNavigateToTab,
  });

  final AppUser appUser;
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<SelfProviderProfileBody> createState() => _SelfProviderProfileBodyState();
}

class _SelfProviderProfileBodyState extends State<SelfProviderProfileBody> {
  final _firestore = FirestoreService();
  List<Review> _reviews = [];
  Map<String, dynamic>? _availability;
  bool _extrasLoaded = false;
  late AppUser _accountUser;

  @override
  void initState() {
    super.initState();
    _accountUser = widget.appUser;
    unawaited(_firestore.ensureServiceProviderProfile(widget.appUser.userId));
    unawaited(_loadExtras());
  }

  @override
  void didUpdateWidget(covariant SelfProviderProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appUser.userId != widget.appUser.userId) {
      _accountUser = widget.appUser;
    }
  }

  String _providerDocId(ServiceProviderProfile profile) => profile.providerId;

  Future<void> _refreshAccountUser() async {
    final user = await _firestore.getUser(widget.appUser.userId);
    if (user != null && mounted) setState(() => _accountUser = user);
  }

  Future<void> _afterSectionSaved({bool refreshAccount = false}) async {
    if (refreshAccount) await _refreshAccountUser();
    await _loadExtras();
  }

  Future<void> _loadExtras() async {
    final profile = await _firestore.getProviderProfile(widget.appUser.userId);
    final providerId = profile?.providerId ?? widget.appUser.userId;
    final reviews = await _firestore.reviewsForProvider(providerId);
    final availability = await _firestore.providerAvailability(widget.appUser.userId);
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _availability = availability;
      _extrasLoaded = true;
    });
  }

  Future<void> _openCertificationEditor(
    ServiceProviderProfile profile, {
    ProviderCertificationEntry? initial,
    int? editIndex,
  }) async {
    final saved = await ProviderCertificationDialog.open(
      context,
      providerId: _providerDocId(profile),
      initial: initial,
      editIndex: editIndex,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certification saved')),
      );
      await _afterSectionSaved();
    }
  }

  Future<void> _deleteCertification(ServiceProviderProfile profile, int index) async {
    final entries = List<ProviderCertificationEntry>.from(profile.effectiveCertificationHistory);
    if (index < 0 || index >= entries.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete certification?'),
        content: Text('Remove "${entries[index].name}" from your profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removedId = entries[index].id;
    entries.removeAt(index);
    final approvedIds = List<String>.from(profile.approvedCertificationIds)
      ..removeWhere((id) => id == removedId);
    try {
      await FirestoreService().updateServiceProvider(
        providerId: _providerDocId(profile),
        data: {
          'certificationHistory': ProviderCertificationEntry.listToFirestore(entries),
          'certifications': entries.map((e) => e.displayLine).toList(),
          'approvedCertificationIds': approvedIds,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certification removed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    }
  }

  Future<void> _openPortfolioEditor(ServiceProviderProfile profile, {bool adding = false}) async {
    ProviderPortfolioProject? initial;
    int? editIndex;
    if (!adding) {
      final stored = profile.portfolioProjects;
      if (stored.isNotEmpty) {
        initial = stored.first;
        editIndex = 0;
      } else {
        final legacy = profile.effectivePortfolioProjects;
        if (legacy.isNotEmpty) initial = legacy.first;
      }
    }
    final saved = await ProviderPortfolioFlow.open(
      context,
      providerId: _providerDocId(profile),
      initial: initial,
      editIndex: editIndex,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Portfolio saved')),
      );
      await _afterSectionSaved();
    }
  }

  Future<void> _openEmploymentEditor(ServiceProviderProfile profile, {bool adding = false}) async {
    final entries = profile.employmentHistory;
    final saved = await ProviderEmploymentDialog.open(
      context,
      providerId: _providerDocId(profile),
      initial: adding ? null : (entries.isNotEmpty ? entries.first : null),
      editIndex: adding ? null : (entries.isNotEmpty ? 0 : null),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employment saved')),
      );
      await _afterSectionSaved();
    }
  }

  Future<void> _openEducationEditor(ServiceProviderProfile profile, {bool adding = false}) async {
    final entries = profile.effectiveEducationHistory;
    final saved = await ProviderEducationDialog.open(
      context,
      providerId: _providerDocId(profile),
      initial: adding ? null : (entries.isNotEmpty ? entries.first : null),
      editIndex: adding ? null : (entries.isNotEmpty ? 0 : null),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Education saved')),
      );
      await _afterSectionSaved();
    }
  }

  Future<void> _openOverviewSettings(ServiceProviderProfile profile) async {
    final saved = await ProviderOverviewSettingsScreen.open(
      context,
      appUser: widget.appUser,
      profile: profile,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile settings saved')),
      );
      await _afterSectionSaved(refreshAccount: true);
    }
  }

  Future<void> _openProfileSettings(ServiceProviderProfile? profile) async {
    await _firestore.ensureServiceProviderProfile(widget.appUser.userId);
    final resolved = profile ?? await _firestore.getProviderProfile(widget.appUser.userId);
    if (resolved == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load provider profile. Try again.')),
        );
      }
      return;
    }
    await _openOverviewSettings(resolved);
  }

  @override
  Widget build(BuildContext context) {
    return ProviderProfileBuilder(
      userId: widget.appUser.userId,
      loading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingIndicator(message: 'Loading profile…'),
      ),
      builder: (context, profile) {
        return StreamBuilder<List<ServiceListing>>(
          initialData: const [],
          stream: _firestore.servicesForProviderUser(widget.appUser.userId),
          builder: (context, serviceSnap) {
            return StreamBuilder<List<Booking>>(
              initialData: const [],
              stream: _firestore.bookingsForProviderUser(widget.appUser.userId),
              builder: (context, bookingSnap) {
                final services = serviceSnap.data ?? [];
                final bookings = bookingSnap.data ?? [];
                final activeServices = services.where((s) => s.isActive).length;
                final reviewCount = _reviews.length;
                final effectiveRating = _effectiveRating(profile, _reviews);
                final responseRate = computeResponseRate(
                  acceptedBookings: profile?.acceptedBookings ?? 0,
                  totalBookings: bookings.isNotEmpty ? bookings.length : 1,
                );
                final completionPct = completionPercent(
                  appUser: widget.appUser,
                  profile: profile,
                  services: services,
                  reviewCount: reviewCount,
                );
                final memberSince = memberProfileMemberSince(widget.appUser.createdAt.toDate());
                final verified = profile?.isVerifiedProvider ?? false;
                final rc = context.roleColors;

                final sidebar = MemberProfileSidebar(
                  name: _accountUser.fullName,
                  headline: profile?.serviceArea.isNotEmpty == true ? profile!.serviceArea : 'Set your service area',
                  roleLabel: 'Service provider',
                  photoUrl: _accountUser.profilePhotoUrl,
                  onEditPhoto: () => _openProfileSettings(profile),
                  badges: [
                    MemberProfileBadge(
                      label: verified ? 'Verified' : (profile?.verificationStatus ?? 'Pending'),
                      icon: verified ? Icons.verified : Icons.schedule,
                      background: verified ? rc.tint : FigmaColors.orange50,
                      foreground: verified ? rc.primary : FigmaColors.orange600,
                    ),
                  ],
                  metaLines: [
                    MemberProfileMetaLine(icon: Icons.calendar_today_outlined, text: 'Member since $memberSince'),
                    if (profile != null && profile.serviceRadiusKm > 0)
                      MemberProfileMetaLine(
                        icon: Icons.my_location_outlined,
                        text: '${profile.serviceRadiusKm.toStringAsFixed(0)} km radius',
                      ),
                  ],
                  stats: [
                    MemberProfileStat(
                      value: effectiveRating > 0 ? effectiveRating.toStringAsFixed(1) : '—',
                      label: 'Rating',
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFEAB308),
                    ),
                    MemberProfileStat(
                      value: '${profile?.completedBookings ?? 0}',
                      label: 'Milestones',
                      icon: Icons.check_circle_outline,
                      iconColor: rc.primary,
                    ),
                    MemberProfileStat(
                      value: '$activeServices',
                      label: 'Services',
                      icon: Icons.storefront_outlined,
                    ),
                    MemberProfileStat(
                      value: '$responseRate%',
                      label: 'Response',
                      icon: Icons.show_chart,
                    ),
                  ],
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ProviderVerificationTrustCard(profile: profile),
                  ),
                );

                final main = <Widget>[
                  if (profile != null) ...[
                    MemberProfileOverviewSection(
                      body: profile.bio.isNotEmpty
                          ? profile.bio
                          : 'Tell customers about your experience and what makes your service stand out.',
                      onEdit: () => _openOverviewSettings(profile),
                      tags: profile.profileTraits,
                      accountUser: _accountUser,
                    ),
                    MemberProfileTimelineSection(
                      title: 'Employment history',
                      entries: profile.employmentDisplayLines,
                      onAdd: () => _openEmploymentEditor(profile, adding: true),
                      onEdit: () => _openEmploymentEditor(profile),
                    ),
                    MemberProfileTimelineSection(
                      title: 'Education',
                      icon: Icons.school_outlined,
                      entries: profile.educationDisplayLines,
                      onAdd: () => _openEducationEditor(profile, adding: true),
                      onEdit: () => _openEducationEditor(profile),
                    ),
                    MemberProfilePortfolioSection(
                      urls: profile.portfolioThumbnailUrls,
                      projects: profile.effectivePortfolioProjects,
                      onAdd: () => _openPortfolioEditor(profile, adding: true),
                      onEdit: () => _openPortfolioEditor(profile),
                    ),
                    MemberProfileCertificationsSection(
                      certifications: profile.effectiveCertificationHistory,
                      onAdd: () => _openCertificationEditor(profile),
                      onEdit: (i) {
                        final stored = profile.certificationHistory;
                        _openCertificationEditor(
                          profile,
                          initial: profile.effectiveCertificationHistory[i],
                          editIndex: i < stored.length ? i : null,
                        );
                      },
                      onDelete: (i) => _deleteCertification(profile, i),
                    ),
                  ] else
                    const FigmaEmptyState(
                      icon: Icons.badge_outlined,
                      title: 'Business profile not set up',
                      message: 'Complete your provider profile so customers can book you.',
                    ),
                ];

                final rightRail = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_extrasLoaded)
                      ProviderReviewsPreviewCard(
                        rating: effectiveRating,
                        reviewCount: reviewCount,
                        onViewAll: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ProviderReviewsScreen(appUser: widget.appUser),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 20),
                    ProviderProfileCompletionCard(
                      percent: completionPct,
                      onTap: () => showProviderProfileCompletionDialog(
                        context,
                        appUser: widget.appUser,
                        profile: profile,
                        services: services,
                        reviewCount: reviewCount,
                        onRequirementTap: (id) => navigateToProviderProfileRequirement(
                          context,
                          id: id,
                          appUser: widget.appUser,
                          profile: profile,
                          onNavigateToTab: widget.onNavigateToTab,
                        ),
                      ),
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 20),
                      ProviderAvailabilityCard(
                        workingDays: formatWorkingDays(_availability),
                        workingHours: formatWorkingHours(_availability),
                        serviceMode: 'On-site',
                        onEdit: () => ProviderAvailabilityScreen.open(context, appUser: widget.appUser)
                            .then((_) => _loadExtras()),
                      ),
                    ],
                  ],
                );

                return MemberProfileColumns(
                  sidebar: sidebar,
                  main: main,
                  rightRail: rightRail,
                );
              },
            );
          },
        );
      },
    );
  }

  /// Customer-visible mean of reviews. Stored [ServiceProviderProfile.averageRating]
  /// is Bayesian (pulled toward ~3.5 for small n) and is only for ranking.
  double _effectiveRating(ServiceProviderProfile? profile, List<Review> reviews) {
    return effectiveProviderRating(
      profileAverage: profile?.averageRating ?? 0,
      reviews: reviews,
    );
  }
}
