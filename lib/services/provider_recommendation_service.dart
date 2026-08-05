import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/provider.dart';
import '../models/service.dart';
import '../utils/geo_location.dart';
import '../utils/haversine.dart';
import '../utils/weighted_scoring.dart';

/// Default proximity filter / normalization radius for recommendation scoring.
const double kDefaultMaxSearchRadiusKm = 15;

/// Neutral proximity when the customer has no usable location (R/A/C still rank).
const double kNeutralProximityWhenNoOrigin = 0.5;

/// A verified provider with a computed recommendation score (RS).
class RankedProvider {
  const RankedProvider({
    required this.profile,
    required this.recommendationScore,
    required this.distanceKm,
    required this.rank,
    required this.isAvailable,
    required this.isNewProvider,
  });

  final ServiceProviderProfile profile;
  final double recommendationScore;

  /// Straight-line distance in km when origin was available; otherwise null.
  final double? distanceKm;
  final int rank;
  final bool isAvailable;

  /// True when the provider has no review history (cold-start rating prior).
  final bool isNewProvider;
}

/// Ranks verified providers with manuscript weights:
/// `RS = 0.40P + 0.30R + 0.20A + 0.10C`.
///
/// Rating uses Bayesian average; completion uses a neutral prior until enough
/// history; near-ties (within [kRecommendationScoreTieEpsilon]) are shuffled.
List<RankedProvider> rankProvidersByRecommendation({
  required List<ServiceProviderProfile> providers,
  GeoPoint? customerOrigin,
  double maxSearchRadiusKm = kDefaultMaxSearchRadiusKm,
  DateTime? now,
  Random? random,
}) {
  final at = now ?? DateTime.now();
  final origin = geoPointOrNull(customerOrigin);
  final hasOrigin = origin != null;

  final scored = <RankedProvider>[];

  for (final profile in providers) {
    if (!profile.isVerifiedProvider) continue;

    double? distanceKm;
    double proximityInputKm;

    if (hasOrigin) {
      final providerLoc = geoPointOrNull(profile.location);
      if (providerLoc == null || isDefaultSignupLocation(providerLoc)) {
        continue;
      }
      distanceKm = haversineDistanceKmFromGeoPoints(origin, providerLoc);
      if (distanceKm > maxSearchRadiusKm) continue;
      proximityInputKm = distanceKm;
    } else {
      // No customer GPS: skip proximity filter; use neutral P via synthetic distance.
      proximityInputKm = (1 - kNeutralProximityWhenNoOrigin) * maxSearchRadiusKm;
    }

    final available = profile.isAvailableNow(at);
    final isNew = isColdStartProvider(
      reviewCount: profile.reviewCount,
      averageRating: profile.averageRating,
    );
    // averageRating is maintained as Bayesian by Cloud Functions; scoring also
    // applies computeBayesianRatingOutOfFive for small-n damping / CF lag.
    final score = weightedProviderScore(
      distanceKm: proximityInputKm,
      maxSearchRadiusKm: maxSearchRadiusKm,
      bayesianRatingOutOfFive: profile.averageRating,
      isAvailable: available,
      completedBookings: profile.completedBookings,
      acceptedBookings: profile.acceptedBookings,
      reviewCount: profile.reviewCount,
    );

    scored.add(
      RankedProvider(
        profile: profile,
        recommendationScore: score,
        distanceKm: distanceKm,
        rank: 0,
        isAvailable: available,
        isNewProvider: isNew,
      ),
    );
  }

  scored.sort((a, b) => b.recommendationScore.compareTo(a.recommendationScore));

  final ordered = applyFairScoreTieBreak(scored, random: random);

  return [
    for (var i = 0; i < ordered.length; i++)
      RankedProvider(
        profile: ordered[i].profile,
        recommendationScore: ordered[i].recommendationScore,
        distanceKm: ordered[i].distanceKm,
        rank: i + 1,
        isAvailable: ordered[i].isAvailable,
        isNewProvider: ordered[i].isNewProvider,
      ),
  ];
}

