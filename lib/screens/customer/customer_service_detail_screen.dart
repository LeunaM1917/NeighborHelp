import '../shared/inquiry_screen.dart';
import '../../services/marketplace_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/figma_layout.dart';
import '../../theme/mobile_layout.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../figma_ui/marketing_service_images.dart';
import '../../figma_ui/widgets/figma_network_image.dart';
import '../../models/app_user.dart';
import '../../models/provider.dart';
import '../../models/review.dart';
import '../../models/service.dart';
import '../../models/service_approval_status.dart';
import '../../services/firestore_service.dart';
import '../../utils/listing_rating.dart';
import '../../utils/review_job_label.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/review_tile.dart';

class CustomerServiceDetailScreen extends StatefulWidget {
  const CustomerServiceDetailScreen({
    super.key,
    required this.appUser,
    required this.listing,
  });

  final AppUser appUser;
  final ServiceListing listing;

  @override
  State<CustomerServiceDetailScreen> createState() =>
      _CustomerServiceDetailScreenState();
}

class _CustomerServiceDetailScreenState
    extends State<CustomerServiceDetailScreen> {
  bool _submitting = false;
  Future<void> _messageProvider() async {
    setState(() => _submitting = true);
    try {
      final id = await MarketplaceService.openInquiry(widget.listing.serviceId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => InquiryScreen(appUser: widget.appUser, inquiryId: id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not open the conversation. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: StreamBuilder<AppUser?>(
          stream: firestore.userStream(widget.listing.providerId),
          builder: (context, providerUserSnap) {
            return StreamBuilder<ServiceProviderProfile?>(
              stream: firestore.providerProfileForUser(
                widget.listing.providerId,
              ),
              builder: (context, providerSnap) {
                final loading =
                    providerUserSnap.connectionState ==
                        ConnectionState.waiting ||
                    providerSnap.connectionState == ConnectionState.waiting;

                if (loading) {
                  return const Center(
                    child: LoadingIndicator(
                      message: 'Loading provider…',
                      showBrand: true,
                    ),
                  );
                }

                final imageUrl = widget.listing.serviceImages.isNotEmpty
                    ? widget.listing.serviceImages.first
                    : MarketingServiceImages.urlFor(
                        serviceName: widget.listing.serviceTitle,
                        categoryName: widget.listing.category,
                      );
                final compactPhoto = _ServiceHeroPhoto(
                  url: imageUrl,
                  compact: true,
                );
                final headerCopy = _HeaderCopy(
                  listing: widget.listing,
                  providerUser: providerUserSnap.data,
                  providerProfile: providerSnap.data,
                );
                final left = _ServiceAndProviderSection(
                  listing: widget.listing,
                  providerId: widget.listing.providerId,
                  providerUser: providerUserSnap.data,
                  providerProfile: providerSnap.data,
                );
                final right = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Discuss your job first',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Message this provider about the work, materials, schedule and price. You may contact several providers to compare before sending a fixed or daily contract offer.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _messageProvider,
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(
                            _submitting ? 'Opening...' : 'Message Provider',
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                final nativeMobile = MobileLayout.isNativeApp(context);

                return SingleChildScrollView(
                  child: FigmaWideContainer(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        nativeMobile ? 8 : 16,
                        0,
                        nativeMobile
                            ? MobileLayout.pageBottomPadding(context)
                            : 80,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to services'),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, c) {
                              final wide = c.maxWidth >= 900;
                              if (!wide) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    headerCopy,
                                    const SizedBox(height: 16),
                                    _ServiceHeroPhoto(
                                      url: imageUrl,
                                      compact: false,
                                    ),
                                    const SizedBox(height: 24),
                                    left,
                                    const SizedBox(height: 24),
                                    right,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: headerCopy),
                                            const SizedBox(width: 20),
                                            compactPhoto,
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        left,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  SizedBox(width: 380, child: right),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy({
    required this.listing,
    required this.providerUser,
    required this.providerProfile,
  });

  final ServiceListing listing;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final providerName = providerUser?.fullName.trim().isNotEmpty == true
        ? providerUser!.fullName
        : 'Local service provider';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: FigmaColors.tintGreen,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            listing.category,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FigmaColors.green,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          listing.serviceTitle,
          style: GoogleFonts.inter(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: FigmaColors.gray900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              'Offered by $providerName',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: rc.primary,
              ),
            ),
            if (providerProfile?.isVerifiedProvider == true)
              const _VerifiedBadge(compact: true),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<ServiceListing>>(
          stream: FirestoreService().servicesForProvider(listing.providerId),
          builder: (context, servicesSnap) {
            final serviceIds = serviceIdsMatchingListing(
              listing: listing,
              providerListings: servicesSnap.data ?? const <ServiceListing>[],
            );
            return StreamBuilder<List<Review>>(
              stream: FirestoreService().reviewsForProviderStream(
                listing.providerId,
              ),
              builder: (context, snap) {
                final rating = computeServiceListingRating(
                  reviews: snap.data ?? const <Review>[],
                  serviceIds: serviceIds,
                  profileAverage: providerProfile?.averageRating ?? 0,
                  profileReviewCount: providerProfile?.reviewCount ?? 0,
                );
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    if (rating.hasServiceReviews) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: FigmaColors.yellow500,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.serviceRating.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FigmaColors.gray900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${rating.serviceReviewCount} for this service',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: FigmaColors.gray600,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'New for this service',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: FigmaColors.gray900,
                        ),
                      ),
                    if (rating.hasOverallReviews)
                      Text(
                        'Overall ${rating.overallRating.toStringAsFixed(1)} (${rating.overallReviewCount})',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: FigmaColors.gray600,
                        ),
                      ),
                    Text(
                      '${providerProfile?.completedBookings ?? 0} completed jobs',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: FigmaColors.gray600,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: FigmaColors.tintGreen,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FigmaColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: compact ? 16 : 18,
            color: FigmaColors.green,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: GoogleFonts.inter(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: FigmaColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Service listing hero image — [compact] fits beside the header on wide layouts.
class _ServiceHeroPhoto extends StatelessWidget {
  const _ServiceHeroPhoto({required this.url, this.compact = false});

  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 240,
          height: 160,
          child: FigmaNetworkImage(url: url, fit: BoxFit.cover),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: FigmaNetworkImage(url: url, fit: BoxFit.cover),
      ),
    );
  }
}

class _ServiceAndProviderSection extends StatelessWidget {
  const _ServiceAndProviderSection({
    required this.listing,
    required this.providerId,
    required this.providerUser,
    required this.providerProfile,
  });

  final ServiceListing listing;
  final String providerId;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoPanel(
          title: 'Service details',
          icon: Icons.description_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.description.isNotEmpty
                    ? listing.description
                    : 'This provider has not added a detailed description yet.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: FigmaColors.gray700,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FactChip(
                    icon: Icons.payments_outlined,
                    label:
                        '₱${listing.estimatedPrice.toStringAsFixed(0)} ${listing.priceType}',
                  ),
                  _FactChip(
                    icon: Icons.schedule_outlined,
                    label: listing.estimatedDuration.isNotEmpty
                        ? listing.estimatedDuration
                        : 'Duration flexible',
                  ),
                  _FactChip(
                    icon: Icons.verified_outlined,
                    label: listing.isMarketplaceVisible
                        ? 'Live listing'
                        : listing.approvalStatus.isPending
                        ? 'Pending admin review'
                        : listing.approvalStatus ==
                              ServiceApprovalStatus.rejected
                        ? 'Not approved'
                        : 'Not visible',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _InfoPanel(
          title: 'Provider profile',
          icon: Icons.person_pin_circle_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: rc.tint,
                    backgroundImage: providerUser?.profilePhotoUrl != null
                        ? NetworkImage(providerUser!.profilePhotoUrl!)
                        : null,
                    child: providerUser?.profilePhotoUrl == null
                        ? Icon(Icons.person_outline, color: rc.primary)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              providerUser?.fullName ??
                                  'Local service provider',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: FigmaColors.gray900,
                              ),
                            ),
                            if (providerProfile?.isVerifiedProvider == true)
                              const _VerifiedBadge(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          providerProfile?.serviceArea.isNotEmpty == true
                              ? providerProfile!.serviceArea
                              : 'Serving nearby communities',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: FigmaColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                providerProfile?.bio.isNotEmpty == true
                    ? providerProfile!.bio
                    : 'Provider bio will appear here once they complete their profile.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: FigmaColors.gray700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FactChip(
                    icon: Icons.map_outlined,
                    label:
                        providerProfile?.serviceCoverageLabel.isNotEmpty == true
                        ? providerProfile!.serviceCoverageLabel
                        : 'Service barangays not selected',
                  ),
                  if (providerProfile?.isVerifiedProvider != true)
                    _FactChip(
                      icon: Icons.pending_outlined,
                      label: 'Verification pending',
                    ),
                  _FactChip(
                    icon: Icons.handyman_outlined,
                    label:
                        '${providerProfile?.acceptedBookings ?? 0} accepted jobs',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: listing.serviceImages.isNotEmpty
                    ? () => _openServicePhotos(context, listing.serviceImages)
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: rc.primary,
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: rc.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  listing.serviceImages.isNotEmpty
                      ? 'View service photos (${listing.serviceImages.length})'
                      : 'No service photos yet',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ReviewsSection(providerId: providerId),
      ],
    );
  }

  void _openServicePhotos(BuildContext context, List<String> images) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.85;
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: FigmaColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Service photos',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.gray900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: FigmaColors.gray600,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: FigmaColors.gray200),
                Expanded(child: _ServicePhotoGallery(images: images)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    return _InfoPanel(
      title: 'Ratings and reviews',
      icon: Icons.reviews_outlined,
      child: FutureBuilder<List<Review>>(
        future: firestore.reviewsForProvider(providerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LoadingIndicator(message: 'Loading reviews…'),
            );
          }
          final reviews = snap.data ?? [];
          if (reviews.isEmpty) {
            return const FigmaEmptyState(
              icon: Icons.star_border_rounded,
              title: 'No reviews yet',
              message: 'Completed customer reviews will appear here.',
            );
          }
          return FutureBuilder<Map<String, String>>(
            future: firestore.serviceTitlesByIds(
              reviews.map((r) => r.serviceId),
            ),
            builder: (context, titlesSnap) {
              final titles = titlesSnap.data ?? const <String, String>{};
              final visible = reviews.take(6).toList();
              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    ReviewTile(
                      review: visible[i],
                      jobLabel: formatReviewJobLabel(
                        review: visible[i],
                        serviceTitle: titles[visible[i].serviceId],
                      ),
                    ),
                    if (i < visible.length - 1)
                      const Divider(height: 24, color: FigmaColors.gray200),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FigmaColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rc.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: rc.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: FigmaColors.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ServicePhotoGallery extends StatefulWidget {
  const _ServicePhotoGallery({required this.images});

  final List<String> images;

  @override
  State<_ServicePhotoGallery> createState() => _ServicePhotoGalleryState();
}

class _ServicePhotoGalleryState extends State<_ServicePhotoGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: FigmaColors.gray100,
            child: PageView.builder(
              controller: _controller,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) =>
                  FigmaNetworkImage(url: images[i], fit: BoxFit.contain),
            ),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  Container(
                    width: i == _index ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index
                          ? context.roleColors.primary
                          : FigmaColors.gray300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          )
        else
          const SizedBox(height: 14),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: rc.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray700,
            ),
          ),
        ],
      ),
    );
  }
}
