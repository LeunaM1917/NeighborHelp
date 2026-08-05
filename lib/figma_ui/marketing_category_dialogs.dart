import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/review.dart';
import '../models/service.dart';
import '../screens/customer/customer_service_detail_screen.dart';
import '../demo/job_title_ranking_demos.dart';
import '../services/firestore_service.dart';
import '../utils/listing_rating.dart';
import '../widgets/customer_provider_profile_dialog.dart';
import 'figma_colors.dart';
import 'marketing_featured_services.dart';
import 'marketing_service_catalog.dart';
import 'marketing_service_images.dart';
import 'pages/figma_signup_landing_page.dart';
import 'widgets/figma_network_image.dart';

/// When set, category/service dialogs book against live Firestore listings (customer app).
class MarketingBrowseContext {
  const MarketingBrowseContext({this.appUser});

  final AppUser? appUser;

  bool get isAuthenticated => appUser != null;
}

/// Opens service detail for a featured marketing card.
void openMarketingFeaturedService(
  BuildContext context,
  MarketingFeaturedService card, {
  MarketingBrowseContext? browseContext,
}) {
  final resolved = MarketingServiceCatalog.resolveForCard(
    categoryId: card.categoryId,
    serviceTitle: card.title,
  );
  if (resolved == null) return;
  showMarketingServiceDetail(
    context,
    service: resolved.service,
    category: resolved.category,
    browseContext: browseContext,
  );
}

/// Opens a scrollable list of services for [category].
void showMarketingCategoryServices(
  BuildContext context,
  MarketingServiceCategory category, {
  MarketingBrowseContext? browseContext,
}) {
  final ctx = browseContext ?? const MarketingBrowseContext();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => _CategoryServicesDialog(
      category: category,
      browseContext: ctx,
    ),
  );
}

/// Opens service detail with description and providers.
void showMarketingServiceDetail(
  BuildContext context, {
  required MarketingServiceItem service,
  required MarketingServiceCategory category,
  MarketingBrowseContext? browseContext,
  int dialogsToCloseOnBook = 1,
}) {
  final ctx = browseContext ?? const MarketingBrowseContext();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => _ServiceDetailDialog(
      service: service,
      category: category,
      browseContext: ctx,
      dialogsToCloseOnBook: dialogsToCloseOnBook,
    ),
  );
}

Future<void> _openServiceDetail(
  BuildContext context, {
  required AppUser appUser,
  required ServiceListing listing,
  required int dialogsToClose,
}) async {
  final navigator = Navigator.of(context);
  for (var i = 0; i < dialogsToClose; i++) {
    if (navigator.canPop()) navigator.pop();
  }
  await navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CustomerServiceDetailScreen(
        appUser: appUser,
        listing: listing,
      ),
    ),
  );
}

