import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/marketing_service_images.dart';
import '../../figma_ui/widgets/figma_network_image.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/provider.dart';
import '../../models/review.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../theme/role_theme.dart';
import '../../utils/review_sentiment.dart';
import '../../widgets/member_profile/member_profile_kit.dart';
import '../customer/customer_service_detail_screen.dart';
import 'messages_hub.dart';

/// Public provider profile (customer viewing a provider).
class PublicProviderProfileBody extends StatelessWidget {
  const PublicProviderProfileBody({
    super.key,
    required this.viewer,
    required this.providerId,
    this.providerUser,
  });

  final AppUser viewer;
  final String providerId;
  final AppUser? providerUser;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return StreamBuilder<AppUser?>(
      stream: firestore.userStream(providerId),
      builder: (context, userSnap) {
        final user = userSnap.data ?? providerUser;
        return StreamBuilder<ServiceProviderProfile?>(
          stream: firestore.providerProfileForUser(providerId),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting && user == null) {
              return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
            }
            final profile = profileSnap.data;
            return StreamBuilder<List<Review>>(
              stream: firestore.reviewsForProviderStream(providerId),
              builder: (context, reviewSnap) {
                final reviews = reviewSnap.data ?? [];
                final rating = effectiveProviderRating(
                  profileAverage: profile?.averageRating ?? 0,
                  reviews: reviews,
                );
                final area = profile?.serviceArea.isNotEmpty == true ? profile!.serviceArea : 'Local area';
                final radius = profile?.serviceRadiusKm.toStringAsFixed(0) ?? '5';
                final verified = profile?.isVerifiedProvider == true;
                final memberSince = user != null ? memberProfileMemberSince(user.createdAt.toDate()) : '';

                final sidebar = MemberProfileSidebar(
                  name: user?.fullName ?? 'Service provider',
                  headline: area,
                  roleLabel: 'Service provider',
                  photoUrl: user?.profilePhotoUrl,
                  badges: [
                    if (verified)
                      const MemberProfileBadge(
                        label: 'Verified',
                        icon: Icons.verified,
                        background: FigmaColors.tintGreen,
                        foreground: FigmaColors.green,
                      ),
                  ],
                  metaLines: [
                    MemberProfileMetaLine(icon: Icons.place_outlined, text: area),
                    MemberProfileMetaLine(icon: Icons.my_location_outlined, text: '$radius km radius'),
                    if (memberSince.isNotEmpty)
                      MemberProfileMetaLine(icon: Icons.calendar_today_outlined, text: 'Member since $memberSince'),
                  ],
                  stats: [
                    MemberProfileStat(
                      value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                      label: 'Rating',
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFEAB308),
                    ),
                    MemberProfileStat(
                      value: '${profile?.completedBookings ?? 0}',
                      label: 'Milestones done',
                      icon: Icons.check_circle_outline,
                      iconColor: FigmaColors.green,
                    ),
                    MemberProfileStat(
                      value: '${reviews.length}',
                      label: 'Reviews',
                      icon: Icons.rate_review_outlined,
                    ),
                  ],
                );

                final main = <Widget>[
                  MemberProfileStatStrip(
                    items: [
                      (icon: Icons.work_outline, value: '${profile?.completedBookings ?? 0}', label: 'Completed jobs'),
                      (icon: Icons.star_outline_rounded, value: rating.toStringAsFixed(1), label: 'Average rating'),
                      (icon: Icons.bolt_outlined, value: 'Responsive', label: 'Usually replies quickly'),
                      (icon: Icons.schedule_outlined, value: 'On-site', label: 'NeighborHelp services'),
                    ],
                  ),
                  MemberProfileOverviewSection(
                    body: profile?.bio.isNotEmpty == true
                        ? profile!.bio
                        : 'This provider has not added an introduction yet.',
                    tags: profile?.profileTraits ?? const [],
                  ),
                  ..._providerProfessionalSections(profile: profile),
                  _ServicesSection(viewer: viewer, providerId: providerId),
                  MemberProfileReviewsSection(
                    reviews: reviews,
                    averageRating: rating,
                    emptyMessage: 'Be the first to leave a review after a completed milestone.',
                  ),
                ];

                final rightRail = _ProviderActionsRail(
                  viewer: viewer,
                  providerId: providerId,
                  user: user,
                  profile: profile,
                );

                return MemberProfileColumns(sidebar: sidebar, main: main, rightRail: rightRail);
              },
            );
          },
        );
      },
    );
  }
}

