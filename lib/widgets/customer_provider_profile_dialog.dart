import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../models/review.dart';
import '../screens/customer/customer_provider_profile_screen.dart';
import '../services/firestore_service.dart';
import '../theme/mobile_layout.dart';
import '../theme/role_theme.dart';
import '../utils/review_sentiment.dart';
import 'member_profile/member_profile_kit.dart';

/// Scrollable provider profile dialog for customers — highlights live ratings & reviews.
Future<void> showCustomerProviderProfileDialog(
  BuildContext context, {
  required AppUser appUser,
  required String providerId,
  AppUser? providerUser,
  ServiceProviderProfile? providerProfile,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _CustomerProviderProfileDialog(
      appUser: appUser,
      providerId: providerId,
      providerUser: providerUser,
      providerProfile: providerProfile,
    ),
  );
}

class _CustomerProviderProfileDialog extends StatelessWidget {
  const _CustomerProviderProfileDialog({
    required this.appUser,
    required this.providerId,
    this.providerUser,
    this.providerProfile,
  });

  final AppUser appUser;
  final String providerId;
  final AppUser? providerUser;
  final ServiceProviderProfile? providerProfile;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final compact = MediaQuery.sizeOf(context).width < 600;
    final maxHeight = MediaQuery.sizeOf(context).height * (MobileLayout.isNativePlatform ? 0.92 : 0.85);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24, vertical: compact ? 16 : 24),
      backgroundColor: FigmaColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Provider profile',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: StreamBuilder<AppUser?>(
                  stream: firestore.userStream(providerId),
                  builder: (context, userSnap) {
                    final user = userSnap.data ?? providerUser;
                    return StreamBuilder<ServiceProviderProfile?>(
                      stream: firestore.providerProfileForUser(providerId),
                      builder: (context, profileSnap) {
                        final profile = profileSnap.data ?? providerProfile;
                        return StreamBuilder<List<Review>>(
                          stream: firestore.reviewsForProviderStream(providerId),
                          builder: (context, reviewSnap) {
                            final reviews = reviewSnap.data ?? const <Review>[];
                            final rating = effectiveProviderRating(
                              profileAverage: profile?.averageRating ?? 0,
                              reviews: reviews,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ProviderHeader(user: user, profile: profile, rating: rating, reviewCount: reviews.length),
                                const SizedBox(height: 20),
                                if (profile?.bio.isNotEmpty == true) ...[
                                  Text(
                                    profile!.bio,
                                    style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.45),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                MemberProfileReviewsSection(
                                  reviews: reviews,
                                  averageRating: rating,
                                  maxListItems: 12,
                                  emptyMessage: 'No customer reviews yet. Book a service and leave feedback after completion.',
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1, color: FigmaColors.gray100),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => CustomerProviderProfileScreen(
                            appUser: appUser,
                            providerId: providerId,
                            providerUser: providerUser,
                          ),
                        ),
                      );
                    },
                    child: const Text('View full profile'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({
    required this.user,
    required this.profile,
    required this.rating,
    required this.reviewCount,
  });

  final AppUser? user;
  final ServiceProviderProfile? profile;
  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Service provider';
    final area = profile?.serviceArea.isNotEmpty == true ? profile!.serviceArea : 'Local area';
    final verified = profile?.isVerifiedProvider == true;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: rc.tint,
          backgroundImage: user?.profilePhotoUrl != null ? NetworkImage(user!.profilePhotoUrl!) : null,
          child: user?.profilePhotoUrl == null
              ? Text(
                  name[0].toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: rc.primary),
                )
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 18, color: FigmaColors.green),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(area, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEAB308)),
                  const SizedBox(width: 4),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : 'New',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
                  ),
                  if (reviewCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($reviewCount review${reviewCount == 1 ? '' : 's'})',
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
