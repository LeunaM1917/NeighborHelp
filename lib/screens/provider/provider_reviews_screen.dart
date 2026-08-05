import 'package:flutter/material.dart';

import '../../figma_ui/figma_colors.dart';
import '../../figma_ui/widgets/figma_empty_state.dart';
import '../../models/app_user.dart';
import '../../models/review.dart';
import '../../services/firestore_service.dart';
import '../../theme/provider_theme.dart';
import '../../ui/app_ui_kit.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/review_tile.dart';

class _ProviderReviewContext {
  const _ProviderReviewContext({
    required this.review,
    required this.customerName,
    required this.jobLabel,
    required this.youLeftFeedback,
  });

  final Review review;
  final String customerName;
  final String jobLabel;
  final bool? youLeftFeedback;
}

class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  final _firestore = FirestoreService();
  Future<List<_ProviderReviewContext>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadReviewContexts();
  }

  Future<List<_ProviderReviewContext>> _loadReviewContexts() async {
    final reviews = await _firestore.reviewsForProvider(widget.appUser.userId);
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final customerNames = <String, String>{};
    final jobLabels = <String, String>{};
    final providerReplied = <String, bool>{};

    for (final review in reviews) {
      if (!customerNames.containsKey(review.customerId)) {
        final user = await _firestore.getUser(review.customerId);
        customerNames[review.customerId] = user?.fullName ?? 'Customer';
      }

      final bookingKey = review.bookingId;
      if (bookingKey.isNotEmpty && !jobLabels.containsKey(bookingKey)) {
        jobLabels[bookingKey] = await _jobLabelForReview(review);
      }

      if (bookingKey.isNotEmpty && !providerReplied.containsKey(bookingKey)) {
        final yours = await _firestore.getReviewForBooking(bookingKey, reviewerRole: 'provider');
        providerReplied[bookingKey] = yours != null;
      }
    }

    return reviews
        .map(
          (review) => _ProviderReviewContext(
            review: review,
            customerName: customerNames[review.customerId] ?? 'Customer',
            jobLabel: review.bookingId.isNotEmpty
                ? (jobLabels[review.bookingId] ?? 'Completed booking')
                : _jobLabelFromReviewOnly(review),
            youLeftFeedback: review.bookingId.isNotEmpty ? (providerReplied[review.bookingId] ?? false) : null,
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
    return providerThemed(
      Scaffold(
        backgroundColor: FigmaColors.gray50,
        body: SafeArea(
          child: AppTabBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: 'Reviews & ratings',
                  subtitle: 'Feedback from customers who completed bookings with you',
                  onBack: () => Navigator.pop(context),
                ),
                FutureBuilder<List<_ProviderReviewContext>>(
                  future: _loadFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: LoadingIndicator(message: 'Loading reviews…'),
                      );
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return const FigmaEmptyState(
                        icon: Icons.star_outline,
                        title: 'No reviews yet',
                        message: 'Complete jobs and encourage customers to leave a rating.',
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items) ...[
                          AppSurfaceCard(
                            child: ReviewTile(
                              review: item.review,
                              fromLabel: 'From ${item.customerName}',
                              jobLabel: item.jobLabel,
                              youLeftFeedback: item.youLeftFeedback,
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
      ),
    );
  }
}