/// Employment, education, portfolio, certifications, and other saved profile fields.
List<Widget> _providerProfessionalSections({required ServiceProviderProfile? profile}) {
  if (profile == null) return const [];

  final sections = <Widget>[];

  if (profile.hasEmployment) {
    sections.add(
      MemberProfileTimelineSection(
        title: 'Employment history',
        entries: profile.employmentDisplayLines,
      ),
    );
  }

  if (profile.hasEducation) {
    sections.add(
      MemberProfileTimelineSection(
        title: 'Education',
        icon: Icons.school_outlined,
        entries: profile.educationDisplayLines,
      ),
    );
  }

  if (profile.hasPortfolio) {
    sections.add(
      MemberProfilePortfolioSection(
        urls: profile.portfolioThumbnailUrls,
        projects: profile.effectivePortfolioProjects,
      ),
    );
  }

  if (profile.hasApprovedCertifications) {
    sections.add(
      MemberProfileCertificationsSection(
        certifications: profile.approvedCertifications,
      ),
    );
  }

  if (profile.otherExperiences.isNotEmpty) {
    sections.add(
      MemberProfileTimelineSection(
        title: 'Other experiences',
        icon: Icons.auto_awesome_outlined,
        entries: profile.otherExperiences,
      ),
    );
  }

  if (profile.linkedAccounts.isNotEmpty) {
    sections.add(MemberProfileLinkedAccountsSection(accounts: profile.linkedAccounts));
  }

  return sections;
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.viewer, required this.providerId});

  final AppUser viewer;
  final String providerId;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return MemberProfileSectionCard(
      title: 'Services offered',
      icon: Icons.home_repair_service_outlined,
      child: StreamBuilder<List<ServiceListing>>(
        stream: firestore.servicesForProvider(providerId),
        builder: (context, snap) {
          final services = (snap.data ?? []).where((s) => s.isMarketplaceVisible).toList();
          if (services.isEmpty) {
            return Text(
              'No published services yet.',
              style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray600),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < services.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ServiceTile(
                  listing: services[i],
                  onView: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerServiceDetailScreen(appUser: viewer, listing: services[i]),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.listing, required this.onView});

  final ServiceListing listing;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final imageUrl = listing.serviceImages.isNotEmpty
        ? listing.serviceImages.first
        : MarketingServiceImages.urlFor(serviceName: listing.serviceTitle, categoryName: listing.category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 88,
              height: 72,
              child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.serviceTitle, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(listing.category, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: rc.primary)),
                Text('₱${listing.estimatedPrice.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onView,
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _ProviderActionsRail extends StatelessWidget {
  const _ProviderActionsRail({
    required this.viewer,
    required this.providerId,
    required this.user,
    required this.profile,
  });

  final AppUser viewer;
  final String providerId;
  final AppUser? user;
  final ServiceProviderProfile? profile;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final firestore = FirestoreService();
    final verified = profile?.isVerifiedProvider == true;
    final area = profile?.serviceArea.isNotEmpty == true ? profile!.serviceArea : 'your area';
    final radius = profile?.serviceRadiusKm.toStringAsFixed(0) ?? '5';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemberProfileSectionCard(
          title: 'Book or contact',
          icon: Icons.calendar_today_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Message to check availability or book a service.',
                style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.45),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Booking>>(
                stream: firestore.bookingsForUser(viewer.userId, asCustomer: true),
                builder: (context, snap) {
                  final related = (snap.data ?? []).where((b) => b.providerId == providerId).toList();
                  return FilledButton.icon(
                    onPressed: () {
                      if (related.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Book a service first to message this provider.')),
                        );
                        return;
                      }
                      MessagesHub.openConversation(context, appUser: viewer, booking: related.first, asCustomer: true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: rc.primary,
                      foregroundColor: rc.onPrimary,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message provider'),
                  );
                },
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<ServiceListing>>(
                stream: firestore.servicesForProvider(providerId),
                builder: (context, snap) {
                  final services = (snap.data ?? []).where((s) => s.isMarketplaceVisible).toList();
                  return OutlinedButton.icon(
                    onPressed: services.isEmpty
                        ? null
                        : () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerServiceDetailScreen(appUser: viewer, listing: services.first),
                              ),
                            ),
                    icon: const Icon(Icons.event_available_outlined, size: 18),
                    label: const Text('Book now'),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        MemberProfileSectionCard(
          title: 'Why book with confidence',
          icon: Icons.shield_outlined,
          child: Column(
            children: [
              if (verified) _TrustLine(icon: Icons.verified_user_outlined, title: 'Verified provider', subtitle: 'Identity verified on NeighborHelp.'),
              if (verified) const SizedBox(height: 12),
              _TrustLine(icon: Icons.place_outlined, title: 'Service area', subtitle: 'Within $radius km of $area.'),
              const SizedBox(height: 12),
              _TrustLine(
                icon: Icons.work_outline,
                title: 'Track record',
                subtitle: '${profile?.completedBookings ?? 0} completed milestone${(profile?.completedBookings ?? 0) == 1 ? '' : 's'}.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: rc.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500, height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}
