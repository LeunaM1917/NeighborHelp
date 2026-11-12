import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/provider_certification.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/screens/provider/provider_certification_dialog.dart';
import 'package:neighbor_help/screens/provider/provider_service_form_screen.dart';
import 'package:neighbor_help/services/firestore_service.dart';
import 'package:neighbor_help/utils/service_certification_policy.dart';
import 'package:neighbor_help/ui/app_notification_dialog.dart';

import 'support/ui_test_support.dart';

ServiceProviderProfile profile({
  String? status,
  String expiry = '2099-01-01',
  String qualification = 'Masonry NC II',
  bool approved = true,
  bool verified = true,
}) => ServiceProviderProfile.fromFirestore('provider', {
  'userId': 'provider',
  'isVerified': verified,
  'baseBarangayId': '1102315026',
  'serviceBarangayIds': ['1102315026'],
  'approvedCertificationIds': approved ? ['cert'] : <String>[],
  'certificationHistory': [
    if (status != null)
      {
        'id': 'cert',
        'name': qualification,
        'provider': 'TESDA',
        'status': status,
        'certificationId': 'TEST-001',
        'url': 'gs://demo/proof.pdf',
        'expirationDate': expiry,
        'reviewedBy': 'admin',
        'reviewedAt': Timestamp.now(),
        'verificationSource': 'TESDA Registry of Certified Workers',
      },
  ],
});

class ListingStore implements FirestoreService {
  ListingStore(this.profile);
  ServiceProviderProfile profile;
  bool failRead = false;
  bool failSave = false;
  int reads = 0;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<AppUser?> getUserForAccountSetup(String userId) async =>
      AppUser.fromFirestore(userId, {
        'fullName': 'Test Provider',
        'role': 'Provider',
        'accountStatus': 'Active',
        'contactNumber': '09123456789',
      });
  @override
  Future<ServiceProviderProfile?> getProviderProfileForListing(
    String userId,
  ) async {
    reads++;
    if (failRead) throw StateError('offline');
    return profile;
  }

