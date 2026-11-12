import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/services/booking_availability.dart';
import 'package:neighbor_help/screens/shared/agreement_amendment_screen.dart';
import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  test(
    'preferred, estimated and confirmed terms survive model round trips without becoming final prematurely',
    () {
      final boundaryYear = DateTime.now().year + 1;
      final initial = Booking.fromFirestore('b', {
        'requestVersion': 2,
        'providerId': 'p',
        'customerId': 'c',
        'status': 'Pending',
        'durationHours': 1.5,
        'totalFee': 188.25,
        'pricingType': 'hourly',
        'hourlyRate': 125.5,
        'scheduledDate': Timestamp.fromDate(
          DateTime.utc(boundaryYear, 10, 31, 16, 15),
        ),
        'termsStatus': 'Awaiting provider estimate',
      });
      expect(initial.requiresProviderEstimate, true);
      expect(initial.hasConfirmedSchedule, false);
      expect(initial.scheduledWindowLabel, contains('Nov 1, $boundaryYear'));
      expect(initial.scheduledWindowLabel, contains('12:15 AM'));
      expect(initial.statusLabel, 'Awaiting provider estimate');
      final pending = Booking.fromFirestore('b', {
        ...initial.toMap(),
        'status': 'Changes Requested',
        'pendingAmendmentId': 'estimate',
        'termsStatus': 'Awaiting customer approval',
      });
      expect(pending.statusLabel, 'Awaiting customer approval');
      expect(pending.hasConfirmedSchedule, false);
      final confirmed = Booking.fromFirestore('b', {
        ...pending.toMap(),
        'status': 'Accepted',
        'confirmedTerms': {'text': 'Approved terms', 'hash': 'fingerprint'},
        'termsStatus': 'Confirmed',
      });
      expect(confirmed.hasConfirmedSchedule, true);
      expect(confirmed.requiresProviderEstimate, false);
      expect(
        Booking.fromFirestore('b', confirmed.toMap()).confirmedTerms?['hash'],
        'fingerprint',
      );
      expect(confirmed.pricingSummary, contains('125.50'));
      expect(
        Booking.fromFirestore('old', {
          'status': 'Accepted',
          'totalFee': 99,
        }).requestVersion,
        1,
      );
    },
  );
  test(
    'listing estimates use whole, fractional, ranged and combined hour/minute descriptions consistently',
    () {
      for (final entry in {
        '45 minutes': .75,
        '1–2 hours': 2.0,
        '1 hour 30 min': 1.5,
        'Varies': 1.0,
        '1.25 hours': 1.25,
      }.entries) {
        expect(listingDurationHours(entry.key), entry.value);
      }
    },
  );
  test(
    'available starts are grouped by Manila calendar days, including UTC date boundaries',
    () {
      final slots = BookingAvailability.fromMap({
        'days': [
          {
            'starts': [
              DateTime.utc(2026, 10, 31, 16).millisecondsSinceEpoch,
              DateTime.utc(2026, 11, 1, 1, 15).millisecondsSinceEpoch,
            ],
          },
        ],
        'estimatedDurationHours': 1.5,
        'estimatedTotalFee': 188.25,
        'pricingType': 'hourly',
        'hourlyRate': 125.5,
      });
      expect(slots.forDay(DateTime(2026, 11, 1)).length, 2);
      expect(slots.hasDay(DateTime(2026, 10, 31)), false);
      expect(
        manilaInstant(
          DateTime(2026, 11, 1),
          const TimeOfDay(hour: 9, minute: 15),
        ),
        DateTime.utc(2026, 11, 1, 1, 15),
      );
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'provider estimate controls remain clear and validate before any command at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: AgreementAmendmentScreen(
              bookingId: 'b',
              bookingData: {
                'requestVersion': 2,
                'providerId': 'p',
                'customerId': 'c',
                'serviceId': 's',
                'pricingType': 'hourly',
                'hourlyRate': 125.5,
                'durationHours': 1.5,
                'totalFee': 188.25,
                'scheduledDate': Timestamp.fromDate(
                  DateTime.utc(2027, 1, 1, 1),
                ),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Provider-estimated duration (hours)'),
          findsOneWidget,
        );
        expect(find.text('Proposed hourly rate (PHP)'), findsOneWidget);
        expect(
          find.textContaining('Proposed total: PHP 188.25'),
          findsOneWidget,
        );
        final preview = find.text('Preview provider estimate');
        await tester.ensureVisible(preview);
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(find.text('Explain in at least 10 characters'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