Future<ServiceListing?> _pickListingIfNeeded(
  BuildContext context,
  List<ServiceListing> matches,
) async {
  if (matches.length == 1) return matches.first;
  return showModalBottomSheet<ServiceListing>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Choose a listing',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: matches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final listing = matches[index];
                  return ListTile(
                    title: Text(
                      listing.serviceTitle,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '₱${listing.estimatedPrice.toStringAsFixed(0)} • ${listing.category}',
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(ctx, listing),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CategoryServicesDialog extends StatelessWidget {
  const _CategoryServicesDialog({
    required this.category,
    required this.browseContext,
  });

  final MarketingServiceCategory category;
  final MarketingBrowseContext browseContext;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width > 600 ? 520.0 : width * 0.92;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: category.bg, borderRadius: BorderRadius.circular(8)),
                    child: Icon(category.icon, color: category.fg, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                        ),
                        Text(
                          '${category.serviceCount} services available',
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: FigmaColors.gray500),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: FigmaColors.gray100),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: category.services.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20, color: FigmaColors.gray100),
                itemBuilder: (context, index) {
                  final service = category.services[index];
                  final thumbUrl = MarketingServiceImages.urlFor(
                    serviceName: service.name,
                    categoryId: category.id,
                  );
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: FigmaNetworkImage(url: thumbUrl, fit: BoxFit.cover),
                      ),
                    ),
                    title: Text(
                      service.name,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                    ),
                    subtitle: Text(
                      'From ₱${service.startingPricePhp}',
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: FigmaColors.gray400, size: 22),
                    onTap: () {
                      showMarketingServiceDetail(
                        context,
                        service: service,
                        category: category,
                        browseContext: browseContext,
                        dialogsToCloseOnBook: 2,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceDetailDialog extends StatefulWidget {
  const _ServiceDetailDialog({
    required this.service,
    required this.category,
    required this.browseContext,
    required this.dialogsToCloseOnBook,
  });

  final MarketingServiceItem service;
  final MarketingServiceCategory category;
  final MarketingBrowseContext browseContext;
  final int dialogsToCloseOnBook;

  @override
  State<_ServiceDetailDialog> createState() => _ServiceDetailDialogState();
}

class _ServiceDetailDialogState extends State<_ServiceDetailDialog> {
  final FirestoreService _firestore = FirestoreService();
  bool _booking = false;
  List<ServiceListing>? _matchedListings;
  Map<String, AppUser?> _providerUsers = {};
  Map<String, ServiceProviderProfile?> _providerProfiles = {};

  @override
  void initState() {
    super.initState();
    if (widget.browseContext.isAuthenticated) {
      _loadLiveListings();
    }
  }

  Future<void> _loadLiveListings() async {
    final listings = await _firestore.fetchActiveServices();
    final matches = MarketingServiceCatalog.matchActiveListings(
      listings,
      marketingServiceName: widget.service.name,
      marketingCategoryName: widget.category.name,
    );
    final users = <String, AppUser?>{};
    final profiles = <String, ServiceProviderProfile?>{};
    for (final listing in matches) {
      users[listing.providerId] ??= await _firestore.getUser(listing.providerId);
      profiles[listing.providerId] ??= await _firestore.getProviderProfile(listing.providerId);
    }

    // Live listings + Ceiling Repair demo peers (UI-only), ranked by RS.
    final ranked = mergeAndRankListingsForJobTitle(
      serviceTitle: widget.service.name,
      liveListings: matches,
      liveProfiles: profiles,
      liveUsers: users,
      customerOrigin: widget.browseContext.appUser?.location,
      absorbDemoMaps: (p, u) {
        profiles
          ..clear()
          ..addAll(p);
        users
          ..clear()
          ..addAll(u);
      },
    );

    if (!mounted) return;
    setState(() {
      _matchedListings = ranked;
      _providerUsers = users;
      _providerProfiles = profiles;
    });
  }

  Future<void> _onBookNow() async {
    final appUser = widget.browseContext.appUser;
    if (appUser == null) {
      Navigator.pop(context);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FigmaSignUpLandingPage()),
      );
      return;
    }

    setState(() => _booking = true);
    try {
      final matches = (_matchedListings ??
              MarketingServiceCatalog.matchActiveListings(
                await _firestore.fetchActiveServices(),
                marketingServiceName: widget.service.name,
                marketingCategoryName: widget.category.name,
              ))
          .where((l) => !isJobTitleDemoProviderId(l.providerId))
          .toList();

      if (!mounted) return;
      if (matches.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No live listing for "${widget.service.name}" yet. Demo rows are for ranking demos only.',
              style: GoogleFonts.inter(),
            ),
          ),
        );
        return;
      }

      final listing = await _pickListingIfNeeded(context, matches);
      if (listing == null || !mounted) return;

      await _openServiceDetail(
        context,
        appUser: appUser,
        listing: listing,
        dialogsToClose: widget.dialogsToCloseOnBook,
      );
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _openListing(ServiceListing listing) async {
    final appUser = widget.browseContext.appUser;
    if (appUser == null) return;
    await _openServiceDetail(
      context,
      appUser: appUser,
      listing: listing,
      dialogsToClose: widget.dialogsToCloseOnBook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width > 640 ? 560.0 : width * 0.94;
    final imageUrl = MarketingServiceImages.urlFor(
      serviceName: widget.service.name,
      categoryId: widget.category.id,
    );
    final authenticated = widget.browseContext.isAuthenticated;
    final liveListings = _matchedListings ?? const <ServiceListing>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.name,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: FigmaColors.green),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.service.name,
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: FigmaColors.gray500),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: FigmaNetworkImage(url: imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.service.description,
                      style: GoogleFonts.inter(fontSize: 15, color: FigmaColors.gray600, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FigmaColors.gray50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: FigmaColors.gray100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 20, color: FigmaColors.navy),
                          const SizedBox(width: 10),
                          Text(
                            'Starting at ₱${widget.service.startingPricePhp}',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Available providers nearby',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authenticated
                          ? (_matchedListings == null
                              ? 'Loading providers…'
                              : liveListings.isEmpty
                                  ? 'Only providers who listed this exact service appear here.'
                                  : widget.service.name.trim().toLowerCase() == 'ceiling repair'
                                      ? 'Ranked by RS for "Ceiling Repair" · includes sample peers for fairness demo.'
                                      : 'Ranked by recommendation score (0.40P+0.30R+0.20A+0.10C) for "${widget.service.name}".')
                          : 'Sample listings — sign up to book with real providers in your area.',
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                    ),
                    const SizedBox(height: 12),
                    if (authenticated && _matchedListings == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (authenticated && liveListings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'No providers have listed "${widget.service.name}" yet. Browse All services for other live listings.',
                          style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500, height: 1.4),
                        ),
                      )
                    else if (authenticated && liveListings.isNotEmpty)
                      ...[
                        for (var i = 0; i < liveListings.length; i++)
                          _LiveProviderCard(
                            listing: liveListings[i],
                            providerUser: _providerUsers[liveListings[i].providerId],
                            providerProfile: _providerProfiles[liveListings[i].providerId],
                            rank: i + 1,
                            isDemo: isJobTitleDemoProviderId(liveListings[i].providerId),
                            onTap: () {
                              final listing = liveListings[i];
                              if (isJobTitleDemoProviderId(listing.providerId)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_providerUsers[listing.providerId]?.fullName ?? 'Demo'} — '
                                      'sample listing for ranking fairness on this job title. '
                                      'Book a live provider to continue.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _openListing(listing);
                            },
                            onViewProfile: widget.browseContext.appUser == null ||
                                    isJobTitleDemoProviderId(liveListings[i].providerId)
                                ? null
                                : () {
                                    final appUser = widget.browseContext.appUser!;
                                    final listing = liveListings[i];
                                    showCustomerProviderProfileDialog(
                                      context,
                                      appUser: appUser,
                                      providerId: listing.providerId,
                                      providerUser: _providerUsers[listing.providerId],
                                      providerProfile: _providerProfiles[listing.providerId],
                                    );
                                  },
                          ),
                      ]
                    else
                      ...widget.service.providers.map((p) => _SampleProviderCard(provider: p)),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: FigmaColors.gray100),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _booking ? null : _onBookNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: FigmaColors.navy,
                    foregroundColor: FigmaColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _booking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: FigmaColors.white),
                        )
                      : Text(
                          authenticated ? 'Book Now' : 'Sign up to book',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveProviderCard extends StatelessWidget {
  const _LiveProviderCard({
    required this.listing,
    required this.providerUser,
    required this.providerProfile,
    required this.onTap,
    this.onViewProfile,
    this.rank,
    this.isDemo = false,
  });

  final ServiceListing listing;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;
  final VoidCallback onTap;
  final VoidCallback? onViewProfile;
  final int? rank;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final name = providerUser?.fullName.isNotEmpty == true ? providerUser!.fullName : 'Provider';
    final area = providerProfile?.serviceArea.isNotEmpty == true ? providerProfile!.serviceArea : 'Your area';
    final verified = providerProfile?.isVerifiedProvider == true;
    final profileAverage = providerProfile?.averageRating ?? 0;
    final profileReviewCount = providerProfile?.reviewCount ?? 0;

    Widget cardBody(ServiceListingRating rating) {
      return Material(
        color: FigmaColors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FigmaColors.gray100),
            ),
            child: Row(
              children: [
                if (rank != null) ...[
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.navy,
                      ),
                    ),
                  ),
                ],
                CircleAvatar(
                  radius: 22,
                  backgroundColor: FigmaColors.tintBlue,
                  backgroundImage:
                      providerUser?.profilePhotoUrl != null ? NetworkImage(providerUser!.profilePhotoUrl!) : null,
                  child: providerUser?.profilePhotoUrl == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: FigmaColors.navy),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: FigmaColors.gray900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (verified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, size: 16, color: FigmaColors.green),
                          ],
                          if (isDemo) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: FigmaColors.gray200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Demo',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: FigmaColors.gray600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        listing.serviceTitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FigmaColors.navy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(area, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
                      if (onViewProfile != null) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: onViewProfile,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'View profile',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: FigmaColors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _ListingRatingColumn(rating: rating, price: listing.estimatedPrice),
              ],
            ),
          ),
        ),
      );
    }

    if (isDemo) {
      final hasServiceReviews = profileReviewCount > 0 && profileAverage > 0;
      return cardBody(
        ServiceListingRating(
          serviceRating: hasServiceReviews ? profileAverage : 0,
          serviceReviewCount: hasServiceReviews ? profileReviewCount : 0,
          overallRating: hasServiceReviews ? profileAverage : 0,
          overallReviewCount: hasServiceReviews ? profileReviewCount : 0,
        ),
      );
    }

    final firestore = FirestoreService();
    return StreamBuilder<List<ServiceListing>>(
      stream: firestore.servicesForProvider(listing.providerId),
      builder: (context, servicesSnap) {
        final providerListings = servicesSnap.data ?? const <ServiceListing>[];
        final serviceIds = serviceIdsMatchingListing(
          listing: listing,
          providerListings: providerListings,
        );
        return StreamBuilder<List<Review>>(
          stream: firestore.reviewsForProviderStream(listing.providerId),
          builder: (context, reviewSnap) {
            final rating = computeServiceListingRating(
              reviews: reviewSnap.data ?? const <Review>[],
              serviceIds: serviceIds,
              profileAverage: profileAverage,
              profileReviewCount: profileReviewCount,
            );
            return cardBody(rating);
          },
        );
      },
    );
  }
}

