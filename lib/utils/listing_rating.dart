import '../models/review.dart';
import '../models/service.dart';
import 'review_sentiment.dart';

/// Normalize titles so republished listings still match prior reviews.
String normalizeServiceTitle(String title) {
  return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Listing id plus any of the provider's listings with the same title.
Set<String> serviceIdsMatchingListing({
  required ServiceListing listing,
  List<ServiceListing> providerListings = const [],
}) {
  final norm = normalizeServiceTitle(listing.serviceTitle);
  final ids = <String>{listing.serviceId};
  for (final other in providerListings) {
    if (normalizeServiceTitle(other.serviceTitle) == norm) {
      ids.add(other.serviceId);
    }
  }
  return ids;
}

/// Service-scoped rating for a listing card, plus overall provider context.
class ServiceListingRating {
  const ServiceListingRating({
    required this.serviceRating,
    required this.serviceReviewCount,
    required this.overallRating,
    required this.overallReviewCount,
  });

  final double serviceRating;
  final int serviceReviewCount;
  final double overallRating;
  final int overallReviewCount;

  bool get hasServiceReviews => serviceReviewCount > 0 && serviceRating > 0;
  bool get hasOverallReviews => overallReviewCount > 0 && overallRating > 0;
}

ServiceListingRating computeServiceListingRating({
  required List<Review> reviews,
  required Set<String> serviceIds,
  double profileAverage = 0,
  int profileReviewCount = 0,
}) {
  final customerReviews = reviews.where((r) => r.isCustomerReview).toList();
  final forService = customerReviews.where((r) => serviceIds.contains(r.serviceId)).toList();

  final serviceAvg = forService.isEmpty
      ? 0.0
      : forService.fold<double>(0, (sum, r) => sum + r.rating) / forService.length;

  final overallAvg = effectiveProviderRating(
    profileAverage: profileAverage,
    reviews: customerReviews,
  );
  final overallCount = customerReviews.isNotEmpty ? customerReviews.length : profileReviewCount;

  return ServiceListingRating(
    serviceRating: serviceAvg,
    serviceReviewCount: forService.length,
    overallRating: overallAvg,
    overallReviewCount: overallCount,
  );
}
