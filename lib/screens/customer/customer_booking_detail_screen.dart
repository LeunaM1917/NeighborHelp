import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../figma_ui/figma_colors.dart';
import '../../theme/role_theme.dart';
import '../../figma_ui/figma_layout.dart';
import '../../figma_ui/widgets/figma_status_chip.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/provider.dart';
import '../../models/review.dart';
import '../../models/service.dart';
import '../../services/firestore_service.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/app_scroll_chrome.dart';
import '../../widgets/loading_indicator.dart';
import '../admin/widgets/admin_services_widgets.dart' show serviceCategoryIcon;
import '../shared/messages_hub.dart';
import '../../utils/review_sentiment.dart';
import '../../widgets/customer_provider_profile_dialog.dart';
import '../../widgets/booking_cancellation_card.dart';
import '../../widgets/booking_user_report_card.dart';
import '../../widgets/contract_panel.dart';
import '../../widgets/milestone_feedback_details.dart';
import 'widgets/booking_review_section.dart';

class CustomerBookingDetailScreen extends StatelessWidget {
  const CustomerBookingDetailScreen({
    super.key,
    required this.appUser,
    required this.booking,
  });

  final AppUser appUser;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final dateFmt = DateFormat('EEEE, MMM d, yyyy • h:mm a');

    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: AppScrollChrome(
          child: SingleChildScrollView(
          child: FigmaWideContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: 'Booking details',
                    subtitle: 'Track status and service information',
                    onBack: () => Navigator.pop(context),
                  ),
                  FutureBuilder<ServiceListing?>(
                    future: firestore.getService(booking.serviceId),
                    builder: (context, serviceSnap) {
                      return StreamBuilder<AppUser?>(
                        stream: firestore.userStream(booking.providerId),
                        builder: (context, providerSnap) {
                          if (serviceSnap.connectionState == ConnectionState.waiting) {
                            return const LoadingIndicator(message: 'Loading…');
                          }
                          final service = serviceSnap.data;
                          final provider = providerSnap.data;

                          return StreamBuilder<Booking?>(
                            stream: firestore.bookingStream(booking.bookingId),
                            builder: (context, bookingSnap) {
                              final b = bookingSnap.data ?? booking;
                              return StreamBuilder<ServiceProviderProfile?>(
                                stream: firestore.providerProfileForUser(b.providerId),
                                builder: (context, profileSnap) {
                                  final profile = profileSnap.data;

                                  final mainChildren = <Widget>[
                                    _headerCard(context, service, dateFmt, b),
                                    const SizedBox(height: 20),
                                    BookingStatusTracker(
                                      status: b.status,
                                      pendingAt: b.createdAt.toDate(),
                                      acceptedAt: b.acceptedAt?.toDate(),
                                      inProgressAt: b.startedAt?.toDate(),
                                      completedAt: b.completedAt?.toDate(),
                                    ),
                                    const SizedBox(height: 20),
                                    AppSection(
                                      title: 'Service details',
                                      child: AppSurfaceCard(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _detail(Icons.place_outlined, 'Location', b.serviceLocation),
                                            if (b.notes != null && b.notes!.isNotEmpty)
                                              _detail(Icons.notes_outlined, 'Notes', b.notes!),
                                            if (b.totalFee != null)
                                              _detail(
                                                Icons.payments_outlined,
                                                'Estimated fee',
                                                b.pricingSummary != null
                                                    ? '₱${b.totalFee!.toStringAsFixed(0)} (${b.pricingSummary})'
                                                    : '₱${b.totalFee!.toStringAsFixed(0)}',
                                              ),
                                            if (b.isMilestoneComplete) ...[
                                              const Padding(
                                                padding: EdgeInsets.only(top: 6, bottom: 16),
                                                child: Divider(height: 1, color: FigmaColors.gray200),
                                              ),
                                              Text(
                                                'Milestone feedback',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: FigmaColors.gray800,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              MilestoneFeedbackDetails(
                                                booking: b,
                                                viewerRole: 'customer',
                                                customerName: appUser.fullName.isNotEmpty ? appUser.fullName : 'You',
                                                providerName: provider?.fullName ?? 'Provider',
                                                compact: true,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ContractPanel(
                                      appUser: appUser,
                                      booking: b,
                                      viewerRole: 'customer',
                                    ),
                                    const SizedBox(height: 20),
                                    BookingReviewSection(appUser: appUser, booking: b),
                                  ];

                                  final sideChildren = <Widget>[
                                    _bookingSummaryCard(context, service, dateFmt, b),
                                    const SizedBox(height: 20),
                                    _providerCard(context, firestore, provider, profile),
                                    if (b.canCustomerCancel ||
                                        (b.isCancelled &&
                                            (b.wasCancelledByCustomer || b.wasCancelledByProvider))) ...[
                                      const SizedBox(height: 20),
                                      BookingCancellationCard(
                                        appUser: appUser,
                                        booking: b,
                                        viewerRole: 'customer',
                                        onCancelled: () => Navigator.pop(context),
                                      ),
                                    ],
                                    if (!b.isPending) ...[
                                      const SizedBox(height: 20),
                                      BookingUserReportCard(
                                        appUser: appUser,
                                        booking: b,
                                        viewerRole: 'customer',
                                        reportedUserId: b.providerId,
                                        reportedRole: 'provider',
                                      ),
                                    ],
                                  ];

                                  return LayoutBuilder(
                                    builder: (context, c) {
                                      final wide = c.maxWidth >= 900;
                                      if (wide) {
                                        return Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: mainChildren,
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            SizedBox(
                                              width: 340,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: sideChildren,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ...mainChildren,
                                          const SizedBox(height: 20),
                                          ...sideChildren,
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, ServiceListing? service, DateFormat dateFmt, Booking b) {
    final rc = context.roleColors;
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: rc.tint, shape: BoxShape.circle),
                child: Icon(
                  service != null
                      ? serviceCategoryIcon(service.category, service.serviceTitle)
                      : Icons.home_repair_service_outlined,
                  color: rc.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service?.serviceTitle ?? 'Service',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.scheduledWindowLabel,
                      style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray600),
                    ),
                    if (b.milestoneNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        b.milestoneLabel,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray500),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FigmaStatusChip(status: b.status),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.place_outlined, b.serviceLocation),
              if (b.totalFee != null)
                _chip(Icons.payments_outlined, 'Estimated fee ₱${b.totalFee!.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FigmaColors.gray50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FigmaColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: FigmaColors.gray500),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray700)),
        ],
      ),
    );
  }

  Widget _bookingSummaryCard(BuildContext context, ServiceListing? service, DateFormat dateFmt, Booking b) {
    return AppSection(
      title: 'Booking summary',
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow('Service', service?.serviceTitle ?? 'Service'),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Date & time', b.scheduledWindowLabel),
            const Divider(height: 1, color: FigmaColors.gray100),
            _summaryRow('Location', b.serviceLocation),
            if (b.milestoneNumber != null) ...[
              const Divider(height: 1, color: FigmaColors.gray100),
              _summaryRow('Contract', b.milestoneLabel),
            ],
            if (b.totalFee != null) ...[
              const Divider(height: 1, color: FigmaColors.gray100),
              _summaryRow('Estimated fee', '₱${b.totalFee!.toStringAsFixed(0)}'),
            ],
            const Divider(height: 1, color: FigmaColors.gray100),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Text('Status', style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
                  const Spacer(),
                  FigmaStatusChip(status: b.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
            ),
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context, AppUser? provider, ServiceProviderProfile? profile) {
    showCustomerProviderProfileDialog(
      context,
      appUser: appUser,
      providerId: booking.providerId,
      providerUser: provider,
      providerProfile: profile,
    );
  }

  Widget _providerCard(
    BuildContext context,
    FirestoreService firestore,
    AppUser? provider,
    ServiceProviderProfile? profile,
  ) {
    final rc = context.roleColors;
    final verified = profile?.isVerifiedProvider ?? false;

    return AppSection(
      title: 'Service provider',
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: rc.tint,
                  backgroundImage: provider?.profilePhotoUrl != null
                      ? NetworkImage(provider!.profilePhotoUrl!)
                      : null,
                  child: provider?.profilePhotoUrl == null
                      ? Text(
                          (provider?.fullName.isNotEmpty == true ? provider!.fullName[0] : 'P').toUpperCase(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: rc.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider?.fullName ?? 'Provider',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (verified) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 15, color: FigmaColors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Verified provider',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.green),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      StreamBuilder<List<Review>>(
                        stream: firestore.reviewsForProviderStream(booking.providerId),
                        builder: (context, reviewSnap) {
                          final reviews = reviewSnap.data ?? const <Review>[];
                          final rating = effectiveProviderRating(
                            profileAverage: profile?.averageRating ?? 0,
                            reviews: reviews,
                          );
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFEAB308)),
                              const SizedBox(width: 4),
                              Text(
                                rating > 0 ? rating.toStringAsFixed(1) : 'New',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: FigmaColors.gray900),
                              ),
                              if (reviews.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${reviews.length} review${reviews.length == 1 ? '' : 's'})',
                                  style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _openProfile(context, provider, profile),
              style: OutlinedButton.styleFrom(
                foregroundColor: rc.primary,
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: rc.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View profile', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                MessagesHub.openConversation(
                  context,
                  appUser: appUser,
                  booking: booking,
                  asCustomer: true,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: FigmaColors.gray800,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: FigmaColors.gray200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text('Message provider', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: FigmaColors.gray500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: FigmaColors.gray500)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 14, color: FigmaColors.gray900, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
