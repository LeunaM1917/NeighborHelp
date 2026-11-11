import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/identity_verification.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_verification_widgets.dart';
import 'package:neighbor_help/screens/customer/widgets/customer_verification_widgets.dart';
import 'package:neighbor_help/screens/provider/widgets/provider_profile_widgets.dart';
import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  test(
    'approval eligibility excludes unfinished capture and unreadable results',
    () {
      expect(
        const IdentityVerification(
          verificationProvider: 'idanalyzer',
          diditStatus: 'In Progress',
        ).canAdminApprove,
        false,
      );
      expect(
        const IdentityVerification(
          verificationProvider: 'idanalyzer',
          diditStatus: 'In Review',
        ).canAdminApprove,
        true,
      );
      expect(
        const IdentityVerification(
          verificationProvider: 'idanalyzer',
          diditStatus: 'Approved',
          verificationRetakeRequired: true,
        ).canAdminApprove,
        false,
      );
    },
  );
  for (final provider in [false, true]) {
    for (final width in [390.0, 1280.0]) {
      testOnPlatform(
        'unreadable ${provider ? 'provider' : 'customer'} ID shows retake guidance at $width',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final row = <String, dynamic>{
            'fullName': 'Test Member',
            'verificationProvider': 'idanalyzer',
            'diditStatus': 'Declined',
            'verificationStatus': 'Rejected',
            'verificationRetakeRequired': true,
            'governmentIdTypeCode': 'DL',
          };
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: provider
                      ? ProviderVerificationTrustCard(
                          profile: ServiceProviderProfile.fromFirestore(
                            'p',
                            row,
                          ),
                        )
                      : CustomerVerificationTrustCard(
                          user: AppUser.fromFirestore('c', row),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('could not be read clearly'),
            findsOneWidget,
          );
          expect(find.byType(ProviderVerifyIdentityButton), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final row in [('In Progress', false), ('In Review', true)]) {
    testOnPlatform(
      'admin approval is ${row.$2 ? 'available' : 'disabled'} for ${row.$1}, rejection stays available',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final user = AppUser.fromFirestore('c', {
          'fullName': 'Test Member',
          'verificationProvider': 'idanalyzer',
          'diditStatus': row.$1,
        });
        var approvals = 0, rejections = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AdminVerificationApplicationCard(
                  application: AdminVerificationApplication.customer(
                    customer: user,
                    businessLabel: 'Customer',
                  ),
                  onApprove: () => approvals++,
                  onReject: () => rejections++,
                  onRefreshDidit: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final approve = find.ancestor(
          of: find.text('Approve'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
        expect(tester.widget<FilledButton>(approve).onPressed != null, row.$2);
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        expect(rejections, 1);
        if (row.$2) {
          await tester.tap(find.text('Approve'));
          await tester.pumpAndSettle();
          expect(approvals, 1);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