class _ListingRatingColumn extends StatelessWidget {
  const _ListingRatingColumn({required this.rating, required this.price});

  final ServiceListingRating rating;
  final double price;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (rating.hasServiceReviews) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: Color(0xFFFBBF24)),
              const SizedBox(width: 4),
              Text(
                rating.serviceRating.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FigmaColors.gray900,
                ),
              ),
            ],
          ),
          Text(
            '${rating.serviceReviewCount} for this service',
            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
          ),
        ] else ...[
          Text(
            'New for this service',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FigmaColors.gray900,
            ),
          ),
        ],
        if (rating.hasOverallReviews)
          Text(
            'Overall ${rating.overallRating.toStringAsFixed(1)} (${rating.overallReviewCount})',
            style: GoogleFonts.inter(fontSize: 11, color: FigmaColors.gray500),
          ),
        Text(
          '₱${price.toStringAsFixed(0)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: FigmaColors.navy,
          ),
        ),
      ],
    );
  }
}

class _SampleProviderCard extends StatelessWidget {
  const _SampleProviderCard({required this.provider});

  final MarketingSampleProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FigmaColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FigmaColors.gray100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: FigmaColors.tintBlue,
            child: Text(
              provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: FigmaColors.navy),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        provider.name,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 16, color: FigmaColors.green),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  provider.area,
                  style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 4),
                  Text(
                    provider.rating.toStringAsFixed(1),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                  ),
                ],
              ),
              Text(
                '${provider.reviews} reviews',
                style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
