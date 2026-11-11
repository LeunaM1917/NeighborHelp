import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/figma_ui/marketing_service_catalog.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/notification.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/models/service_proposal.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_inbox_button.dart';
import 'package:neighbor_help/screens/provider/provider_service_form_screen.dart';
import 'package:neighbor_help/utils/service_certification_policy.dart';
import 'package:neighbor_help/widgets/service_proposal_dialogs.dart';
import 'support/ui_test_support.dart';

Map<String, dynamic> profileData({
  bool approved = true,
  String qualification = 'Masonry NC II',
  bool grant = true,
}) => {
  'userId': 'provider',
  'isVerified': true,
  'approvedCertificationIds': approved ? ['cert'] : [],
  'certificationHistory': [
    {
      'id': 'cert',
      'name': qualification,
      'provider': 'TESDA',
      'status': 'Approved',
      'url': 'gs://demo/certificates/provider/cert/proof.pdf',
      'certificationId': 'SYNTHETIC-ONLY',
      'expirationDate': '2099-01-01',
      'reviewedBy': 'admin',
      'reviewedAt': Timestamp.now(),
      'verificationSource': 'TESDA Registry of Certified Workers',
    },
  ],
  if (grant)
    'approvedServiceProposals': {
      'proposal': {
        'status': 'Approved',
        'serviceTitle': 'Garden Block Wall Repair',
        'category': 'Construction',
        'qualificationName': 'Masonry NC II',
        'certificationEntryId': 'old-cert',
        'reviewedBy': 'admin',
        'reviewedAt': Timestamp.now(),
      },
    },
};
ServiceListing customListing({String status = 'Approved'}) =>
    ServiceListing.fromFirestore('custom', {
      'providerId': 'provider',
      'serviceTitle': 'Garden Block Wall Repair',
      'category': 'Construction',
      'serviceProposalId': 'approved-proposal',
      'requiredQualification': 'Masonry NC II',
      'approvalStatus': status,
      'isActive': status == 'Approved',
      'estimatedPrice': 500,
      'estimatedDuration': '1–2 hours',
      'priceType': 'fixed',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  void resize(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  Future<void> open(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  test(
    'approved custom work requires its approved qualification; renewal may use a new certificate entry',
    () {
      bool matches(Map<String, dynamic> row) => hasMatchingServiceCertificate(
        ServiceProviderProfile.fromFirestore('provider', row),
        category: 'Construction',
        serviceTitle: 'Garden Block Wall Repair',
      );
      expect(matches(profileData()), true);
      expect(matches(profileData(grant: false)), false);
      expect(matches(profileData(approved: false)), false);
      expect(matches(profileData(qualification: 'Domestic Work NC II')), false);
      final category = MarketingServiceCatalog.categoryByName('Construction')!;
      expect(
        MarketingServiceCatalog.withApprovedProposals(category, [
          customListing(status: 'Draft'),
        ]).services.length,
        category.services.length,
      );
      final visible = MarketingServiceCatalog.withApprovedProposals(category, [
        customListing(),
        customListing(),
      ]);
      expect(
        visible.services
            .where((s) => s.name == 'Garden Block Wall Repair')
            .length,
        1,
      );
      expect(visible.services.last.providers, isEmpty);
    },
  );

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'provider proposal retains input after a server error at $width',
      (tester) async {
        resize(tester, width);
        var fail = true;
        Map<String, dynamic>? submitted;
        await open(
          tester,
          ServiceProposalForm(
            profile: ServiceProviderProfile.fromFirestore(
              'provider',
              profileData(),
            ),
            onSubmit: (data) async {
              submitted = data;
                if (fail) {
                throw StateError('Certificate expired during submission.');
                }
            },
          ),
        );
        await tester.enterText(
          field('Proposed service name'),
          'Garden Block Wall Repair',
        );
        await tester.enterText(
          field('Work covered and limitations'),
          'Repair agreed garden masonry blocks, excluding structural design.',
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Masonry NC II').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit proposal'));
        await tester.pumpAndSettle();
        expect(
          find.text('Certificate expired during submission.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(field('Proposed service name'))
              .controller!
              .text,
          'Garden Block Wall Repair',
        );
        fail = false;
        await tester.tap(find.text('Submit proposal'));
        await tester.pumpAndSettle();
        expect(submitted!['certificationEntryId'], 'cert');
        expect(submitted!.containsKey('status'), false);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testOnPlatform(
      'admin proposal review requires scope confirmation and records rejection feedback at $width',
      (tester) async {
        resize(tester, width);
        final proposal = ServiceProposal('test', {
          'serviceTitle': 'Garden Block Wall Repair',
          'category': 'Construction',
          'qualificationName': 'Masonry NC II',
          'providerName': 'Test Provider',
          'description': 'Repair agreed garden masonry blocks.',
        });
        Map<String, dynamic>? decision;
        await open(
          tester,
          ServiceProposalReviewDialog(
            proposal: proposal,
            onReview: (data) async => decision = data,
          ),
        );
        await tester.enterText(
          field('Review notes / rejection reason'),
          'Scope checked against the TESDA qualification.',
        );
        await tester.tap(find.text('Approve proposal'));
        await tester.pumpAndSettle();
        expect(decision, isNull);
        expect(
          find.textContaining('Confirm the certificate matches'),
          findsOneWidget,
        );
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Approve proposal'));
        await tester.pumpAndSettle();
        expect(decision!['scopeConfirmed'], true);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          field('Review notes / rejection reason'),
          'Describe the task boundaries more clearly.',
        );
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettle();
        expect(decision!['action'], 'reject');
        expect(decision!['scopeConfirmed'], false);
        expect(tester.takeException(), isNull);
      },
    );

    testOnPlatform(
      'approved custom listing keeps its reviewed category and title at $width',
      (tester) async {
        resize(tester, width);
        final user = AppUser.fromFirestore('provider', {
          'role': 'Provider',
          'accountStatus': 'Active',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: ProviderServiceFormScreen(
              appUser: user,
              existing: customListing(status: 'Draft'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('Approved category')).readOnly,
          true,
        );
        expect(
          tester.widget<TextField>(field('Service title *')).controller!.text,
          'Garden Block Wall Repair',
        );
        expect(
          tester.widget<TextField>(field('Service title *')).readOnly,
          true,
        );
        expect(
          find.textContaining('This proposal was approved for Masonry NC II'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform(
    'admin inbox opens certificate review rather than the campaign sender',
    (tester) async {
      resize(tester, 390);
      final note = AppNotification(
        notificationId: 'certificate',
        userId: 'admin',
        title: 'Certificate awaiting review',
        message: 'A certificate was submitted.',
        notificationType: 'Admin Activity',
        adminTab: 5,
        isRead: false,
        createdAt: Timestamp.now(),
      );
      var destination = -1;
      final read = <String>[];
      await open(
        tester,
        AdminInboxDialog(
          stream: Stream.value([note]),
          onRead: (n) async {
            read.add(n.notificationId);
          },
          onNavigate: (i) => destination = i,
        ),
      );
      expect(find.text('Certificate awaiting review'), findsOneWidget);
      await tester.tap(find.text('Certificate awaiting review'));
      await tester.pumpAndSettle();
      expect(read, ['certificate']);
      expect(destination, 5);
      expect(destination, isNot(10));
      expect(tester.takeException(), isNull);
    },
  );
}
