import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/inquiry.dart';
import 'package:neighbor_help/utils/approved_service_catalog.dart';
import 'package:neighbor_help/figma_ui/marketing_service_catalog.dart';
import 'package:neighbor_help/figma_ui/marketing_featured_services.dart';
import 'package:neighbor_help/widgets/service_agreement_card.dart';

void main() {
  test('client and server share the same supported service boundaries', () {
    final server = jsonDecode(
      File('functions/service_policy.json').readAsStringSync(),
    );
    expect(server, approvedServiceCatalog);
    expect(isSupportedService('Custom Services', 'Carpentry'), isFalse);
    expect(
      isSupportedService('Repair and Technical Services', 'Electrical Repair'),
      isTrue,
    );
    expect(isSupportedService('Cleaning', 'House Cleaning'), isTrue);
    for (final service in MarketingFeaturedServices.all) {
      expect(isSupportedService(service.categoryName, service.title), isTrue);
    }
    for (final category in MarketingServiceCatalog.categories) {
      expect(category.services, isNotEmpty);
      for (final service in category.services) {
        expect(isSupportedService(category.name, service.name), isTrue);
      }
    }
  });
  test(
    'new daily display and historical hourly display preserve their recorded amounts',
    () {
      final daily = Booking.fromFirestore('daily', {
        'pricingType': 'daily',
        'proposedRate': 750.25,
        'numberOfDays': 3,
        'totalFee': 2250.75,
      });
      expect(daily.pricingSummary, '₱750.25/day × 3 day(s)');
      expect(daily.totalFee, 2250.75);
      final old = Booking.fromFirestore('old', {
        'pricingType': 'hourly',
        'hourlyRate': 123,
        'durationHours': 2,
        'totalFee': 246,
      });
      expect(old.pricingSummary, contains('123.00/hr'));
      expect(old.totalFee, 246);
    },
  );
  test(
    'multi-day completion uses the last agreed work period and pending offers can be withdrawn',
    () {
      final end = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 3)),
      );
      final b = Booking.fromFirestore('b', {
        'status': 'In Progress',
        'agreement': {'text': 'Agreed'},
        'durationHours': 24,
        'startedAt': Timestamp.now(),
        'scheduledEndDate': end,
      });
      expect(b.workEndsAt, end.toDate());
      expect(b.canMarkCompleted, isFalse);
      expect(
        Booking.fromFirestore('pending', {
          'status': 'Pending',
          'scheduledDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 1)),
          ),
        }).canCustomerCancel,
        isTrue,
      );
      expect(
        Booking.fromFirestore('changes', {
          'status': 'Changes Requested',
        }).canCustomerCancel,
        isTrue,
      );
    },
  );
  test('stale and expired public projections fail closed', () {
    ServiceProviderProfile profile(Map<String, dynamic> extra) =>
        ServiceProviderProfile.fromFirestore('p', {
          'isVerified': true,
          'eligibleServiceIds': ['s'],
          ...extra,
        });
    expect(profile({}).canOfferService('s'), isFalse);
    expect(
      profile({
        'marketplacePolicyVersion': 3,
        'eligibleServiceExpiries': {'s': DateTime(2000).millisecondsSinceEpoch},
      }).canOfferService('s'),
      isFalse,
    );
    expect(
      profile({
        'marketplacePolicyVersion': 3,
        'eligibleServiceExpiries': {'s': DateTime(2099).millisecondsSinceEpoch},
      }).canOfferService('s'),
      isTrue,
    );
  });
  test('both participants must discuss before the client enables an offer', () {
    expect(
      Inquiry('a', {
        'customerMessageCount': 1,
        'providerMessageCount': 0,
      }).hasDiscussion,
      isFalse,
    );
    expect(
      Inquiry('a', {
        'customerMessageCount': 1,
        'providerMessageCount': 1,
      }).hasDiscussion,
      isTrue,
    );
  });
  for (final width in [360.0, 1024.0]) {
    testWidgets('agreement consent is explicit and scrollable at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  answer = await confirmServiceAgreement(
                    context,
                    agreement: {
                      'text': List.filled(
                        40,
                        'Terms that both parties can review before accepting.',
                      ).join('\n'),
                    },
                    title: 'Review agreement',
                    confirmation:
                        'I am at least 18 and voluntarily accept these exact terms.',
                  );
                },
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Agree and continue'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
