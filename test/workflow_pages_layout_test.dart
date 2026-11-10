// Firebase Core's official mocks initialize local document IDs without a server.
// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/screens/shared/agreement_amendment_screen.dart';
import 'package:neighbor_help/theme/app_theme.dart';
import 'package:neighbor_help/widgets/settlement_card.dart';
import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  final booking = <String, dynamic>{
    'totalFee': 400,
    'proposedRate': 400,
    'pricingType': 'fixed',
    'numberOfDays': 1,
    'hoursPerDay': 2,
    'scheduledDate': Timestamp.fromDate(DateTime.utc(2026, 11, 15, 1)),
  };
  for (final width in [390.0, 900.0, 1500.0]) {
    testOnPlatform(
      'settlement form stays usable and validates required details at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: neighborHelpTheme(),
            home: SettlementProposalScreen(
              bookingId: 'preview',
              bookingData: booking,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(4));
        expect(tester.takeException(), isNull);
        final preview = find.text('Preview settlement');
        await tester.ensureVisible(preview);
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(
          find.text('Explain in at least 10 characters'),
          findsNWidgets(3),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testOnPlatform(
      'amendment controls and preview remain reachable at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: neighborHelpTheme(),
            home: AgreementAmendmentScreen(
              bookingId: 'preview',
              bookingData: booking,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final preview = find.text('Preview amendment');
        await tester.ensureVisible(preview);
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(find.text('Explain in at least 10 characters'), findsOneWidget);
        expect(
          find.text('Describe in at least 5 characters'),
          findsNWidgets(7),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
