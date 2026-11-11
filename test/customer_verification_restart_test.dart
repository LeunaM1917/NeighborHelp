import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/screens/customer/widgets/customer_verification_widgets.dart';
import 'package:neighbor_help/screens/provider/provider_government_id_picker_dialog.dart';
import 'package:neighbor_help/screens/provider/widgets/provider_profile_widgets.dart';
import 'package:neighbor_help/services/identity_verification_service.dart';

import 'support/ui_test_support.dart';

class _UnusedFunctions extends Fake implements FirebaseFunctions {}

class _RecordingVerificationService extends IdentityVerificationService {
  _RecordingVerificationService() : super(functions: _UnusedFunctions());

  final documents = <String>[];
  VerificationSubject? lastSubject;

  @override
  Future<bool> startGovernmentIdVerification({
    required String documentType,
    required String documentLabel,
    String? callbackUrl,
    VerificationSubject subject = VerificationSubject.provider,
  }) async {
    documents.add(documentType);
    lastSubject = subject;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double width = 1280,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'an unfinished customer attempt can cancel or change ID at $width',
      (tester) async {
        final service = _RecordingVerificationService();
        await show(
          tester,
          ProviderVerifyIdentityButton(
            subject: VerificationSubject.customer,
            governmentIdTypeCode: 'ID',
            governmentIdTypeLabel: 'National ID card',
            inReview: true,
            restartFromIdPicker: true,
            identityService: service,
          ),
          width: width,
        );
        await tester.tap(find.text('Restart verification'));
        await tester.pumpAndSettle();
        expect(find.byType(ProviderGovernmentIdPickerDialog), findsOneWidget);
        expect(find.text('Passport'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue to ID Analyzer'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(service.documents, isEmpty);

        await tester.tap(find.text('Restart verification'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Passport'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue to ID Analyzer'));
        await tester.pumpAndSettle();
        expect(service.documents, ['P']);
        expect(service.lastSubject, VerificationSubject.customer);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform(
    'customer card distinguishes unfinished, submitted review and verified states',
    (tester) async {
      for (final status in [
        'Not Started',
        'In Progress',
        'In Review',
        'Approved',
      ]) {
        final verified = status == 'Approved';
        final user = AppUser.fromFirestore('customer', {
          'role': 'Customer',
          'accountStatus': 'Active',
          'diditStatus': status,
          'verificationProvider': 'idanalyzer',
          'verificationStatus': verified ? 'Approved' : 'Pending',
          'isVerified': verified,
          'governmentIdTypeCode': 'ID',
          'governmentIdTypeLabel': 'National ID card',
        });
        await show(tester, CustomerVerificationTrustCard(user: user));
        expect(
          find.text('Government ID verified'),
          verified ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Restart verification'),
          ['Not Started', 'In Progress'].contains(status)
              ? findsOneWidget
              : findsNothing,
        );
        if (status == 'In Review') {
          expect(
            find.text('National ID card — awaiting identity review'),
            findsOneWidget,
          );
          expect(
            find.text(
              'Verification incomplete. Choose your government ID again.',
            ),
            findsNothing,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'provider continuation retains its existing selected-document behavior',
    (tester) async {
      final service = _RecordingVerificationService();
      await show(
        tester,
        ProviderVerifyIdentityButton(
          inReview: true,
          governmentIdTypeCode: 'ID',
          identityService: service,
        ),
      );
      await tester.tap(find.text('Continue on ID Analyzer'));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderGovernmentIdPickerDialog), findsNothing);
      expect(service.documents, ['ID']);
      expect(service.lastSubject, VerificationSubject.provider);
    },
  );
}
