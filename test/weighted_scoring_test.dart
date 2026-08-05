import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/provider_weekly_availability.dart';
import 'package:neighbor_help/services/provider_recommendation_service.dart';
import 'package:neighbor_help/utils/weighted_scoring.dart';

void main() {
  group('computeBayesianRatingOutOfFive', () {
    test('matches Cloud Functions formula (C=10, m=3.5)', () {
      // Two 5-star reviews: (10*3.5 + 2*5) / (10+2) = 45/12 = 3.75
      final bayes = computeBayesianRatingOutOfFive(
        observedAverageOutOfFive: 5,
        reviewCount: 2,
      );
      expect(bayes, closeTo(3.75, 1e-9));
    });

    test('few five-star reviews stay below experienced high rating', () {
      final fewFives = computeBayesianRatingOutOfFive(
        observedAverageOutOfFive: 5,
        reviewCount: 2,
      );
      final experienced = computeBayesianRatingOutOfFive(
        observedAverageOutOfFive: 4.6,
        reviewCount: 40,
      );
      expect(fewFives, lessThan(experienced));
    });

    test('zero reviews returns prior 3.5', () {
      expect(
        computeBayesianRatingOutOfFive(observedAverageOutOfFive: 0, reviewCount: 0),
        kBayesianPriorOutOfFive,
      );
    });
  });

  group('weightedProviderScore', () {
    test('is within [0,1] for typical inputs', () {
      final s = weightedProviderScore(
        distanceKm: 2,
        maxSearchRadiusKm: 10,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 8,
        acceptedBookings: 10,
        reviewCount: 5,
      );
      expect(s, greaterThanOrEqualTo(0));
      expect(s, lessThanOrEqualTo(1.0001));
    });

    test('keeps manuscript weights 0.40 / 0.30 / 0.20 / 0.10', () {
      // P = 1; R = bayesian(4, n=1000)/5; A = 1; C = 0.8
      const n = 1000;
      final s = weightedProviderScore(
        distanceKm: 0,
        maxSearchRadiusKm: 10,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 8,
        acceptedBookings: 10,
        reviewCount: n,
      );
      final bayes = computeBayesianRatingOutOfFive(
        observedAverageOutOfFive: 4,
        reviewCount: n,
      );
      final r = bayes / 5;
      expect(s, closeTo(0.40 * 1 + 0.30 * r + 0.20 * 1 + 0.10 * 0.8, 1e-9));
    });

    test('uses Bayesian rating in RS (not raw 5.0 for two reviews)', () {
      final withTwoFives = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 5,
        isAvailable: true,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 2,
      );
      final withRawFiveAssumption = 0.40 * (1 - 5 / 15) +
          0.30 * 1.0 +
          0.20 * 1.0 +
          0.10 * 1.0;
      expect(withTwoFives, lessThan(withRawFiveAssumption));
    });

    test('higher proximity raises score', () {
      final near = weightedProviderScore(
        distanceKm: 1,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 20,
      );
      final far = weightedProviderScore(
        distanceKm: 12,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 20,
      );
      expect(near, greaterThan(far));
    });

    test('higher Bayesian rating raises score', () {
      final high = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 5,
        isAvailable: true,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 40,
      );
      final low = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 2,
        isAvailable: true,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 40,
      );
      expect(high, greaterThan(low));
    });

    test('availability raises score', () {
      final open = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 20,
      );
      final closed = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 4,
        isAvailable: false,
        completedBookings: 5,
        acceptedBookings: 5,
        reviewCount: 20,
      );
      expect(open, greaterThan(closed));
    });

    test('higher completion rate raises score after min history', () {
      final reliable = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 9,
        acceptedBookings: 10,
        reviewCount: 20,
      );
      final weak = weightedProviderScore(
        distanceKm: 5,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 4,
        isAvailable: true,
        completedBookings: 2,
        acceptedBookings: 10,
        reviewCount: 20,
      );
      expect(reliable, greaterThan(weak));
    });

    test('cold-start uses Bayesian prior 3.5 and completion prior 0.5', () {
      final s = weightedProviderScore(
        distanceKm: 0,
        maxSearchRadiusKm: 15,
        bayesianRatingOutOfFive: 0,
        isAvailable: true,
        completedBookings: 0,
        acceptedBookings: 0,
        reviewCount: 0,
      );
      expect(s, closeTo(0.40 * 1 + 0.30 * 0.7 + 0.20 * 1 + 0.10 * 0.5, 1e-9));
    });

    test('completion stays neutral until minimum accepted bookings', () {
      final prior = normalizedCompletionScore(completedBookings: 2, acceptedBookings: 2);
      final live = normalizedCompletionScore(completedBookings: 9, acceptedBookings: 10);
      expect(prior, closeTo(kColdStartCompletionPrior, 1e-9));
      expect(live, closeTo(0.9, 1e-9));
      expect(
        normalizedCompletionScore(completedBookings: 0, acceptedBookings: 0),
        kColdStartCompletionPrior,
      );
    });
  });

  group('applyFairScoreTieBreak', () {
    RankedProvider rp(String id, double score) => RankedProvider(
          profile: ServiceProviderProfile(
            providerId: id,
            userId: id,
            bio: '',
            serviceArea: '',
            location: const GeoPoint(7.3, 125.6),
            serviceRadiusKm: 5,
            averageRating: 4,
            completedBookings: 0,
            acceptedBookings: 0,
            isVerified: true,
            verificationStatus: 'approved',
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          ),
          recommendationScore: score,
          distanceKm: 1,
          rank: 0,
          isAvailable: true,
          isNewProvider: false,
        );

    test('shuffles only within 1% score band', () {
      final sorted = [
        rp('a', 0.80),
        rp('b', 0.795), // within 0.01 of 0.80
        rp('c', 0.70), // separate band
      ];
      final out = applyFairScoreTieBreak(sorted, random: Random(1));
      expect(out.map((e) => e.profile.providerId).toSet(), {'a', 'b', 'c'});
      // Lower band stays after higher band.
      expect(out.last.profile.providerId, 'c');
      expect(out.take(2).map((e) => e.profile.providerId).toSet(), {'a', 'b'});
    });

    test('different seeds can reorder near-ties', () {
      final sorted = [rp('a', 0.50), rp('b', 0.50), rp('c', 0.50)];
      final orders = <String>{};
      for (var seed = 0; seed < 30; seed++) {
        final out = applyFairScoreTieBreak(sorted, random: Random(seed));
        orders.add(out.map((e) => e.profile.providerId).join(','));
      }
      expect(orders.length, greaterThan(1));
    });
  });

  group('ProviderWeeklyAvailability.isAvailableNow', () {
    test('true during enabled weekday hours', () {
      final schedule = ProviderWeeklyAvailability.defaults;
      expect(schedule.isAvailableNow(DateTime(2026, 8, 3, 10, 0)), isTrue);
    });

    test('false outside hours', () {
      final schedule = ProviderWeeklyAvailability.defaults;
      expect(schedule.isAvailableNow(DateTime(2026, 8, 3, 22, 0)), isFalse);
    });
  });

  group('rankProvidersByRecommendation', () {
    final now = DateTime(2026, 8, 3, 10, 0);
    final origin = const GeoPoint(7.3081, 125.6842);

    ServiceProviderProfile provider({
      required String id,
      required double lat,
      required double lng,
      required double rating,
      required bool verified,
      int completed = 8,
      int accepted = 10,
      int reviewCount = 5,
    }) {
      return ServiceProviderProfile(
        providerId: id,
        userId: id,
        bio: '',
        serviceArea: 'Panabo',
        location: GeoPoint(lat, lng),
        serviceRadiusKm: 10,
        averageRating: rating,
        completedBookings: completed,
        acceptedBookings: accepted,
        reviewCount: reviewCount,
        isVerified: verified,
        verificationStatus: verified ? 'approved' : 'pending',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
    }

    test('excludes unverified providers', () {
      final ranked = rankProvidersByRecommendation(
        providers: [
          provider(id: 'v', lat: 7.31, lng: 125.685, rating: 4.5, verified: true),
          provider(id: 'u', lat: 7.309, lng: 125.684, rating: 5.0, verified: false),
        ],
        customerOrigin: origin,
        now: now,
        random: Random(0),
      );
      expect(ranked.map((r) => r.profile.providerId), ['v']);
    });

    test('sorts by recommendation score descending, not nearest alone', () {
      final nearWeak = provider(
        id: 'near',
        lat: 7.309,
        lng: 125.685,
        rating: 2.0,
        verified: true,
        completed: 1,
        accepted: 10,
        reviewCount: 20,
      );
      final fartherStrong = provider(
        id: 'strong',
        lat: 7.35,
        lng: 125.70,
        rating: 5.0,
        verified: true,
        completed: 10,
        accepted: 10,
        reviewCount: 40,
      );

      final ranked = rankProvidersByRecommendation(
        providers: [nearWeak, fartherStrong],
        customerOrigin: origin,
        maxSearchRadiusKm: 15,
        now: now,
        random: Random(0),
      );

      expect(ranked.first.profile.providerId, 'strong');
      expect(
        ranked.first.recommendationScore,
        greaterThan(ranked.last.recommendationScore + kRecommendationScoreTieEpsilon),
      );
    });

    test('new provider is not zero-punished', () {
      final ranked = rankProvidersByRecommendation(
        providers: [
          provider(
            id: 'new',
            lat: 7.31,
            lng: 125.685,
            rating: 0,
            verified: true,
            completed: 0,
            accepted: 0,
            reviewCount: 0,
          ),
        ],
        customerOrigin: origin,
        now: now,
        random: Random(0),
      );
      expect(ranked.single.isNewProvider, isTrue);
      expect(ranked.single.recommendationScore, greaterThan(0.4));
    });

    test('provider with two raw five-stars does not beat experienced on rating alone', () {
      final twoFives = provider(
        id: 'two',
        lat: 7.31,
        lng: 125.685,
        rating: 5.0,
        verified: true,
        completed: 5,
        accepted: 5,
        reviewCount: 2,
      );
      final experienced = provider(
        id: 'exp',
        lat: 7.31,
        lng: 125.685,
        rating: 4.6,
        verified: true,
        completed: 5,
        accepted: 5,
        reviewCount: 40,
      );

      final ranked = rankProvidersByRecommendation(
        providers: [twoFives, experienced],
        customerOrigin: origin,
        now: now,
        random: Random(0),
      );
      expect(ranked.first.profile.providerId, 'exp');
    });
  });
}
