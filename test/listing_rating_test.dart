import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/review.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/models/service_approval_status.dart';
import 'package:neighbor_help/utils/listing_rating.dart';

Review _review({
  required String serviceId,
  required int rating,
  String providerId = 'p1',
}) {
  return Review(
    reviewId: 'r-$serviceId-$rating',
    bookingId: 'b1',
    customerId: 'c1',
    providerId: providerId,
    serviceId: serviceId,
    rating: rating,
    createdAt: Timestamp.now(),
    reviewerRole: 'customer',
  );
}

ServiceListing _listing({
  required String id,
  required String title,
  String providerId = 'p1',
}) {
  return ServiceListing(
    serviceId: id,
    providerId: providerId,
    serviceTitle: title,
    category: 'Home Repair',
    description: '',
    estimatedPrice: 100,
    priceType: 'fixed',
    estimatedDuration: '1 hour',
    availability: const {},
    serviceImages: const [],
    isActive: true,
    approvalStatus: ServiceApprovalStatus.approved,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );
}

void main() {
  test('primary rating uses only matching service ids', () {
    final listing = _listing(id: 'door', title: 'Door Repair');
    final rating = computeServiceListingRating(
      reviews: [
        _review(serviceId: 'dog', rating: 5),
        _review(serviceId: 'dog', rating: 5),
        _review(serviceId: 'door', rating: 4),
      ],
      serviceIds: {listing.serviceId},
      profileAverage: 3.6,
      profileReviewCount: 3,
    );

    expect(rating.hasServiceReviews, isTrue);
    expect(rating.serviceRating, 4.0);
    expect(rating.serviceReviewCount, 1);
    expect(rating.overallRating, 14 / 3);
    expect(rating.overallReviewCount, 3);
  });

  test('no service reviews shows empty service rating but keeps overall', () {
    final rating = computeServiceListingRating(
      reviews: [
        _review(serviceId: 'dog', rating: 5),
        _review(serviceId: 'dog', rating: 5),
      ],
      serviceIds: {'door'},
      profileAverage: 3.6,
      profileReviewCount: 2,
    );

    expect(rating.hasServiceReviews, isFalse);
    expect(rating.serviceReviewCount, 0);
    expect(rating.overallRating, 5.0);
    expect(rating.overallReviewCount, 2);
  });

  test('same title listings share service reviews', () {
    final current = _listing(id: 'door-v2', title: 'Door Repair');
    final previous = _listing(id: 'door-v1', title: 'Door Repair');
    final ids = serviceIdsMatchingListing(
      listing: current,
      providerListings: [previous, current],
    );

    final rating = computeServiceListingRating(
      reviews: [
        _review(serviceId: 'door-v1', rating: 5),
        _review(serviceId: 'dog', rating: 4),
      ],
      serviceIds: ids,
    );

    expect(ids, containsAll(['door-v1', 'door-v2']));
    expect(rating.serviceRating, 5.0);
    expect(rating.serviceReviewCount, 1);
  });
}
