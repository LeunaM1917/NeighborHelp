import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking.dart';
import 'identity_verification.dart';
import 'provider.dart';
import 'review.dart';
import 'service.dart';
import '../utils/report_analytics.dart';

enum AdminReportType {
  transactions('Service Transactions', 'bookings'),
  providers('Provider Performance', 'serviceProviders'),
  verification('Verification Status', 'users'),
  feedback('User Feedback/Sentiment Analysis', 'reviews');

  const AdminReportType(this.label, this.collection);
  final String label;
  final String collection;
}

/// Deliberate allow-list: no ID images, session URLs, biometric results, contact
/// details, document numbers, or raw verification responses enter reports.
class ReportVerification {
  const ReportVerification(
    this.id,
    this.role,
    this.status,
    this.at,
    this.dateBasis,
  );
  factory ReportVerification.fromMap(String id, Map<String, dynamic> data) {
    final identity = IdentityVerification.fromMap(data);
    final status = identity.isVerifiedOnPlatform
        ? 'Approved'
        : identity.isDeclined
        ? 'Rejected'
        : identity.hasStarted
        ? 'Pending'
        : 'Not started';
    final basis = data['verificationUpdatedAt'] is Timestamp
        ? 'verificationUpdatedAt'
        : data['verificationReviewedAt'] is Timestamp
        ? 'verificationReviewedAt'
        : 'createdAt';
    return ReportVerification(
      id,
      data['role']?.toString() ?? 'Provider',
      status,
      data[basis] is Timestamp ? (data[basis] as Timestamp).toDate() : null,
      basis,
    );
  }
  final String id, role, status, dateBasis;
  final DateTime? at;
}

class AdminReportData {
  AdminReportData({
    required this.period,
    required this.loadedAt,
    required this.bookings,
    required this.reviews,
    required this.services,
    required this.providers,
    required this.verifications,
    this.missingDates = 0,
  });
  final ReportPeriod period;
  final DateTime loadedAt;
  final List<Booking> bookings;
  final List<Review> reviews;
  final Map<String, ServiceListing> services;
  final List<ServiceProviderProfile> providers;
  final List<ReportVerification> verifications;
  final int missingDates;

  String category(String serviceId) {
    final value = services[serviceId]?.category.trim() ?? '';
    return value.isEmpty ? 'Other' : value;
  }
}

class AdminReportFilter {
  const AdminReportFilter({this.category, this.provider, this.status});
  final String? category, provider, status;
}

/// One immutable result is used by preview and all three export formats.
class AdminReportResult {
  AdminReportResult({
    required this.type,
    required this.period,
    required this.loadedAt,
    required Map<String, Object?> filters,
    required Map<String, Object?> summary,
    required List<Map<String, Object?>> rows,
  }) : filters = Map.unmodifiable(filters),
       summary = Map.unmodifiable(summary),
       rows = List.unmodifiable(
         rows.map((row) => Map<String, Object?>.unmodifiable(row)),
       );
  final AdminReportType type;
  final ReportPeriod period;
  final DateTime loadedAt;
  final Map<String, Object?> filters, summary;
  final List<Map<String, Object?>> rows;
  Map<String, Object?> toJson() => {
    'report': type.label,
    'timezone': 'Asia/Manila',
    'startInclusive': reportTimestampText(period.start),
    'endExclusive': reportTimestampText(period.endExclusive),
    'snapshotAt': reportTimestampText(loadedAt),
    'filters': filters,
    'summary': summary,
    'records': rows,
  };
}

