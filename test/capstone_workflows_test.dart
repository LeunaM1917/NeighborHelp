import 'package:neighbor_help/screens/admin/widgets/admin_bookings_widgets.dart'
    show bookingStatusBucket;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/review.dart';
import 'package:neighbor_help/utils/report_analytics.dart';
import 'package:neighbor_help/utils/service_search.dart';
import 'package:neighbor_help/utils/service_certification_policy.dart';
import 'package:neighbor_help/widgets/booking_reschedule_card.dart';

void main() {
  final now = DateTime(2026, 11, 3, 10);
  ServiceProviderProfile provider({String area = 'Panabo City'}) =>
      ServiceProviderProfile.fromFirestore('p', {
        'userId': 'p',
        'serviceArea': area,
        'isVerified': true,
        'approvedCertificationIds': ['cert'],
        'certificationHistory': [
          {
            'id': 'cert',
            'name': 'Carpentry NC II',
            'provider': 'TESDA',
            'status': 'Approved',
            'certificationId': 'NC-TEST',
            'verificationSource': 'TESDA Registry of Certified Workers',
            'reviewedBy': 'admin',
            'reviewedAt': Timestamp.now(),
            'url': 'gs://test/proof.pdf',
            'expirationDate': '2027-01-01',
          },
        ],
      });
  Booking booking({String status = 'Accepted', DateTime? date}) =>
      Booking.fromFirestore('b', {
        'customerId': 'c',
        'providerId': 'p',
        'serviceId': 's',
        'status': status,
        'scheduledDate': Timestamp.fromDate(
          date ?? now.add(const Duration(days: 1)),
        ),
        'createdAt': Timestamp.fromDate(date ?? now),
        'updatedAt': Timestamp.fromDate(now),
      });

  test('location, price and rating filters each constrain search results', () {
    bool matches({
      String location = 'Panabo City',
      String? price,
      String? rating,
    }) => matchesServiceFilters(
      price: 300,
      rating: 4.7,
      area: 'Panabo City',
      profile: provider(),
      location: location,
      priceFilter: price,
      ratingFilter: rating,
      now: now,
    );
    expect(matches(), isTrue);
    expect(matches(location: 'Tagum City'), isFalse);
    expect(matches(price: 'Under ₱300'), isFalse);
    expect(matches(price: '₱300 – ₱500'), isTrue);
    expect(matches(price: '₱500+'), isFalse);
    expect(matches(rating: '4.8+ stars'), isFalse);
    expect(matches(rating: '4.5+ stars'), isTrue);
  });
  test('availability filtering uses the provider weekly schedule', () {
    expect(
      matchesServiceFilters(
        price: 100,
        rating: 4,
        area: 'Panabo City',
        profile: provider(),
        availability: 'Today',
        now: DateTime(2026, 11, 8),
      ),
      isFalse,
    );
    expect(
      matchesServiceFilters(
        price: 100,
        rating: 4,
        area: 'Panabo City',
        profile: provider(),
        availability: 'Today',
        now: now,
      ),
      isTrue,
    );
  });
  test(
    'completed and milestone bookings share the completed reporting bucket',
    () {
      expect(bookingStatusBucket('Completed'), 0);
      expect(bookingStatusBucket('Milestone Complete'), 0);
      expect(bookingStatusBucket('Declined'), 2);
    },
  );
  test('this week availability does not include next week', () {
    expect(
      matchesServiceFilters(
        price: 100,
        rating: 4,
        area: 'Panabo City',
        profile: provider(),
        availability: 'This week',
        now: DateTime(2026, 11, 8),
      ),
      isFalse,
    );
  });

  test(
    'public discovery hides services that are no longer eligible for that provider',
    () {
      final profile = ServiceProviderProfile.fromFirestore('p', {
        'isVerified': true,
        'eligibleServiceIds': ['cleaning'],
        'marketplacePolicyVersion': 2,
        'eligibleServiceExpiries': {
          'cleaning': DateTime(2099).millisecondsSinceEpoch,
        },
      });
      expect(profile.canOfferService('cleaning'), isTrue);
      expect(profile.canOfferService('expired-technical-service'), isFalse);
    },
  );

  test('matching certificate qualifies carpentry but not plumbing', () {
    expect(
      serviceRequiresCertification(
        category: 'Home Repair',
        serviceTitle: 'Carpentry',
      ),
      isTrue,
    );
    expect(
      hasMatchingServiceCertificate(
        provider(),
        category: 'Home Repair',
        serviceTitle: 'Carpentry',
        now: now,
      ),
      isTrue,
    );
    expect(
      hasMatchingServiceCertificate(
        provider(),
        category: 'Home Repair',
        serviceTitle: 'Plumbing',
        now: now,
      ),
      isFalse,
    );
  });
  test(
    'selected report period excludes older records and includes milestone completion',
    () {
      final rows = bookingsInRange(
        [
          booking(status: 'Milestone Complete'),
          booking(date: DateTime(2026, 10, 30)),
        ],
        'This month',
        now: now,
      );
      expect(rows.length, 1);
      expect(rows.single.isCompleted, isTrue);
    },
  );
  test(
    'rating history comes from dated reviews and does not fabricate missing days',
    () {
      Review review(String id, int rating, int day) =>
          Review.fromFirestore(id, {
            'rating': rating,
            'reviewerRole': 'customer',
            'createdAt': Timestamp.fromDate(DateTime(2026, 11, day)),
          });
      final result = dailyReviewRatings([
        review('a', 5, 1),
        review('b', 3, 1),
        review('c', 2, 3),
      ]);
      expect(result, {DateTime(2026, 11, 1): 4.0, DateTime(2026, 11, 3): 2.0});
    },
  );
  test(
    'CSV exports preserve multiline text and neutralize spreadsheet formulas',
    () {
      final csv = encodeCsv([
        {'name': '=HYPERLINK("x")', 'notes': 'line 1\nline 2'},
      ]);
      expect(csv, contains('"\'=HYPERLINK(""x"")"'));
      expect(csv, contains('"line 1\nline 2"'));
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets('reschedule controls remain usable at width $width', (
      tester,
    ) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingRescheduleCard(
                booking: booking(),
                asCustomer: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Request a new date'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Request a new date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
