import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/identity_verification.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_verification_widgets.dart';
import 'package:neighbor_help/utils/identity_verification_issues.dart';
import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  test('legacy and malformed issue data has a safe, truthful explanation', () {
    final v = IdentityVerification.fromMap({
      'verificationIssueCodes': [
        'IMAGE_TOO_BLURRY',
        123,
        'private content',
        'IMAGE_TOO_BLURRY',
        'NEW_VENDOR_WARNING',
      ],
    });
    expect(v.verificationIssueCodes, [
      'IMAGE_TOO_BLURRY',
      'NEW_VENDOR_WARNING',
    ]);
    final messages = identityVerificationIssues(v);
    expect(messages.first, contains('too blurry'));
    expect(messages.last, contains('additional issue'));
    expect(
      identityVerificationIssues(
        const IdentityVerification(diditStatus: 'Expired'),
      ).single,
      contains('link expired'),
    );
    expect(
      identityVerificationIssues(
        const IdentityVerification(verificationStatus: 'Rejected'),
      ).single,
      contains('no detailed reason was saved'),
    );
  });

  for (final provider in [false, true]) {
    for (final width in [390.0, 1280.0]) {
      testOnPlatform(
        'admin reads rejected ${provider ? 'provider' : 'customer'} issues at $width and can refresh',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final row = <String, dynamic>{
            'fullName': 'Test Member',
            'verificationProvider': 'idanalyzer',
            'verificationStatus': 'Rejected',
            'diditStatus': 'Declined',
            'verificationRetakeRequired': true,
            'governmentIdTypeLabel': "Driver's license",
            'verificationIssueCodes': [
              'UNRECOGNIZED_BACK_DOCUMENT',
              'LOW_TEXT_CONFIDENCE',
            ],
          };
          final user = AppUser.fromFirestore('member', row);
          final application = provider
              ? AdminVerificationApplication.provider(
                  profile: ServiceProviderProfile.fromFirestore('member', row),
                  user: user,
                  businessLabel: '',
                )
              : AdminVerificationApplication.customer(
                  customer: user,
                  businessLabel: '',
                );
          var refreshes = 0, approvals = 0, rejections = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AdminVerificationApplicationCard(
                    application: application,
                    onApprove: () => approvals++,
                    onReject: () => rejections++,
                    onRefreshDidit: () => refreshes++,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('View details'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('back of the ID could not be recognized'),
            findsOneWidget,
          );
          expect(
            find.textContaining('could not be read confidently'),
            findsOneWidget,
          );
          expect(find.text("Document: Driver's license"), findsOneWidget);
          expect(find.text('Status: Rejected'), findsOneWidget);
          await tester.tap(find.text('Refresh ID Analyzer'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(refreshes, 1);
          expect(approvals, 0);
          expect(rejections, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'approval explanation stays above action buttons at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final user = AppUser.fromFirestore('member', {
          'fullName': 'Test Member',
          'verificationProvider': 'idanalyzer',
          'diditStatus': 'Expired',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminVerificationApplicationCard(
                  application: AdminVerificationApplication.customer(
                    customer: user,
                    businessLabel: '',
                  ),
                  onApprove: () {},
                  onReject: () {},
                  onRefreshDidit: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final hint = find.text(
          'A readable, completed ID check is required before approval.',
        );
        expect(
          tester.getBottomLeft(hint).dy,
          lessThan(tester.getTopLeft(find.text('Reject')).dy),
        );
        await tester.tap(find.text('View details'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('verification link expired'),
          findsOneWidget,
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
