import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/provider_weekly_availability.dart';
import 'package:neighbor_help/models/requested_work_schedule.dart';
import 'package:neighbor_help/services/provider_recommendation_service.dart';
import 'package:neighbor_help/widgets/work_completion_card.dart';

void main() {
  RequestedWorkSchedule request(String iso, {int days = 1, double hours = 1}) =>
      RequestedWorkSchedule(
        start: DateTime.parse(iso),
        days: days,
        hoursPerDay: hours,
      );
  Booking booking(String status, {String price = 'fixed'}) =>
      Booking.fromFirestore('b', {
        'customerId': 'c',
        'providerId': 'p',
        'status': status,
        'pricingType': price,
        'startedAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        'scheduledDate': Timestamp.fromDate(DateTime.now()),
        'scheduledEndDate': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 4)),
        ),
        'agreement': {'hash': 'test', 'text': 'Test agreement'},
      });
  test(
    'full requested hours and every consecutive day must fit Philippine working hours',
    () {
      final schedule = ProviderWeeklyAvailability.defaults;
      expect(
        schedule.coversRequest(request('2026-11-09T08:00:00Z', hours: 1)),
        isTrue,
      ); // 4–5 PM
      expect(
        schedule.coversRequest(request('2026-11-09T08:00:00Z', hours: 2)),
        isFalse,
      );
      expect(
        schedule.coversRequest(request('2026-11-14T01:00:00Z', days: 2)),
        isFalse,
      ); // Sunday off
    },
  );
  test(
    'Monday overnight shift covers Tuesday morning but not Monday morning',
    () {
      final schedule = ProviderWeeklyAvailability.defaults
          .updateDay(
            'Monday',
            const ProviderDaySchedule(
              enabled: true,
              start: '10:00 PM',
              end: '2:00 AM',
            ),
          )
          .updateDay(
            'Tuesday',
            const ProviderDaySchedule(
              enabled: false,
              start: '8:00 AM',
              end: '5:00 PM',
            ),
          );
      expect(schedule.coversRequest(request('2026-11-09T17:00:00Z')), isTrue);
      expect(schedule.coversRequest(request('2026-11-08T17:00:00Z')), isFalse);
      expect(schedule.isAvailableNow(DateTime(2026, 11, 10, 1)), isTrue);
    },
  );
  test(
    'scheduled matching fails closed until accepted-booking availability is known',
    () {
      final p = ServiceProviderProfile.fromFirestore('p', {
        'userId': 'p',
        'isVerified': true,
        'location': const GeoPoint(7.3, 125.6),
      });
      final schedule = request('2026-11-09T01:00:00Z');
      expect(
        rankProvidersByRecommendation(
          providers: [p],
          requestedSchedule: schedule,
        ),
        isEmpty,
      );
      expect(
        rankProvidersByRecommendation(
          providers: [p],
          requestedSchedule: schedule,
          availabilityByProvider: {'p': false},
        ),
        isEmpty,
      );
      expect(
        rankProvidersByRecommendation(
          providers: [p],
          requestedSchedule: schedule,
          availabilityByProvider: {'p': true},
        ),
        hasLength(1),
      );
    },
  );
  test(
    'fixed-price completion may be reported early, but it is not completed until confirmation',
    () {
      expect(booking('In Progress').canMarkCompleted, isTrue);
      expect(booking('In Progress', price: 'daily').canMarkCompleted, isFalse);
      final reported = booking('Awaiting Confirmation');
      expect(reported.isAwaitingConfirmation, isTrue);
      expect(reported.isCompleted, isFalse);
      expect(reported.canMarkCompleted, isFalse);
    },
  );
  test(
    'blocking preserves discussion state but pauses messaging and new offers',
    () {
      final t = Inquiry('t', {
        'blockedBy': ['c'],
        'customerMessageCount': 1,
        'providerMessageCount': 1,
      });
      expect(t.isBlocked, isTrue);
      expect(t.hasDiscussion, isTrue);
      expect(t.blockedBy, contains('c'));
    },
  );
  for (final width in [360.0, 1024.0]) {
    testWidgets(
      'customer can review completion choices without auto-confirming at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkCompletionCard(
                  booking: booking('Awaiting Confirmation'),
                  asCustomer: true,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Confirm work complete'), findsOneWidget);
        expect(find.text('Request corrections'), findsOneWidget);
        await tester.tap(find.text('Confirm work complete'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm deliverables complete'), findsOneWidget);
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Request corrections'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
