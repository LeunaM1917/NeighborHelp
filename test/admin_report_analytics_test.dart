import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/admin_report.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/review.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/services/export_service.dart';
import 'package:neighbor_help/utils/report_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 13, 5);
  final period = ReportPeriod.named('This month', now);
  Booking booking(
    String id,
    String provider,
    String service,
    String status, {
    double? fee,
    DateTime? at,
  }) => Booking.fromFirestore(id, {
    'providerId': provider,
    'serviceId': service,
    'status': status,
    'totalFee': fee,
    'createdAt': Timestamp.fromDate(at ?? DateTime.utc(2026, 11, 1)),
    'scheduledDate': Timestamp.fromDate(DateTime.utc(2030)),
  });
  Review review(
    String id,
    int rating, {
    String provider = 'p1',
    String service = 's1',
    String? sentiment,
    String role = 'customer',
    DateTime? at,
  }) => Review.fromFirestore(id, {
    'providerId': provider,
    'serviceId': service,
    'rating': rating,
    'reviewerRole': role,
    'createdAt': Timestamp.fromDate(at ?? DateTime.utc(2026, 11, 3)),
    'comment': 'Private feedback must not enter exports',
    if (sentiment != null) 'sentiment': {'label': sentiment, 'source': 'lstm'},
  });
  final first = booking('b1', 'p1', 's1', 'Milestone Complete', fee: 100);
  final data = AdminReportData(
    period: period,
    loadedAt: now,
    services: {
      's1': ServiceListing.fromFirestore('s1', {'category': 'Cleaning'}),
      's2': ServiceListing.fromFirestore('s2', {'category': 'Home Repair'}),
    },
    providers: [],
    bookings: [
      first,
      first,
      booking('b2', 'p2', 's2', 'Completed'),
      booking('b3', 'p1', 'deleted', 'Cancelled', fee: 500),
      booking(
        'old',
        'p1',
        's1',
        'Completed',
        fee: 900,
        at: period.start.subtract(const Duration(microseconds: 1)),
      ),
      booking(
        'future',
        'p1',
        's1',
        'Completed',
        fee: 900,
        at: period.endExclusive,
      ),
    ],
    reviews: [
      review('r1', 5, sentiment: 'Positive'),
      review('r1', 5, sentiment: 'Positive'),
      review('r2', 1, sentiment: 'negative'),
      review('r3', 4, provider: 'p2', service: 's2', sentiment: 'neutral'),
      review('r4', 0),
      review('r5', 5, role: 'provider'),
      review('old', 2, at: period.start.subtract(const Duration(seconds: 1))),
    ],
    verifications: [
      ReportVerification.fromMap('p1', {
        'role': 'Provider',
        'isVerified': true,
        'verificationUpdatedAt': Timestamp.fromDate(now),
        'governmentIdNumber': 'sensitive',
        'identitySessionUrl': 'secret',
      }),
      ReportVerification.fromMap('p1', {
        'role': 'Provider',
        'isVerified': true,
        'verificationUpdatedAt': Timestamp.fromDate(now),
      }),
      ReportVerification.fromMap('c1', {
        'role': 'Customer',
        'diditStatus': 'in review',
        'createdAt': Timestamp.fromDate(now),
      }),
      ReportVerification.fromMap('c2', {'role': 'Customer'}),
    ],
  );

  test(
    'Manila period boundaries include midnight, leap/year boundaries and exclude future dates',
    () {
      expect(period.start, DateTime.utc(2026, 10, 31, 16));
      expect(period.contains(DateTime.utc(2026, 10, 31, 15, 59, 59)), isFalse);
      expect(period.contains(period.start), isTrue);
      expect(period.contains(now), isTrue);
      expect(period.contains(period.endExclusive), isFalse);
      expect(
        reportRangeStart('This week', DateTime.utc(2026, 11, 8, 16)),
        DateTime.utc(2026, 11, 8, 16),
      );
      expect(
        reportRangeStart('This year', DateTime.utc(2025, 12, 31, 16)),
        DateTime.utc(2025, 12, 31, 16),
      );
      final custom = ReportPeriod.dates(
        DateTime(2024, 2, 29),
        DateTime(2024, 2, 29),
        now,
      );
      expect(custom.start, DateTime.utc(2024, 2, 28, 16));
      expect(custom.endExclusive, DateTime.utc(2024, 2, 29, 16));
      expect(
        reportTimestampText(DateTime.utc(2026, 10, 31, 16)),
        '2026-11-01T00:00:00.000+08:00',
      );
    },
  );

  test(
    'deduplicates IDs, counts milestone completions and keeps unknown fees out of totals',
    () {
      final stats = AdminReportAnalytics(data, const AdminReportFilter());
      expect(stats.bookings.length, 3);
      expect(stats.completed, 2);
      expect(stats.completedValue, 100);
      expect(stats.categories, {'Cleaning': 1, 'Home Repair': 1, 'Other': 1});
      expect(stats.averageRating, closeTo(10 / 3, .00001));
      expect(stats.providerRatings, {'p1': 3.0, 'p2': 4.0});
      expect(stats.ratingDistribution, {1: 0, 2: 0, 3: 1, 4: 1, 5: 0});
      expect(
        stats
            .generate(AdminReportType.transactions)
            .summary['Completed bookings without fee'],
        1,
      );
    },
  );

  test(
    'category, provider and report-specific status filters apply before aggregation',
    () {
      final filtered = AdminReportAnalytics(
        data,
        const AdminReportFilter(category: 'Cleaning', provider: 'p1'),
      );
      expect(filtered.bookings.map((b) => b.bookingId), ['b1']);
      expect(filtered.averageRating, 3);
      expect(
        filtered.generate(AdminReportType.providers).rows.single['Bookings'],
        1,
      );
      final completed = AdminReportAnalytics(
        data,
        const AdminReportFilter(status: 'Milestone Complete'),
      ).generate(AdminReportType.transactions);
      expect(completed.rows.length, 1);
      expect(completed.summary['Completion (%)'], 100);
      final feedback = AdminReportAnalytics(
        data,
        const AdminReportFilter(status: 'positive'),
      ).generate(AdminReportType.feedback);
      expect(feedback.rows.single['Review ID'], 'r1');
      expect(feedback.summary['positive'], 1);
      final noMatch = AdminReportAnalytics(
        data,
        const AdminReportFilter(provider: 'missing'),
      );
      expect(noMatch.generate(AdminReportType.providers).rows, isEmpty);
      expect(noMatch.averageRating, 0);
    },
  );

  test(
    'verification records use one user ID, explicit date basis and safe columns',
    () {
      final report = AdminReportAnalytics(
        data,
        const AdminReportFilter(),
      ).generate(AdminReportType.verification);
      expect(report.rows.length, 2);
      expect(report.summary['Approved'], 1);
      expect(report.summary['Pending'], 1);
      expect(report.rows.first['Date basis'], 'createdAt');
      expect(jsonEncode(report.toJson()), isNot(contains('sensitive')));
      expect(
        jsonEncode(report.toJson()),
        isNot(contains('identitySessionUrl')),
      );
    },
  );

  test(
    'all report exports retain the exact filtered preview and reporting context',
    () async {
      for (final type in AdminReportType.values) {
        final result = AdminReportAnalytics(
          data,
          const AdminReportFilter(provider: 'p1'),
        ).generate(type);
        final json = jsonDecode(
          utf8.decode(await ExportService.reportBytes(result, 'json')),
        );
        expect(json['records'], result.rows);
        expect(json['summary'], result.summary);
        expect(json['filters']['Provider'], 'p1');
        expect(json['timezone'], 'Asia/Manila');
        final csv = utf8.decode(await ExportService.reportBytes(result, 'csv'));
        expect(csv, contains('Summary:'));
        expect(csv, contains('+08:00'));
        for (final row in result.rows) {
          expect(csv, contains(row.values.first.toString()));
        }
        expect(csv, isNot(contains('Private feedback')));
        expect(() => result.rows.clear(), throwsUnsupportedError);
        final pdf = await ExportService.reportBytes(result, 'pdf');
        expect(latin1.decode(pdf.take(5).toList()), '%PDF-');
      }
    },
  );

  test(
    'PDF paginates a large report and supports Unicode categories',
    () async {
      final result = AdminReportResult(
        type: AdminReportType.transactions,
        period: period,
        loadedAt: now,
        filters: {'Category': 'Paglilinis – José'},
        summary: {'Bookings': 140},
        rows: List.generate(
          140,
          (i) => {
            'Booking ID': 'booking-$i',
        'Provider ID': 'provider-0123456789abcdef01234567',
            'Category': 'Paglilinis – José',
        'Status': 'Milestone Complete',
        'Requested at (Asia/Manila)': '2026-11-01T00:00:00.000+08:00',
            'Fee (PHP)': i + .25,
          },
        ),
      );
      final bytes = await ExportService.reportBytes(result, 'pdf');
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
        greaterThan(1),
      );
      const qa = String.fromEnvironment('REPORT_PDF_QA');
      if (qa.isNotEmpty) {
        File(qa).writeAsBytesSync(bytes);
      }
    },
  );

  test(
    'CSV neutralizes formulas while preserving commas, quotes and multiline values',
    () {
      final csv = encodeCsv([
        {'value': ' \t=SUM(A1)', 'notes': 'a,"b"\r\nc'},
      ]);
      expect(csv, contains('"\' \t=SUM(A1)"'));
      expect(csv, contains('"a,""b""\r\nc"'));
    },
  );
}
