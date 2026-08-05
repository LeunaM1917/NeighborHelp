import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/review.dart';
import '../../services/firestore_service.dart';
import '../../utils/review_sentiment.dart';
import '../../widgets/member_profile/member_profile_kit.dart';
import 'messages_hub.dart';

/// Public customer profile (provider viewing a customer).
class PublicCustomerProfileBody extends StatelessWidget {
  const PublicCustomerProfileBody({
    super.key,
    required this.viewer,
    required this.customer,
    this.bookingForMessage,
  });

  final AppUser viewer;
  final AppUser customer;
  final Booking? bookingForMessage;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final memberSince = memberProfileMemberSince(customer.createdAt.toDate());
    final location = memberProfileLocation(customer);

    return StreamBuilder<List<Review>>(
      stream: firestore.reviewsForCustomerStream(customer.userId),
      builder: (context, reviewSnap) {
        return StreamBuilder<List<Booking>>(
          stream: firestore.bookingsForUser(customer.userId, asCustomer: true),
          builder: (context, bookingSnap) {
            final reviews = reviewSnap.data ?? [];
            final bookings = bookingSnap.data ?? [];
            var completedBookings = 0;
            for (final b in bookings) {
              if (b.isMilestoneComplete) completedBookings++;
            }
            final verified = customer.isVerifiedCustomer;
            final avg = effectiveCustomerRating(reviews);

            final sidebar = MemberProfileSidebar(
              name: customer.fullName.isNotEmpty ? customer.fullName : 'Customer',
              headline: 'NeighborHelp customer',
              roleLabel: 'Customer',
              photoUrl: customer.profilePhotoUrl,
              badges: [
                if (verified)
                  const MemberProfileBadge(
                    label: 'Verified',
                    icon: Icons.verified,
                    background: FigmaColors.tintGreen,
                    foreground: FigmaColors.green,
                  ),
                MemberProfileBadge(
                  label: customer.accountStatus.firestoreValue,
                  background: FigmaColors.tintBlue,
                  foreground: FigmaColors.navy,
                ),
              ],
              metaLines: [
                MemberProfileMetaLine(icon: Icons.calendar_today_outlined, text: 'Member since $memberSince'),
                MemberProfileMetaLine(icon: Icons.place_outlined, text: location),
                if (customer.email.isNotEmpty)
                  MemberProfileMetaLine(icon: Icons.email_outlined, text: customer.email),
              ],
              stats: [
                MemberProfileStat(
                  value: avg > 0 ? avg.toStringAsFixed(1) : '—',
                  label: 'Provider rating',
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFEAB308),
                ),
                MemberProfileStat(
                  value: '$completedBookings',
                  label: 'Completed',
                  icon: Icons.flag_outlined,
                  iconColor: FigmaColors.green,
                ),
                MemberProfileStat(
                  value: '${reviews.length}',
                  label: 'Provider reviews',
                  icon: Icons.rate_review_outlined,
                ),
              ],
            );

            final main = <Widget>[
              MemberProfileStatStrip(
                items: [
                  (icon: Icons.handshake_outlined, value: '$completedBookings', label: 'Completed'),
                  (icon: Icons.star_outline_rounded, value: avg > 0 ? avg.toStringAsFixed(1) : '—', label: 'Rating from providers'),
                  (icon: Icons.reviews_outlined, value: '${reviews.length}', label: 'Written reviews'),
                  (icon: Icons.event_note_outlined, value: '${bookings.length}', label: 'Total bookings'),
                ],
              ),
              MemberProfileOverviewSection(
                body: customer.bio?.trim().isNotEmpty == true
                    ? customer.bio!.trim()
                    : customer.address?.trim().isNotEmpty == true
                        ? 'Books local services in ${customer.address}. '
                            'Providers on NeighborHelp can see milestone history and feedback from past jobs.'
                        : 'Active NeighborHelp customer. Providers can review feedback from completed milestones before accepting work.',
              ),
              MemberProfileReviewsSection(
                reviews: reviews,
                averageRating: avg,
                emptyMessage:
                    'No provider feedback yet. Reviews appear after completed milestones when providers rate the customer.',
              ),
            ];

            Widget? rightRail;
            if (bookingForMessage != null) {
              rightRail = MemberProfileSectionCard(
                title: 'Contact',
                icon: Icons.chat_bubble_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Continue your conversation about this booking.',
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => MessagesHub.openConversation(
                        context,
                        appUser: viewer,
                        booking: bookingForMessage!,
                        asCustomer: false,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message customer'),
                    ),
                  ],
                ),
              );
            }

            return MemberProfileColumns(sidebar: sidebar, main: main, rightRail: rightRail);
          },
        );
      },
    );
  }
}