class AdminReportAnalytics {
  AdminReportAnalytics(this.data, this.filter) {
    bookings = {
      for (final b in data.bookings)
        if (data.period.contains(b.createdAt.toDate()) &&
            matches(b.serviceId, b.providerId) &&
            (filter.status == null ||
                b.status.toLowerCase() == filter.status!.toLowerCase()))
          b.bookingId: b,
    }.values.toList();
    reviews = {
      for (final r in data.reviews)
        if (r.isCustomerReview &&
            data.period.contains(r.createdAt.toDate()) &&
            matches(r.serviceId, r.providerId) &&
            (filter.status == null || sentiment(r) == filter.status))
          r.reviewId: r,
    }.values.toList();
  }
  final AdminReportData data;
  final AdminReportFilter filter;
  late final List<Booking> bookings;
  late final List<Review> reviews;
  bool matches(String service, String provider) =>
      (filter.category == null || data.category(service) == filter.category) &&
      (filter.provider == null || provider == filter.provider);
  static String sentiment(Review review) =>
      const [
        'positive',
        'neutral',
        'negative',
      ].contains(review.normalizedSentimentLabel)
      ? review.normalizedSentimentLabel
      : 'Unanalyzed';
  List<Review> get ratedReviews =>
      reviews.where((r) => r.rating >= 1 && r.rating <= 5).toList();
  double get averageRating => ratedReviews.isEmpty
      ? 0
      : ratedReviews.fold<double>(0, (n, r) => n + r.rating) /
            ratedReviews.length;
  int get completed => bookings.where((b) => b.isCompleted).length;
  double get completedValue => bookings
      .where((b) => b.isCompleted && validFee(b.totalFee))
      .fold(0.0, (value, b) => value + b.totalFee!);
  static bool validFee(double? fee) => fee != null && fee.isFinite && fee >= 0;
  Map<String, int> get categories {
    final counts = <String, int>{};
    for (final b in bookings) {
      final key = data.category(b.serviceId);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, double> get providerRatings {
    final sums = <String, int>{}, counts = <String, int>{};
    for (final r in ratedReviews) {
      sums[r.providerId] = (sums[r.providerId] ?? 0) + r.rating;
      counts[r.providerId] = (counts[r.providerId] ?? 0) + 1;
    }
    return {for (final id in sums.keys) id: sums[id]! / counts[id]!};
  }

  Map<int, int> get ratingDistribution {
    final values = {for (var star = 1; star <= 5; star++) star: 0};
    for (final rating in providerRatings.values) {
      values[rating.round()] = values[rating.round()]! + 1;
    }
    return values;
  }

  List<ReportVerification> get verifications => {
    for (final v in data.verifications)
      if (v.at != null &&
          data.period.contains(v.at!) &&
          (filter.provider == null || v.id == filter.provider) &&
          (filter.status == null || v.status == filter.status))
        v.id: v,
  }.values.toList();

  AdminReportResult generate(AdminReportType type) {
    final rows = <Map<String, Object?>>[];
    final summary = <String, Object?>{};
    switch (type) {
      case AdminReportType.transactions:
        for (final b in bookings) {
          rows.add({
            'Booking ID': b.bookingId,
            'Provider ID': b.providerId,
            'Category': data.category(b.serviceId),
            'Status': b.status,
            'Requested at (Asia/Manila)': reportTimestampText(
              b.createdAt.toDate(),
            ),
            'Fee (PHP)': validFee(b.totalFee) ? b.totalFee : null,
          });
        }
        summary.addAll({
          'Bookings': bookings.length,
          'Completed': completed,
          'Completion (%)': bookings.isEmpty
              ? 0.0
              : completed * 100 / bookings.length,
          'Completed booking value (PHP)': completedValue,
          'Completed bookings without fee': bookings
              .where((b) => b.isCompleted && !validFee(b.totalFee))
              .length,
        });
      case AdminReportType.providers:
        final ids = {
          ...bookings.map((b) => b.providerId),
          ...reviews.map((r) => r.providerId),
        }..remove('');
        final byProvider = <String, List<Booking>>{};
        final reviewsByProvider = <String, List<Review>>{};
        for (final b in bookings) {
          byProvider.putIfAbsent(b.providerId, () => []).add(b);
        }
        for (final r in ratedReviews) {
          reviewsByProvider.putIfAbsent(r.providerId, () => []).add(r);
        }
        for (final id in ids.toList()..sort()) {
          final jobs = byProvider[id] ?? [];
          final ratings = reviewsByProvider[id] ?? [];
          final done = jobs.where((b) => b.isCompleted).length;
          rows.add({
            'Provider ID': id,
            'Bookings': jobs.length,
            'Completed': done,
            'Completion (%)': jobs.isEmpty ? 0.0 : done * 100 / jobs.length,
            'Reviews': ratings.length,
            'Average rating': ratings.isEmpty
                ? null
                : ratings.fold<int>(0, (n, r) => n + r.rating) / ratings.length,
            'Completed booking value (PHP)': jobs
                .where((b) => b.isCompleted && validFee(b.totalFee))
                .fold<double>(0.0, (n, b) => n + b.totalFee!),
          });
        }
        summary.addAll({
          'Providers with activity': ids.length,
          'Bookings': bookings.length,
          'Completed': completed,
          'Customer reviews': ratedReviews.length,
          'Average rating': ratedReviews.isEmpty ? null : averageRating,
        });
      case AdminReportType.verification:
        for (final v in verifications) {
          rows.add({
            'User ID': v.id,
            'Role': v.role,
            'Status': v.status,
            'Record date (Asia/Manila)': reportTimestampText(v.at!),
            'Date basis': v.dateBasis,
          });
        }
        summary['Verification records'] = rows.length;
        for (final status in [
          'Approved',
          'Rejected',
          'Pending',
          'Not started',
        ]) {
          summary[status] = verifications
              .where((v) => v.status == status)
              .length;
        }
      case AdminReportType.feedback:
        for (final r in reviews) {
          rows.add({
            'Review ID': r.reviewId,
            'Booking ID': r.bookingId,
            'Provider ID': r.providerId,
            'Category': data.category(r.serviceId),
            'Rating': r.rating >= 1 && r.rating <= 5 ? r.rating : null,
            'Sentiment': sentiment(r),
            'Submitted at (Asia/Manila)': reportTimestampText(
              r.createdAt.toDate(),
            ),
          });
        }
        summary.addAll({
          'Customer feedback': reviews.length,
          'Rated reviews': ratedReviews.length,
          'Average rating': ratedReviews.isEmpty ? null : averageRating,
        });
        for (final label in ['positive', 'neutral', 'negative', 'Unanalyzed']) {
          summary[label] = reviews.where((r) => sentiment(r) == label).length;
        }
    }
    rows.sort(
      (a, b) => a.values.first.toString().compareTo(b.values.first.toString()),
    );
    return AdminReportResult(
      type: type,
      period: data.period,
      loadedAt: data.loadedAt,
      filters: {
        'Category': filter.category ?? 'All',
        'Provider': filter.provider ?? 'All',
        'Status': filter.status ?? 'All',
      },
      summary: summary,
      rows: rows,
    );
  }
}
