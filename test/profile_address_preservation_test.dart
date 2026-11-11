import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/screens/customer/customer_settings_screen.dart';
import 'package:neighbor_help/services/firestore_service.dart';
import 'package:neighbor_help/widgets/member_profile/member_profile_kit.dart';
import 'package:neighbor_help/widgets/profile_location_editor.dart';
import 'package:neighbor_help/widgets/service_location_picker.dart';
import 'support/ui_test_support.dart';

const fullAddress =
    'House 12-A, Purok 3, New Visayas, Panabo City, Davao del Norte';

class ProfileStore implements FirestoreService {
  Map<String, dynamic> data = {
    'fullName': 'Test Customer',
    'role': 'Customer',
    'accountStatus': 'Active',
    'contactNumber': '09123456789',
    'address': 'Panabo City, Davao del Norte',
  };
  int saves = 0;
  @override
  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    this.data.addAll(data);
    saves++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  testWidgets(
    'profile geocoding keeps house and street details when Google returns only the city',
    (tester) async {
      final address = TextEditingController(text: fullAddress);
      addTearDown(address.dispose);
      GeoPoint? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceLocationPicker(
              address: address,
              preserveAddressText: true,
              onSelected: (p) => selected = p,
              lookupAddress: (input) async {
                expect(input, fullAddress);
                return {
                  'address': 'Panabo City, Davao del Norte',
                  'latitude': 7.3,
                  'longitude': 125.6,
                };
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Locate address'));
      await tester.pumpAndSettle();
      expect(address.text, fullAddress);
      expect(selected, const GeoPoint(7.3, 125.6));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a stale map lookup cannot replace an address edited during the request',
    (tester) async {
      final address = TextEditingController(text: fullAddress);
      addTearDown(address.dispose);
      final result = Completer<Map<String, dynamic>>();
      var selections = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceLocationPicker(
              address: address,
              onSelected: (_) => selections++,
              lookupAddress: (_) => result.future,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Locate address'));
      await tester.pump();
      address.text = 'House 42, Cacao, Panabo City';
      result.complete({
        'address': 'Panabo City',
        'latitude': 7.3,
        'longitude': 125.6,
      });
      await tester.pumpAndSettle();
      expect(address.text, 'House 42, Cacao, Panabo City');
      expect(selections, 0);
    },
  );
  testOnPlatform(
    'saving and reopening a customer profile retains the full address',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ProfileStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomerSettingsScreen(
                      appUser: AppUser.fromFirestore('customer', store.data),
                      firestore: store,
                    ),
                  ),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.controller?.text == 'Panabo City, Davao del Norte',
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, fullAddress);
      expect(
        tester
            .widget<ServiceLocationPicker>(find.byType(ServiceLocationPicker))
            .preserveAddressText,
        true,
      );
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(store.saves, 1);
      expect(store.data['address'], fullAddress);
      expect(
        memberProfileLocation(AppUser.fromFirestore('customer', store.data)),
        fullAddress,
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text(fullAddress), findsOneWidget);
      expect(find.byType(ProfileLocationEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'empty profiles do not pretend that a complete city address was supplied',
    () {
      expect(
        memberProfileLocation(AppUser.fromFirestore('new', {})),
        'Location not provided',
      );
    },
  );
}
