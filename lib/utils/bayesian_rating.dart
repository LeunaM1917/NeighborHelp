/// Bayesian average for provider ratings.
///
/// [confidenceWeight] C (spec default: 10)
/// [globalMean] m — mean rating across all providers (1–5 scale)
/// [ratings] individual star ratings (1–5)
double bayesianAverageFromRatings({
  required double confidenceWeight,
  required double globalMean,
  required List<int> ratings,
}) {
  final n = ratings.length;
  final sum = ratings.fold<double>(0, (a, b) => a + b);
  return bayesianAverageFromSum(
    confidenceWeight: confidenceWeight,
    globalMean: globalMean,
    sumRatings: sum,
    reviewCount: n,
  );
}

/// Same formula using pre-aggregated sum and count.
double bayesianAverageFromSum({
  required double confidenceWeight,
  required double globalMean,
  required double sumRatings,
  required int reviewCount,
}) {
  final c = confidenceWeight;
  final n = reviewCount;
  return (c * globalMean + sumRatings) / (c + n);
}
