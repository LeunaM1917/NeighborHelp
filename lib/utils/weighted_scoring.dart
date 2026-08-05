/// Bayesian confidence weight (same `C` as Cloud Functions `onReviewCreated`).
const int kBayesianConfidenceWeight = 10;

/// Bayesian prior rating out of 5 (same default `m` as Cloud Functions).
const double kBayesianPriorOutOfFive = 3.5;

/// Alias kept for older call sites / tests.
const double kColdStartRatingPriorOutOfFive = kBayesianPriorOutOfFive;

/// Neutral completion score until minimum booking history exists.
const double kColdStartCompletionPrior = 0.5;

/// Minimum accepted bookings before using actual completion rate in RS.
const int kMinAcceptedBookingsForCompletionRate = 3;

/// RS scores within this absolute delta (1% on the 0–1 scale) are tie-broken fairly.
const double kRecommendationScoreTieEpsilon = 0.01;

/// Whether the provider has no review history (UI "New" cue / cold-start rating).
bool isColdStartProvider({required int reviewCount, required double averageRating}) {
  return reviewCount <= 0 || averageRating <= 0;
}

/// Bayesian average out of 5.
///
/// Formula (matches Cloud Functions): `(C × m + n × R) / (C + n)`
/// where C = [kBayesianConfidenceWeight], m = [kBayesianPriorOutOfFive],
/// R = observed mean, n = review count.
///
/// Firestore `averageRating` is written by Cloud Functions as a Bayesian value
/// after reviews; treating it as R here keeps the same damping for small n and
/// also protects against not-yet-updated raw means (e.g. a lone 5.0).
double computeBayesianRatingOutOfFive({
  required double observedAverageOutOfFive,
  required int reviewCount,
  double priorOutOfFive = kBayesianPriorOutOfFive,
  int confidenceWeight = kBayesianConfidenceWeight,
}) {
  if (reviewCount <= 0 || observedAverageOutOfFive <= 0) {
    return priorOutOfFive;
  }
  final bayes = (confidenceWeight * priorOutOfFive +
          reviewCount * observedAverageOutOfFive) /
      (confidenceWeight + reviewCount);
  return bayes.clamp(0.0, 5.0);
}

/// Normalized rating feature R in [0, 1] from Bayesian average.
double normalizedRatingScore({
  required double bayesianRatingOutOfFive,
  required int reviewCount,
}) {
  final bayes = computeBayesianRatingOutOfFive(
    observedAverageOutOfFive: bayesianRatingOutOfFive,
    reviewCount: reviewCount,
  );
  return (bayes / 5.0).clamp(0.0, 1.0);
}

/// Normalized completion feature C in [0, 1].
///
/// Uses neutral prior until [kMinAcceptedBookingsForCompletionRate] accepted
/// bookings exist, then `completed / accepted`.
double normalizedCompletionScore({
  required int completedBookings,
  required int acceptedBookings,
}) {
  if (acceptedBookings < kMinAcceptedBookingsForCompletionRate) {
    return kColdStartCompletionPrior.clamp(0.0, 1.0);
  }
  return (completedBookings / acceptedBookings).clamp(0.0, 1.0);
}

/// Feature breakdown for panel / Admin “show the computation” demos.
class WeightedScoreBreakdown {
  const WeightedScoreBreakdown({
    required this.proximity,
    required this.rating,
    required this.availability,
    required this.completion,
    required this.recommendationScore,
    required this.distanceKm,
    required this.bayesianRatingOutOfFive,
    required this.isAvailable,
    required this.completionRateDisplay,
  });

  final double proximity;
  final double rating;
  final double availability;
  final double completion;
  final double recommendationScore;
  final double distanceKm;
  final double bayesianRatingOutOfFive;
  final bool isAvailable;

  /// completed/accepted when history exists; otherwise cold-start prior.
  final double completionRateDisplay;

  int get scorePercent => (recommendationScore * 100).round();
}

/// Manuscript formula (unchanged weights):
/// `RS = 0.40×P + 0.30×R + 0.20×A + 0.10×C`
WeightedScoreBreakdown computeWeightedScoreBreakdown({
  required double distanceKm,
  required double maxSearchRadiusKm,
  required double bayesianRatingOutOfFive,
  required bool isAvailable,
  required int completedBookings,
  required int acceptedBookings,
  int reviewCount = 0,
}) {
  final proximity = maxSearchRadiusKm <= 0
      ? 0.0
      : (1 - (distanceKm / maxSearchRadiusKm)).clamp(0.0, 1.0);
  final rating = normalizedRatingScore(
    bayesianRatingOutOfFive: bayesianRatingOutOfFive,
    reviewCount: reviewCount,
  );
  final availability = isAvailable ? 1.0 : 0.0;
  final completion = normalizedCompletionScore(
    completedBookings: completedBookings,
    acceptedBookings: acceptedBookings,
  );
  final rs = 0.40 * proximity + 0.30 * rating + 0.20 * availability + 0.10 * completion;
  final completionDisplay = acceptedBookings < kMinAcceptedBookingsForCompletionRate
      ? kColdStartCompletionPrior
      : (completedBookings / acceptedBookings).clamp(0.0, 1.0);

  return WeightedScoreBreakdown(
    proximity: proximity,
    rating: rating,
    availability: availability,
    completion: completion,
    recommendationScore: rs,
    distanceKm: distanceKm,
    bayesianRatingOutOfFive: computeBayesianRatingOutOfFive(
      observedAverageOutOfFive: bayesianRatingOutOfFive,
      reviewCount: reviewCount,
    ),
    isAvailable: isAvailable,
    completionRateDisplay: completionDisplay,
  );
}

/// Weighted provider ranking score in range roughly [0, 1].
double weightedProviderScore({
  required double distanceKm,
  required double maxSearchRadiusKm,
  required double bayesianRatingOutOfFive,
  required bool isAvailable,
  required int completedBookings,
  required int acceptedBookings,
  int reviewCount = 0,
}) {
  return computeWeightedScoreBreakdown(
    distanceKm: distanceKm,
    maxSearchRadiusKm: maxSearchRadiusKm,
    bayesianRatingOutOfFive: bayesianRatingOutOfFive,
    isAvailable: isAvailable,
    completedBookings: completedBookings,
    acceptedBookings: acceptedBookings,
    reviewCount: reviewCount,
  ).recommendationScore;
}
