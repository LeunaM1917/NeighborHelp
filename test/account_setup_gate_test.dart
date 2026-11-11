import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/models/user_role.dart';
import 'package:neighbor_help/screens/provider/widgets/provider_profile_widgets.dart';
import 'package:neighbor_help/utils/account_setup_policy.dart';
import 'package:neighbor_help/widgets/account_setup_gate.dart';
import 'support/ui_test_support.dart';

AccountSetupStatus status({
  bool provider = false,
  bool complete = true,
  bool verified = false,
  String decision = '',
}) => AccountSetupStatus(
  role: provider ? UserRole.provider : UserRole.customer,
  user: AppUser.fromFirestore('new-user', {
    'fullName': 'New Member',
    'role': provider ? 'Provider' : 'Customer',
    'accountStatus': 'Active',
    'contactNumber': complete ? '09123456789' : null,
    'address': complete ? 'House 12, New Visayas, Panabo City' : null,
    'isVerified': verified,
    'diditStatus': decision,
    'verificationProvider': decision.isEmpty ? '' : 'idanalyzer',
  }),
  profile: provider
      ? ServiceProviderProfile.fromFirestore('new-user', {
          'userId': 'new-user',
          'isVerified': verified,
          'diditStatus': decision,
          'verificationProvider': decision.isEmpty ? '' : 'idanalyzer',
          if (complete) 'baseBarangayId': '1102315026',
          'serviceBarangayIds': complete ? ['1102315026'] : <String>[],
        })
      : null,
);

Future<void> home(
  WidgetTester tester, {
  required AccountSetupStatus initial,
  required AccountSetupLoader load,
  required VoidCallback onAllowed,
  Future<void> Function()? edit,
  Future<void> Function()? refresh,
  double width = 390,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('Browse services'),
              TextButton(
                onPressed: () async {
                  final ready = await requireAccountSetup(
                    context,
                    appUser: initial.user,
                    action: initial.role == UserRole.provider
                        ? 'list a service'
                        : 'book a service',
                    loadStatus: load,
                    editProfile: edit,
                    refreshVerification: refresh,
                  );
                  if (ready) onAllowed();
                },
                child: Text(
                  initial.role == UserRole.provider
                      ? 'Add your service'
                      : 'Book service',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  test('only required details and approved KYC qualify actions', () {
    expect(status(complete: false).missing, [
      'Valid phone number',
      'Address or barangay and city',
    ]);
    expect(status(provider: true, complete: false).missing, [
      'Valid phone number',
      'Home barangay',
      'Service barangays',
    ]);
    expect(status(verified: true).ready, true);
    expect(status(complete: false, verified: true).ready, false);
    expect(status(provider: true, verified: true).ready, true);
    expect(status().ready, false);
    expect(validAccountPhone('+63 (912) 345-6789'), true);
    expect(validAccountPhone('abc'), false);
  });
  for (final provider in [false, true]) {
    for (final width in [390.0, 1280.0]) {
      testOnPlatform(
        'browse freely and dismiss setup at $width (provider: $provider)',
        (tester) async {
          final current = status(provider: provider, complete: false);
          var actions = 0;
          await home(
            tester,
            initial: current,
            load: () async => current,
            onAllowed: () => actions++,
            width: width,
          );
          expect(find.text('Browse services'), findsOneWidget);
          expect(find.byType(AccountSetupDialog), findsNothing);
          await tester.tap(
            find.text(provider ? 'Add your service' : 'Book service'),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccountSetupDialog), findsOneWidget);
          expect(find.text('Complete profile'), findsOneWidget);
          expect(find.byType(ProviderVerifyIdentityButton), findsNothing);
          expect(actions, 0);
          await tester.tap(find.text('Keep browsing'));
          await tester.pumpAndSettle();
          expect(find.byType(AccountSetupDialog), findsNothing);
          expect(find.text('Browse services'), findsOneWidget);
          expect(actions, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testOnPlatform(
      'complete profile then refresh approval to continue (provider: $provider)',
      (tester) async {
        var current = status(provider: provider, complete: false);
        var actions = 0;
        await home(
          tester,
          initial: current,
          load: () async => current,
          onAllowed: () => actions++,
          edit: () async {
            current = status(provider: provider);
          },
          refresh: () async {
            current = status(provider: provider, verified: true);
          },
        );
        await tester.tap(
          find.text(provider ? 'Add your service' : 'Book service'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Complete profile'));
        await tester.pumpAndSettle();
        expect(find.byType(ProviderVerifyIdentityButton), findsOneWidget);
        expect(actions, 0);
        await tester.ensureVisible(find.text('Refresh status'));
        await tester.tap(find.text('Refresh status'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(actions, 1);
        expect(find.byType(AccountSetupDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final decision in ['Approved', 'In Review', 'Declined', 'In Progress']) {
    testOnPlatform(
      '$decision without platform approval still blocks only the action',
      (tester) async {
        final current = status(decision: decision);
        var actions = 0;
        await home(
          tester,
          initial: current,
          load: () async => current,
          onAllowed: () => actions++,
        );
        await tester.tap(find.text('Book service'));
        await tester.pumpAndSettle();
        expect(find.byType(AccountSetupDialog), findsOneWidget);
        expect(find.text('Continue'), findsNothing);
        expect(actions, 0);
        if (decision == 'Approved' || decision == 'In Review') {
          expect(find.byType(ProviderVerifyIdentityButton), findsNothing);
        } else {
          final button = tester.widget<ProviderVerifyIdentityButton>(
            find.byType(ProviderVerifyIdentityButton),
          );
          expect(button.declined, decision == 'Declined');
          expect(button.restartFromIdPicker, decision == 'In Progress');
        }
        await tester.tap(find.text('Keep browsing'));
        await tester.pumpAndSettle();
        expect(find.text('Browse services'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testOnPlatform(
    'loading failures allow browsing and a successful fresh retry',
    (tester) async {
      var fail = true, actions = 0;
      await home(
        tester,
        initial: status(),
        load: () async {
          if (fail) throw StateError('offline');
          return status(verified: true);
        },
        onAllowed: () => actions++,
      );
      await tester.tap(find.text('Book service'));
      await tester.pumpAndSettle();
      expect(find.text('Could not check account setup'), findsOneWidget);
      expect(actions, 0);
      await tester.tap(find.text('Keep browsing'));
      await tester.pumpAndSettle();
      fail = false;
      await tester.tap(find.text('Book service'));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(find.byType(AccountSetupDialog), findsNothing);
    },
  );
  testOnPlatform(
    'duplicate clicks cannot create duplicate dialogs or actions',
    (tester) async {
      final pending = Completer<AccountSetupStatus>();
      var reads = 0, actions = 0;
      await home(
        tester,
        initial: status(),
        load: () {
          reads++;
          return pending.future;
        },
        onAllowed: () => actions++,
      );
      await tester.tap(find.text('Book service'));
      await tester.tap(find.text('Book service'));
      expect(reads, 1);
      pending.complete(status(verified: true));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