/// Sort marketplace listings for one job title by the provider's RS
/// (same weights as Nearby — fairness per service / job title).
List<ServiceListing> sortListingsByProviderRecommendation({
  required List<ServiceListing> listings,
  required Map<String, ServiceProviderProfile?> profilesByProviderId,
  GeoPoint? customerOrigin,
  DateTime? now,
  Random? random,
}) {
  if (listings.length <= 1) return List<ServiceListing>.from(listings);

  final profiles = <ServiceProviderProfile>[];
  final seen = <String>{};
  for (final listing in listings) {
    final profile = profilesByProviderId[listing.providerId];
    if (profile == null) continue;
    final key = profile.providerId;
    if (seen.add(key)) profiles.add(profile);
  }

  final ranked = rankProvidersByRecommendation(
    providers: profiles,
    customerOrigin: customerOrigin,
    now: now,
    random: random,
  );

  final scoreById = <String, double>{};
  for (final r in ranked) {
    scoreById[r.profile.providerId] = r.recommendationScore;
    scoreById[r.profile.userId] = r.recommendationScore;
  }

  final sorted = List<ServiceListing>.from(listings);
  sorted.sort((a, b) {
    final sa = scoreById[a.providerId] ?? -1;
    final sb = scoreById[b.providerId] ?? -1;
    final byScore = sb.compareTo(sa);
    if (byScore != 0) return byScore;
    return a.serviceTitle.compareTo(b.serviceTitle);
  });
  return sorted;
}

/// Full RS breakdown for Admin / panel computation demos.
WeightedScoreBreakdown breakdownForProvider({
  required ServiceProviderProfile profile,
  GeoPoint? customerOrigin,
  double maxSearchRadiusKm = kDefaultMaxSearchRadiusKm,
  DateTime? now,
  double? ratingOverride,
  int? reviewCountOverride,
  bool? availableOverride,
  int? completedOverride,
  int? acceptedOverride,
}) {
  final at = now ?? DateTime.now();
  final origin = geoPointOrNull(customerOrigin);
  double distanceKm;
  if (origin != null) {
    final providerLoc = geoPointOrNull(profile.location);
    if (providerLoc == null || isDefaultSignupLocation(providerLoc)) {
      distanceKm = maxSearchRadiusKm * (1 - kNeutralProximityWhenNoOrigin);
    } else {
      distanceKm = haversineDistanceKmFromGeoPoints(origin, providerLoc);
    }
  } else {
    distanceKm = maxSearchRadiusKm * (1 - kNeutralProximityWhenNoOrigin);
  }

  return computeWeightedScoreBreakdown(
    distanceKm: distanceKm,
    maxSearchRadiusKm: maxSearchRadiusKm,
    bayesianRatingOutOfFive: ratingOverride ?? profile.averageRating,
    isAvailable: availableOverride ?? profile.isAvailableNow(at),
    completedBookings: completedOverride ?? profile.completedBookings,
    acceptedBookings: acceptedOverride ?? profile.acceptedBookings,
    reviewCount: reviewCountOverride ?? profile.reviewCount,
  );
}

/// Shuffles only providers whose RS values fall in the same ~1% band.
///
/// [sortedDescending] must already be sorted by [RankedProvider.recommendationScore]
/// descending. Overall band order (higher RS before lower RS) is preserved.
List<RankedProvider> applyFairScoreTieBreak(
  List<RankedProvider> sortedDescending, {
  Random? random,
  double epsilon = kRecommendationScoreTieEpsilon,
}) {
  if (sortedDescending.length <= 1) return sortedDescending;

  final rng = random ?? Random();
  final out = <RankedProvider>[];
  var i = 0;
  while (i < sortedDescending.length) {
    final bandScore = sortedDescending[i].recommendationScore;
    final band = <RankedProvider>[sortedDescending[i]];
    var j = i + 1;
    while (j < sortedDescending.length &&
        (bandScore - sortedDescending[j].recommendationScore) <= epsilon) {
      band.add(sortedDescending[j]);
      j++;
    }
    if (band.length > 1) {
      band.shuffle(rng);
    }
    out.addAll(band);
    i = j;
  }
  return out;
}
