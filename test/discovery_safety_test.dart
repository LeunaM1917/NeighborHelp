import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:neighbor_help/data/panabo_barangays.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/requested_work_schedule.dart';
import 'package:neighbor_help/services/provider_recommendation_service.dart';
import 'package:neighbor_help/utils/barangay_coverage.dart';
import 'package:neighbor_help/utils/customer_map_data.dart';
import 'package:neighbor_help/widgets/provider_barangay_editor.dart';
import 'package:neighbor_help/widgets/provider_map_alternative.dart';
import 'package:neighbor_help/widgets/conversation_composer.dart';
import 'package:neighbor_help/widgets/conversation_message.dart';
import 'package:neighbor_help/widgets/service_agreement_card.dart';

void main() {
  test(
    'client and server use identical Panabo IDs, centers and indicative areas',
    () {
      final source =
          jsonDecode(File('functions/panabo_barangays.json').readAsStringSync())
              as Map;
      expect(panaboBarangays, source['barangays']);
      expect(panaboBarangays.length, 40);
      expect(
        barangaysCover(
          panaboBarangays.map((b) => b['id'] as String).toList(),
          const GeoPoint(7.3, 125.6),
        ),
        isTrue,
      );
      expect(
        barangaysCover(
          panaboBarangays.map((b) => b['id'] as String).toList(),
          const GeoPoint(14.6, 121),
        ),
        isFalse,
      );
    },
  );
  test(
    'an unanswered offer expires at its exact deadline and accepted work stays accepted',
    () {
      final past = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      final start = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 5)),
      );
      final expired = Booking.fromFirestore('b', {
        'status': 'Pending',
        'scheduledDate': start,
        'offerExpiresAt': past,
      });
      expect(expired.status, 'Expired');
      expect(expired.canCustomerCancel, isFalse);
      expect(expired.isPending, isFalse);
      expect(
        Booking.fromFirestore('b', {
          'status': 'Accepted',
          'scheduledDate': start,
          'offerExpiresAt': past,
        }).status,
        'Accepted',
      );
    },
  );
  test(
    'recommendations exclude selected barangays that do not cover the customer and mark time off unavailable',
    () {
      final all = panaboBarangays.map((b) => b['id'] as String).toList();
      const origin = GeoPoint(7.3, 125.6);
      final outside = panaboBarangays.firstWhere(
        (b) => !barangaysCover([b['id'] as String], origin),
      )['id'];
      final start = DateTime.parse('2026-11-09T01:00:00Z');
      ServiceProviderProfile profile(String id, List ids, {bool off = false}) =>
          ServiceProviderProfile.fromFirestore(id, {
            'isVerified': true,
            'location': origin,
            'serviceBarangayIds': ids,
            'timeOff': off
                ? [
                    {
                      'startMs': start.millisecondsSinceEpoch,
                      'endMs': start
                          .add(const Duration(hours: 2))
                          .millisecondsSinceEpoch,
                    },
                  ]
                : [],
          });
      final ranked = rankProvidersByRecommendation(
        providers: [
          profile('yes', all),
          profile('no', [outside]),
          profile('leave', all, off: true),
        ],
        customerOrigin: origin,
        requestedSchedule: RequestedWorkSchedule(
          start: start,
          days: 1,
          hoursPerDay: 1,
        ),
        availabilityByProvider: {'yes': true, 'no': true, 'leave': true},
      );
      expect(ranked.map((r) => r.profile.providerId), isNot(contains('no')));
      expect(ranked.map((r) => r.profile.providerId), isNot(contains('leave')));
    },
  );

  Widget app(Widget child, double scale) => MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    builder: (context, body) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: body!,
    ),
    home: Scaffold(body: child),
  );
  void size(WidgetTester t, double width) {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('expired offer card does not claim it is awaiting acceptance', (
    tester,
  ) async {
    final booking = Booking.fromFirestore('b', {
      'status': 'Expired',
      'scheduledDate': Timestamp.now(),
      'agreement': {'text': 'Original terms', 'hash': 'original'},
    });
    await tester.pumpWidget(app(ServiceAgreementCard(booking: booking), 1));
    expect(find.text('Expired without provider acceptance'), findsOneWidget);
    expect(find.textContaining('awaiting provider acceptance'), findsNothing);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'barangay selection and chat remain readable at 320px with text scale $scale',
      (tester) async {
        size(tester, 320);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            app(
              SingleChildScrollView(
                child: Column(
                  children: [
                    Form(
                      child: ProviderBarangayEditor(
                        baseId: panaboBarangays.first['id'] as String,
                        serviceIds: const {},
                        onChanged: (_, _) {},
                      ),
                    ),
                    const ConversationMessage(
                      mine: true,
                      senderName: 'You',
                      text: 'Please discuss the materials, schedule and price.',
                      mediaUrl: '',
                    ),
                    ConversationComposer(
                      controller: controller,
                      enabled: true,
                      sending: false,
                      onSend: () {},
                      onPhoto: () {},
                    ),
                  ],
                ),
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.ensureVisible(find.byType(ConversationComposer));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Send message'), findsOneWidget);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tester.ensureVisible(find.text('Choose where you accept jobs'));
          await tester.tap(find.text('Choose where you accept jobs'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.text('Use selection'), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
  testWidgets(
    'keyboard sends exactly once and cannot send through disabled or busy chat',
    (tester) async {
      final controller = TextEditingController(text: 'Discuss requirements');
      addTearDown(controller.dispose);
      var sent = 0;
      Future<void> mount(bool enabled, bool sending) => tester.pumpWidget(
        app(
          ConversationComposer(
            controller: controller,
            enabled: enabled,
            sending: sending,
            onSend: () => sent++,
            onPhoto: () {},
          ),
          1,
        ),
      );
      await mount(true, false);
      await tester.tap(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(sent, 1);
      await mount(false, false);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(sent, 1);
      await mount(true, true);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Send message',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'barangay checkboxes save the selected coverage and dialog actions have labels',
    (tester) async {
      Set<String> selected = {};
      String? base;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, update) => Form(
              child: SingleChildScrollView(
                child: ProviderBarangayEditor(
                  baseId: base,
                  serviceIds: selected,
                  onChanged: (b, ids) => update(() {
                    base = b;
                    selected = ids;
                  }),
                ),
              ),
            ),
          ),
          1,
        ),
      );
      await tester.tap(find.text('Choose where you accept jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.tap(find.text('Use selection'));
      await tester.pumpAndSettle();
      expect(selected, {panaboBarangays.first['id']});
      expect(find.text('Service barangays (1 selected)'), findsOneWidget);
    },
  );
  testWidgets(
    'map has a screen-reader list of the same providers without displaying coordinates',
    (tester) async {
      const pins = [
        NearbyMapPin(
          id: 'p',
          position: LatLng(7.3, 125.6),
          label: 'Test Provider',
          area: 'New Visayas, Panabo City (approximate base)',
        ),
      ];
      await tester.pumpWidget(
        app(
          const SingleChildScrollView(
            child: ProviderMapAlternative(pins: pins),
          ),
          2,
        ),
      );
      await tester.tap(find.text('Provider list (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Test Provider'), findsOneWidget);
      expect(find.textContaining('7.3'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
