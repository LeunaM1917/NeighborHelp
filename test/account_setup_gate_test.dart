import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/user_role.dart';
import 'package:neighbor_help/screens/customer/customer_settings_screen.dart';
import 'package:neighbor_help/screens/provider/provider_overview_settings_screen.dart';
import 'package:neighbor_help/screens/provider/widgets/provider_profile_widgets.dart';
import 'package:neighbor_help/utils/account_setup_policy.dart';
import 'package:neighbor_help/widgets/account_setup_gate.dart';
import 'support/ui_test_support.dart';

AppUser user({
  bool complete = true,
  String role = 'Customer',
  bool verified = false,
  String decision = '',
  String status = 'Pending',
}) => AppUser.fromFirestore('new-user', {
  'fullName': 'New Member',
  'email': 'member@example.test',
  'role': role,
  'contactNumber': complete ? '09123456789' : null,
  'address': complete ? 'New Visayas, Panabo City' : null,
  'isVerified': verified,
  'verificationStatus': status,
  'diditStatus': decision,
  'verificationProvider': decision.isNotEmpty ? 'idanalyzer' : '',
});
ServiceProviderProfile profile({
  bool complete = true,
  bool verified = false,
  String decision = '',
}) => ServiceProviderProfile.fromFirestore('new-user', {
  'userId': 'new-user',
  'isVerified': verified,
  'diditStatus': decision,
  'verificationProvider': decision.isNotEmpty ? 'idanalyzer' : '',
  if (complete) 'baseBarangayId': '1102315026',
  'serviceBarangayIds': complete ? ['1102315026'] : <String>[],
});

