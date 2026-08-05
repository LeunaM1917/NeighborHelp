import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../models/booking.dart';
import '../../../widgets/milestone_review_section.dart';

/// Customer feedback for a completed milestone (wraps [MilestoneReviewSection]).
class BookingReviewSection extends StatelessWidget {
  const BookingReviewSection({
    super.key,
    required this.appUser,
    required this.booking,
  });

  final AppUser appUser;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return MilestoneReviewSection(
      appUser: appUser,
      booking: booking,
      reviewerRole: 'customer',
      title: 'Leave a review',
      subtitle: 'Help neighbors choose trusted providers',
    );
  }
}
