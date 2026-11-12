import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/screens/provider/provider_service_form_screen.dart';
import 'package:neighbor_help/services/firestore_service.dart';
import 'support/ui_test_support.dart';

class ServiceFormStore extends Fake implements FirestoreService {
  final writes = <Map<String, dynamic>>[];
  @override
  String newServiceId() => 'new-listing';
  @override
  Future<List<Map<String, dynamic>>> approvedServiceOptions() async => [
    {'category': 'Home Care', 'serviceTitle': 'Upholstery Cleaning'},
  ];
  @override
  Future<AppUser?> getUserForAccountSetup(String id) async =>
      AppUser.fromFirestore(id, {
        'fullName': 'Test Provider',
        'role': 'Provider',
        'accountStatus': 'Active',
        'contactNumber': '09123456789',
      });
  @override
  Future<ServiceProviderProfile?> getProviderProfileForListing(
    String id,
  ) async => ServiceProviderProfile.fromFirestore(id, {
    'userId': id,
    'isVerified': true,
    'baseBarangayId': '1102315026',
    'serviceBarangayIds': ['1102315026'],
    'approvedCertificationIds': ['cert'],
    'certificationHistory': [
      {
        'id': 'cert',
        'name': 'Domestic Work NC II',
        'provider': 'TESDA',
        'status': 'Approved',
        'expirationDate': '2099-01-01',
        'reviewedBy': 'admin',
        'reviewedAt': Timestamp.now(),
        'certificationId': 'TEST-ONLY',
        'url': 'gs://demo/certificate.pdf',
        'verificationSource': 'TESDA Registry of Certified Workers',
      },
    ],
  });
  @override
  Future<void> updateService(String id, Map<String, dynamic> data) async =>
      writes.add({'serviceId': id, ...data});
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<void> openForm(
  WidgetTester tester,
  ServiceFormStore store,
  double width, {
  ServiceListing? existing,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
                    'accountStatus': 'Active',
                  }),
                  firestore: store,
                  existing: existing,
                ),
              ),
            ),
            child: const Text('Open form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open form'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'custom category and service save directly as an incomplete private draft at $width',
      (tester) async {
        final store = ServiceFormStore();
        await openForm(tester, store, width);
        await tester.tap(find.byType(DropdownMenu<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Category').last);
        await tester.pumpAndSettle();
        await tester.enterText(field('Category name'), 'Garden Maintenance');
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('+ Add Service'));
        await tester.tap(find.text('+ Add Service'));
        await tester.pumpAndSettle();
        await tester.enterText(
          field('Service name'),
          'Garden Furniture Cleaning',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('Service title *')).controller!.text,
          'Garden Furniture Cleaning',
        );
        expect(find.text('Live preview'), findsOneWidget);
        await tester.tap(find.text('Save as draft'));
        await tester.pumpAndSettle();
        expect(store.writes.single, containsPair('approvalStatus', 'Draft'));
        expect(store.writes.single, containsPair('isActive', false));
        expect(
          store.writes.single,
          containsPair('category', 'Garden Maintenance'),
        );
        expect(store.writes.single['serviceImages'], isEmpty);
        expect(find.text('Open form'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testOnPlatform(
      'approved custom catalog entries are selectable and category cancellation retains the current selection at $width',
      (tester) async {
        final store = ServiceFormStore();
        await openForm(tester, store, width);
        await tester.tap(find.byType(DropdownMenu<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Home Care').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Upholstery Cleaning'));
        await tester.tap(find.text('Upholstery Cleaning'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('Service title *')).controller!.text,
          'Upholstery Cleaning',
        );
        await tester.ensureVisible(find.byType(DropdownMenu<String>));
        await tester.tap(find.byType(DropdownMenu<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add Category').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save as draft'));
        await tester.pumpAndSettle();
        expect(store.writes.single, containsPair('category', 'Home Care'));
        expect(
          store.writes.single,
          containsPair('serviceTitle', 'Upholstery Cleaning'),
        );
        expect(tester.takeException(), isNull);
      },
    );
    testOnPlatform(
      'fewer than three photos block submission but allow a draft at $width',
      (tester) async {
        final store = ServiceFormStore();
        await openForm(
          tester,
          store,
          width,
          existing: ServiceListing.fromFirestore('listing', {
            'providerId': 'provider',
            'category': 'Cleaning',
            'serviceTitle': 'House Cleaning',
            'description': 'Clean agreed rooms and surfaces.',
            'estimatedPrice': 300,
            'priceType': 'hourly',
            'estimatedDuration': '1 hour',
            'serviceImages': [
              'https://example.test/one.png',
              'https://example.test/two.png',
              'https://example.test/three.png',
            ],
            'approvalStatus': 'Draft',
            'certificationEntryId': 'cert',
          }),
        );
        await tester.ensureVisible(find.byTooltip('Remove photo').first);
        await tester.tap(find.byTooltip('Remove photo').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit for approval'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Add at least 3 service photos before submitting for approval.',
          ),
          findsWidgets,
        );
        expect(store.writes, isEmpty);
        await tester.tap(find.text('Save as draft'));
        await tester.pumpAndSettle();
        expect(store.writes.single, containsPair('approvalStatus', 'Draft'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