Future<void> mount(
  WidgetTester tester,
  AppUser value, {
  double width = 390,
  Stream<ServiceProviderProfile?>? profiles,
  Future<void> Function()? edit,
  Future<void> Function()? refresh,
  Future<void> Function()? signOut,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  await tester.pumpWidget(
    MaterialApp(
      home: AccountSetupGate(
        appUser: value,
        role: value.role,
        providerProfiles: profiles,
        onEditProfile: edit ?? () async {},
        onRefresh: refresh ?? () async {},
        onSignOut: signOut ?? () async {},
        child: const Scaffold(body: Text('Dashboard unlocked')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  testOnPlatform(
    'administrator accounts are outside customer and provider setup',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, user(role: 'Administrator', complete: false));
      expect(find.text('Dashboard unlocked'), findsOneWidget);
      expect(find.text('Complete your account setup'), findsNothing);
    },
  );

  testOnPlatform(
    'failed provider profile load stays blocked and can be retried',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profiles = StreamController<ServiceProviderProfile?>();
      addTearDown(profiles.close);
      profiles.addError(StateError('offline'));
      await mount(
        tester,
        user(role: 'Provider'),
        profiles: profiles.stream,
        refresh: () async {
          profiles.add(profile(verified: true));
        },
      );
      expect(find.text('Dashboard unlocked'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard unlocked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'required details exclude optional profile score and private provider GPS',
    () {
      expect(missingAccountDetails(user(), role: UserRole.customer), isEmpty);
      expect(
        missingAccountDetails(user(complete: false), role: UserRole.customer),
        ['Valid phone number', 'Address or barangay and city'],
      );
      expect(
        missingAccountDetails(
          user(role: 'Provider'),
          role: UserRole.provider,
          profile: profile(),
        ),
        isEmpty,
      );
      expect(
        missingAccountDetails(
          user(role: 'Provider'),
          role: UserRole.provider,
          profile: profile(complete: false),
        ),
        ['Home barangay', 'Service barangays'],
      );
      expect(validAccountPhone('+63 (912) 345-6789'), isTrue);
      expect(validAccountPhone('123'), isFalse);
      expect(validAccountPhone('not a phone'), isFalse);
    },
  );

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'new customer must finish details and KYC before dashboard at $width',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var edits = 0;
        await mount(
          tester,
          user(complete: false),
          width: width,
          edit: () async {
            edits++;
          },
        );
        expect(find.text('Complete your account setup'), findsOneWidget);
        expect(find.text('Dashboard unlocked'), findsNothing);
        expect(find.byType(ProviderVerifyIdentityButton), findsNothing);
        await tester.tap(find.text('Complete profile'));
        await tester.pumpAndSettle();
        expect(edits, 1);
        await mount(tester, user(), width: width);
        expect(find.byType(ProviderVerifyIdentityButton), findsOneWidget);
        expect(find.text('Dashboard unlocked'), findsNothing);
        await mount(tester, user(decision: 'Approved'), width: width);
        expect(
          find.textContaining('Awaiting System Administrator approval'),
          findsOneWidget,
        );
        expect(find.byType(ProviderVerifyIdentityButton), findsNothing);
        expect(find.text('Dashboard unlocked'), findsNothing);
        await mount(tester, user(verified: true), width: width);
        expect(find.text('Dashboard unlocked'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final decision in ['Declined', 'In Review', 'In Progress']) {
    testOnPlatform(
      '$decision does not grant access and shows the appropriate action',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester, user(decision: decision));
        expect(find.text('Dashboard unlocked'), findsNothing);
        final buttons = find.byType(ProviderVerifyIdentityButton);
        if (decision == 'In Review') {
          expect(buttons, findsNothing);
          expect(find.textContaining('under review'), findsOneWidget);
        } else {
          final button = tester.widget<ProviderVerifyIdentityButton>(buttons);
          expect(button.declined, decision == 'Declined');
          expect(button.restartFromIdPicker, decision == 'In Progress');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform(
    'KYC approval cannot bypass missing profile details after sign-in',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, user(complete: false, verified: true));
      expect(find.text('Dashboard unlocked'), findsNothing);
      expect(find.textContaining('Identity verified'), findsOneWidget);
      expect(find.text('Complete profile'), findsOneWidget);
    },
  );

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'provider unlocks only after barangay setup and approved KYC at $width',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profiles = StreamController<ServiceProviderProfile?>();
        addTearDown(profiles.close);
        profiles.add(profile(complete: false, verified: true));
        await mount(
          tester,
          user(role: 'Provider'),
          width: width,
          profiles: profiles.stream,
        );
        expect(find.text('Complete profile'), findsOneWidget);
        expect(find.text('Dashboard unlocked'), findsNothing);
        profiles.add(profile(decision: 'Approved'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Awaiting System Administrator approval'),
          findsOneWidget,
        );
        expect(find.text('Dashboard unlocked'), findsNothing);
        profiles.add(profile(verified: true));
        await tester.pumpAndSettle();
        expect(find.text('Dashboard unlocked'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform('refresh failure offers a popup and leaves sign-out usable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var signedOut = false;
    await mount(
      tester,
      user(decision: 'Approved'),
      refresh: () async {
        throw StateError('offline');
      },
      signOut: () async {
        signedOut = true;
      },
    );
    await tester.ensureVisible(find.text('Refresh verification status'));
    await tester.tap(find.text('Refresh verification status'));
    await tester.pumpAndSettle();
    expect(find.text('Could not update account setup'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
    expect(find.text('Dashboard unlocked'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testOnPlatform(
    'setup profile editor validates phone and address before saving',
    (tester) async {
      for (final provider in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: provider
                ? ProviderOverviewSettingsScreen(
                    appUser: user(role: 'Provider', complete: false),
                    profile: profile(),
                    requireAccountDetails: true,
                  )
                : CustomerSettingsScreen(
                    appUser: user(complete: false),
                    requireAccountDetails: true,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final form = tester.state<FormState>(find.byType(Form).first);
        form.validate();
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a valid phone number, such as 09123456789'),
          findsOneWidget,
        );
        if (!provider) {
          expect(
            find.text('Enter your barangay and city or address'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
