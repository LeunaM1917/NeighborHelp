import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../screens/shared/customer_reputation_screen.dart';
import '../services/firestore_service.dart';
import '../theme/mobile_layout.dart';
import '../theme/role_theme.dart';
import '../utils/review_sentiment.dart';
import 'member_profile/member_profile_kit.dart';

/// Scrollable customer profile dialog for providers — highlights live ratings & reviews.
Future<void> showCustomerReputationDialog(
  BuildContext context, {
  required AppUser appUser,
  required AppUser customer,
  Booking? booking,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _CustomerReputationDialog(
      appUser: appUser,
      customer: customer,
      booking: booking,
    ),
  );
}

class _CustomerReputationDialog extends StatelessWidget {
  const _CustomerReputationDialog({
    required this.appUser,
    required this.customer,
    this.booking,
  });

  final AppUser appUser;
  final AppUser customer;
  final Booking? booking;

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
                      'Customer profile',
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
                  stream: firestore.userStream(customer.userId),
                  builder: (context, userSnap) {
                    final user = userSnap.data ?? customer;
                    return StreamBuilder<List<Review>>(
                      stream: firestore.reviewsForCustomerStream(user.userId),
                      builder: (context, reviewSnap) {
                        final reviews = reviewSnap.data ?? const <Review>[];
                        final rating = effectiveCustomerRating(reviews);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CustomerHeader(user: user, rating: rating, reviewCount: reviews.length),
                            const SizedBox(height: 20),
                            if (user.bio?.trim().isNotEmpty == true) ...[
                              Text(
                                user.bio!.trim(),
                                style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray700, height: 1.45),
                              ),
                              const SizedBox(height: 20),
                            ],
                            MemberProfileReviewsSection(
                              reviews: reviews,
                              averageRating: rating,
                              maxListItems: 12,
                              emptyMessage:
                                  'No provider feedback yet. Reviews appear after completed milestones when providers rate the customer.',
                            ),
                          ],
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
                      CustomerReputationScreen.open(
                        context,
                        appUser: appUser,
                        customer: customer,
                        booking: booking,
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

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.user,
    required this.rating,
    required this.reviewCount,
  });

  final AppUser user;
  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final rc = context.roleColors;
    final name = user.fullName.isNotEmpty ? user.fullName : 'Customer';
    final location = memberProfileLocation(user);
    final verified = user.isVerifiedCustomer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: rc.tint,
          backgroundImage: user.profilePhotoUrl != null ? NetworkImage(user.profilePhotoUrl!) : null,
          child: user.profilePhotoUrl == null
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
              Text(location, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
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
                      '($reviewCount review${reviewCount == 1 ? '' : 's'} from providers)',
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
