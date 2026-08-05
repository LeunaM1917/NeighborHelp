import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/booking.dart';
import '../models/review.dart';
import '../services/firestore_service.dart';
import 'review_tile.dart';

/// Ratings and reviews left on a completed milestone booking.
class MilestoneFeedbackDetails extends StatelessWidget {
  const MilestoneFeedbackDetails({
    super.key,
    required this.booking,
    required this.viewerRole,
    required this.customerName,
    required this.providerName,
    this.compact = false,
  });

  final Booking booking;
  /// `customer` or `provider`
  final String viewerRole;
  final String customerName;
  final String providerName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!booking.isMilestoneComplete) return const SizedBox.shrink();

    return StreamBuilder<List<Review>>(
      stream: FirestoreService().reviewsForBookingStream(booking.bookingId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Loading reviews…',
              style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500),
            ),
          );
        }

        final reviews = snap.data ?? [];
        Review? customerReview;
        Review? providerReview;
        for (final r in reviews) {
          if (r.isCustomerReview) customerReview = r;
          if (r.isProviderReview) providerReview = r;
        }

        if (customerReview == null && providerReview == null) {
          return Text(
            'No reviews yet for this milestone.',
            style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
          );
        }

        final isCustomer = viewerRole == 'customer';
        final children = <Widget>[
          if (!compact) ...[
            Text(
              'Reviews',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: FigmaColors.gray800),
            ),
            const SizedBox(height: 10),
          ],
          if (customerReview != null)
            ReviewTile(
              review: customerReview,
              subtitle: isCustomer ? 'Your review' : 'From $customerName',
            )
          else
            _missingReview(
              isCustomer ? 'You have not reviewed this milestone yet.' : 'No review from the customer yet.',
            ),
          if (providerReview != null) ...[
            const SizedBox(height: 14),
            ReviewTile(
              review: providerReview,
              subtitle: isCustomer ? 'From $providerName' : 'Your feedback',
            ),
          ] else if (!isCustomer) ...[
            const SizedBox(height: 14),
            _missingReview('You have not left feedback for this milestone yet.'),
          ] else ...[
            const SizedBox(height: 14),
            _missingReview('No feedback from the provider yet.'),
          ],
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }

  Widget _missingReview(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.4),
      ),
    );
  }
}
