import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../figma_ui/figma_colors.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../services/firestore_service.dart';
import '../../widgets/member_profile/member_profile_kit.dart';
import '../customer/customer_reviews_screen.dart';
import '../customer/customer_settings_screen.dart';
import '../customer/widgets/customer_verification_widgets.dart';
import '../shared/help_support_popover.dart';

/// Counts for customer profile stats (matches Bookings tab buckets).
({int completed, int upcoming}) customerProfileBookingCounts(List<Booking> bookings) {
  var completed = 0;
  var upcoming = 0;
  for (final b in bookings) {
    final s = b.statusNormalized;
    if (s == 'cancelled' || s == 'canceled') continue;
    if (b.isMilestoneComplete) {
      completed++;
    } else {
      upcoming++;
    }
  }
  return (completed: completed, upcoming: upcoming);
}

/// Self profile layout for the customer tab.
class SelfCustomerProfileBody extends StatefulWidget {
  const SelfCustomerProfileBody({
    super.key,
    required this.appUser,
    this.onBookingsTap,
  });

  final AppUser appUser;
  final VoidCallback? onBookingsTap;

  @override
  State<SelfCustomerProfileBody> createState() => _SelfCustomerProfileBodyState();
}

class _SelfCustomerProfileBodyState extends State<SelfCustomerProfileBody> {
  final _firestore = FirestoreService();
  Future<({int given, int received})>? _reviewCountsFuture;

  @override
  void initState() {
    super.initState();
    _reviewCountsFuture = _fetchReviewCounts();
  }

  Future<({int given, int received})> _fetchReviewCounts() async {
    final results = await Future.wait([
      _firestore.reviewsByCustomer(widget.appUser.userId),
      _firestore.reviewsForCustomer(widget.appUser.userId),
    ]);
    final given = results[0].where((r) => r.isCustomerReview).length;
    final received = results[1].length;
    return (given: given, received: received);
  }

  void _refreshReviews() {
    setState(() => _reviewCountsFuture = _fetchReviewCounts());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _firestore.userStream(widget.appUser.userId),
      builder: (context, userSnap) {
        final user = userSnap.data ?? widget.appUser;
        return StreamBuilder<List<Booking>>(
          stream: _firestore.bookingsForUser(user.userId, asCustomer: true),
          builder: (context, bookingSnap) {
            final bookings = bookingSnap.data ?? const <Booking>[];
            final bookingCounts = customerProfileBookingCounts(bookings);

            return FutureBuilder<({int given, int received})>(
              future: _reviewCountsFuture,
              builder: (context, reviewSnap) {
                final reviewCounts = reviewSnap.data;
                final reviewsGiven = reviewCounts?.given ?? 0;
                final reviewsReceived = reviewCounts?.received ?? 0;
                return _buildContent(
                  context,
                  user: user,
                  completed: bookingCounts.completed,
                  upcoming: bookingCounts.upcoming,
                  reviewsGiven: reviewsGiven,
                  reviewsReceived: reviewsReceived,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required AppUser user,
    required int completed,
    required int upcoming,
    required int reviewsGiven,
    required int reviewsReceived,
  }) {
    final memberSince = memberProfileMemberSince(user.createdAt.toDate());
    final verified = user.isVerifiedCustomer;

    final sidebar = MemberProfileSidebar(
      name: user.fullName.isNotEmpty ? user.fullName : 'Customer',
      roleLabel: 'Your profile',
      photoUrl: user.profilePhotoUrl,
      onEditPhoto: () => _openSettings(context, user),
      badges: [
        if (verified)
          const MemberProfileBadge(
            label: 'Verified',
            icon: Icons.verified,
            background: FigmaColors.tintGreen,
            foreground: FigmaColors.green,
          ),
        MemberProfileBadge(
          label: user.accountStatus.firestoreValue,
          background: FigmaColors.tintGreen,
          foreground: FigmaColors.green,
        ),
      ],
      metaLines: [
        MemberProfileMetaLine(icon: Icons.calendar_today_outlined, text: 'Member since $memberSince'),
        MemberProfileMetaLine(icon: Icons.place_outlined, text: memberProfileLocation(user)),
      ],
      stats: [
        MemberProfileStat(
          value: '$completed',
          label: 'Completed',
          icon: Icons.check_circle_outline,
          iconColor: FigmaColors.green,
        ),
        MemberProfileStat(
          value: '$upcoming',
          label: 'Upcoming',
          icon: Icons.event_outlined,
        ),
        MemberProfileStat(
          value: '$reviewsGiven',
          label: 'Reviews given',
          icon: Icons.star_outline,
        ),
        MemberProfileStat(
          value: '$reviewsReceived',
          label: 'Reviews received',
          icon: Icons.star_half_outlined,
          iconColor: const Color(0xFFEAB308),
        ),
      ],
      footer: Text(
        'Supporting local providers in your community.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600, fontStyle: FontStyle.italic, height: 1.4),
      ),
    );

    final main = <Widget>[
      MemberProfileOverviewSection(
        body: user.bio?.trim().isNotEmpty == true
            ? user.bio!.trim()
            : 'Tell providers a little about yourself — add a bio in profile settings.',
        onEdit: () => _openSettings(context, user),
        accountUser: user,
      ),
      MemberProfileSettingsList(
        tiles: [
          MemberProfileSettingsTile(
            icon: Icons.person_outline,
            title: 'Edit profile',
            subtitle: 'Name, photo, bio, contact, address',
            onTap: () => _openSettings(context, user),
          ),
          MemberProfileSettingsTile(
            icon: Icons.star_outline,
            title: 'Ratings & reviews',
            subtitle: 'Reviews you left for providers',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => CustomerReviewsScreen(appUser: user)),
            ),
          ),
          MemberProfileSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & support',
            subtitle: 'Contact our team',
            onTap: () => HelpSupportPopover.show(context, roleLabel: 'Customer'),
          ),
        ],
      ),
    ];

    final rightRail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MemberProfileSectionCard(
          title: 'Quick overview',
          icon: Icons.insights_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MiniStat(label: 'Completed', value: '$completed', color: FigmaColors.tintGreen, fg: FigmaColors.green),
              const SizedBox(height: 10),
              _MiniStat(label: 'Upcoming', value: '$upcoming', color: FigmaColors.orange50, fg: FigmaColors.orange600),
              const SizedBox(height: 10),
              _MiniStat(label: 'Reviews given', value: '$reviewsGiven', color: FigmaColors.tintBlue, fg: FigmaColors.navy),
              const SizedBox(height: 10),
              _MiniStat(
                label: 'Reviews received',
                value: '$reviewsReceived',
                color: FigmaColors.orange50,
                fg: FigmaColors.orange600,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: widget.onBookingsTap,
                child: const Text('View all bookings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CustomerVerificationTrustCard(user: user),
      ],
    );

    return MemberProfileColumns(sidebar: sidebar, main: main, rightRail: rightRail);
  }

  Future<void> _openSettings(BuildContext context, AppUser user) async {
    final saved = await CustomerSettingsScreen.open(context, appUser: user);
    if (saved == true && mounted) _refreshReviews();
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color, required this.fg});

  final String label;
  final String value;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray700))),
        ],
      ),
    );
  }
}