  @override
  Future<void> updateService(
    String serviceId,
    Map<String, dynamic> data,
  ) async {
    if (failSave) throw StateError('offline');
    writes.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> openForm(
  WidgetTester tester,
  ListingStore store,
  double width,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final listing = ServiceListing.fromFirestore('listing', {
    'providerId': 'provider',
    'category': 'Construction',
    'serviceTitle': 'Masonry',
    'description': 'Masonry service description',
    'estimatedPrice': 500,
    'priceType': 'fixed',
    'estimatedDuration': '1–2 hours',
    'approvalStatus': 'Draft',
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ProviderServiceFormScreen(
                  appUser: AppUser.fromFirestore('provider', {
                    'role': 'Provider',
                  }),
                  existing: listing,
                  firestore: store,
                ),
              ),
            ),
            child: const Text('Open listing'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open listing'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  testOnPlatform(
    'certificate editor displays distinct issue and expiration dates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderCertificationDialog(
              providerId: 'provider',
              initial: const ProviderCertificationEntry(
                id: 'cert',
                name: 'Masonry NC II',
                issueDate: '2025-01-02',
                expirationDate: '2030-03-04',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(ProviderCertificationEntry.formatForPicker('2025-01-02')),
        findsOneWidget,
      );
      expect(
        find.text(ProviderCertificationEntry.formatForPicker('2030-03-04')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform('a provider without a certificate can retain a draft', (
    tester,
  ) async {
    final store = ListingStore(profile());
    await openForm(tester, store, 390);
    await tester.tap(find.text('Save as draft'));
    await tester.pumpAndSettle();
    expect(store.reads, 0);
    expect(store.writes, hasLength(1));
    expect(store.writes.single['isActive'], false);
    expect(find.text('Open listing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'feedback distinguishes strict eligibility and certificate review states',
    () {
      ServiceCertificateStatus check(ServiceProviderProfile p) =>
          serviceCertificateStatus(
            p,
            category: 'Construction',
            serviceTitle: 'Masonry',
          );
      expect(check(profile()), ServiceCertificateStatus.missing);
      expect(
        check(profile(status: 'Approved', qualification: 'Tile Setting NC II')),
        ServiceCertificateStatus.missing,
      );
      expect(
        check(profile(status: 'Pending')),
        ServiceCertificateStatus.pending,
      );
      expect(
        check(profile(status: 'Rejected')),
        ServiceCertificateStatus.rejected,
      );
      expect(
        check(profile(status: 'Approved', expiry: '2000-01-01')),
        ServiceCertificateStatus.expired,
      );
      expect(
        check(profile(status: 'Approved', approved: false)),
        ServiceCertificateStatus.needsReview,
      );
      expect(
        check(profile(status: 'Approved')),
        ServiceCertificateStatus.approved,
      );
    },
  );

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'closing a listing notice keeps the service form unchanged at $width',
      (tester) async {
        final store = ListingStore(profile());
        await openForm(tester, store, width);
        final before = tester.getSize(find.byType(ProviderServiceFormScreen));
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        final popup = find.byType(AppNotificationDialog);
        expect(popup, findsOneWidget);
        await tester.tap(
          find.descendant(of: popup, matching: find.byTooltip('Close')),
        );
        await tester.pumpAndSettle();
        expect(popup, findsNothing);
        expect(tester.getSize(find.byType(ProviderServiceFormScreen)), before);
        expect(find.text('Masonry service description'), findsWidgets);
        expect(store.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testOnPlatform(
      'missing certificate opens matching upload and preserves listing at $width',
      (tester) async {
        final store = ListingStore(profile());
        await openForm(tester, store, width);
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(find.text('Matching certificate required'), findsOneWidget);
        expect(
          find.textContaining('Masonry requires Masonry NC II'),
          findsOneWidget,
        );
        expect(store.writes, isEmpty);
        await tester.tap(find.text('Upload certificate'));
        await tester.pumpAndSettle();
        expect(find.byType(ProviderCertificationDialog), findsOneWidget);
        expect(find.text('Masonry NC II'), findsWidgets);
        expect(tester.takeException(), isNull);
        Navigator.of(
          tester.element(find.byType(ProviderCertificationDialog)),
        ).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ProviderServiceFormScreen), findsOneWidget);
        expect(find.text('Masonry service description'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final row in [
    ('Pending', '2099-01-01', 'Certificate awaiting review'),
    ('Rejected', '2099-01-01', 'Certificate rejected'),
    ('Approved', '2000-01-01', 'Certificate expired'),
  ]) {
    testOnPlatform('${row.$3} prevents submission and allows another attempt', (
      tester,
    ) async {
      final store = ListingStore(profile(status: row.$1, expiry: row.$2));
      await openForm(tester, store, 390);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text(row.$3), findsOneWidget);
      expect(
        find.text('Upload certificate'),
        row.$1 == 'Pending' ? findsNothing : findsOneWidget,
      );
      expect(store.writes, isEmpty);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      // Approval received while this form was open must be read on the next attempt.
      store.profile = profile(status: 'Approved');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.reads, 4);
      expect(store.writes.single['approvalStatus'], 'Pending');
      expect(store.writes.single['isActive'], false);
      expect(find.text('Open listing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testOnPlatform(
    'connection error releases submit button and retains the form',
    (tester) async {
      final store = ListingStore(profile(status: 'Approved'))..failRead = true;
      await openForm(tester, store, 390);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Could not check account setup'), findsOneWidget);
      await tester.tap(find.text('Keep browsing'));
      await tester.pumpAndSettle();
      store.failRead = false;
      store.failSave = true;
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Could not save service'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      store.failSave = false;
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.writes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform('matching certificate still requires verified identity', (
    tester,
  ) async {
    final store = ListingStore(profile(status: 'Approved', verified: false));
    await openForm(tester, store, 390);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Complete your profile and verification'), findsOneWidget);
    expect(store.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
