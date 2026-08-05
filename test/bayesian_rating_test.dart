import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/utils/bayesian_rating.dart';

void main() {
  test('Bayesian average pulls toward global mean when few reviews', () {
    final v = bayesianAverageFromRatings(
      confidenceWeight: 10,
      globalMean: 3.5,
      ratings: const [5],
    );
    expect(v, lessThan(5));
    expect(v, greaterThan(3.5));
  });

  test('Bayesian average matches closed form for sum helper', () {
    final v = bayesianAverageFromSum(
      confidenceWeight: 10,
      globalMean: 3.5,
      sumRatings: 10,
      reviewCount: 2,
    );
    expect(v, closeTo((10 * 3.5 + 10) / 12, 1e-9));
  });
}
