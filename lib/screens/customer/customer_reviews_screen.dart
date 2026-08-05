import 'package:flutter/material.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../models/app_user.dart';
import '../../models/review.dart';
import '../../services/firestore_service.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/review_tile.dart';

class _CustomerReviewContext {
  const _CustomerReviewContext({
    required this.review,
    required this.providerName,
    required this.jobLabel,
    required this.providerLeftFeedback,
  });

  final Review review;
  final String providerName;
  final String jobLabel;
  final bool? providerLeftFeedback;
}

class CustomerReviewsScreen extends StatefulWidget {
  const CustomerReviewsScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<CustomerReviewsScreen> createState() => _CustomerReviewsScreenState();
}

class _CustomerReviewsScreenState extends State<CustomerReviewsScreen> {
  final _firestore = FirestoreService();
  Future<List<_CustomerReviewContext>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadReviewContexts();
  }

  Future<List<_CustomerReviewContext>> _loadReviewContexts() async {
    final all = await _firestore.reviewsByCustomer(widget.appUser.userId);
    final reviews = all.where((r) => r.isCustomerReview).toList();
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final providerNames = <String, String>{};
    final jobLabels = <String, String>{};
    final providerReplied = <String, bool>{};

    for (final review in reviews) {
      if (!providerNames.containsKey(review.providerId)) {
        final user = await _firestore.getUser(review.providerId);
        providerNames[review.providerId] = user?.fullName ?? 'Provider';
      }

      final bookingKey = review.bookingId;
      if (bookingKey.isNotEmpty && !jobLabels.containsKey(bookingKey)) {
        jobLabels[bookingKey] = await _jobLabelForReview(review);
      }

      if (bookingKey.isNotEmpty && !providerReplied.containsKey(bookingKey)) {
        final theirs = await _firestore.getReviewForBooking(bookingKey, reviewerRole: 'provider');
        providerReplied[bookingKey] = theirs != null;
      }
    }

    return reviews
        .map(
          (review) => _CustomerReviewContext(
            review: review,
            providerName: providerNames[review.providerId] ?? 'Provider',
            jobLabel: review.bookingId.isNotEmpty
                ? (jobLabels[review.bookingId] ?? 'Completed booking')
                : _jobLabelFromReviewOnly(review),
            providerLeftFeedback:
                review.bookingId.isNotEmpty ? (providerReplied[review.bookingId] ?? false) : null,
          ),
        )
        .toList();
  }

  Future<String> _jobLabelForReview(Review review) async {
    final booking = await _firestore.getBooking(review.bookingId);
    final serviceId = booking?.serviceId ?? review.serviceId;
    var title = 'Service';
    if (serviceId.isNotEmpty) {
      final service = await _firestore.getService(serviceId);
      title = service?.serviceTitle ?? title;
    }
    final milestone = review.milestoneNumber ?? booking?.milestoneNumber;
    if (milestone != null && milestone > 0) {
      title = '$title · Milestone $milestone';
    }
    return title;
  }

  String _jobLabelFromReviewOnly(Review review) {
    if (review.milestoneNumber != null && review.milestoneNumber! > 0) {
      return 'Milestone ${review.milestoneNumber}';
    }
    return 'Completed booking';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.gray50,
      body: SafeArea(
        child: AppTabBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: 'Ratings & reviews',
                subtitle: 'Reviews you have shared after completed bookings',
                onBack: () => Navigator.pop(context),
              ),
              FutureBuilder<List<_CustomerReviewContext>>(
                future: _loadFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: LoadingIndicator(message: 'Loading your reviews…'),
                    );
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const FigmaEmptyState(
                      icon: Icons.star_outline,
                      title: 'No reviews yet',
                      message: 'After a booking is completed, open booking details to leave a rating.',
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items) ...[
                        AppSurfaceCard(
                          child: ReviewTile(
                            review: item.review,
                            fromLabel: 'For ${item.providerName}',
                            jobLabel: item.jobLabel,
                            youLeftFeedback: item.providerLeftFeedback,
                            feedbackLeftMessage: 'Provider left feedback for you',
                            feedbackMissingMessage: 'Provider has not left feedback yet',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
