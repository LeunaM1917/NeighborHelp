import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neighbor_help/l10n/app_strings.dart';
import 'package:neighbor_help/l10n/messages.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/figma_ui/marketing_service_asset_paths.dart';
import 'package:neighbor_help/services/crash_reporting.dart';
import 'package:neighbor_help/widgets/work_completion_card.dart';

void main() {
  test(
    'diagnostic opt-out immediately stops app reporting and attempts all safeguards on failure',
    () async {
      CrashReporting.consent.value = true;
      final calls = <String>[];
      final result = CrashReporting.revokeConsent(
        savePreference: () async {
          calls.add('save');
          throw StateError('storage unavailable');
        },
        disableNative: () async {
          calls.add('disable');
        },
        deleteUnsent: () async {
          calls.add('delete');
        },
      );
      expect(CrashReporting.consent.value, isFalse);
      await expectLater(result, throwsStateError);
      expect(calls, containsAll(['save', 'disable', 'delete']));
    },
  );
  test(
    'workflow translations cover the same nonempty strings in all three languages',
    () {
      for (final row in messages.entries) {
        expect(row.value, hasLength(3), reason: row.key);
        for (final value in row.value) {
          expect(value.trim(), isNotEmpty, reason: row.key);
        }
      }
      for (final code in ['en', 'fil', 'ceb']) {
        final strings = AppStrings(code);
        expect(strings.text('Confirm work complete'), isNotEmpty);
        expect(
          strings.text('Payment record notice'),
          isNot('Payment record notice'),
        );
      }
    },
  );
  test(
    'language preference survives reload and unsupported choices do not replace it',
    () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences.instance.setLanguage('ceb');
      await AppPreferences.instance.load();
      expect(AppPreferences.instance.locale.languageCode, 'ceb');
      await AppPreferences.instance.setLanguage('unsupported');
      expect(AppPreferences.instance.locale.languageCode, 'ceb');
      await AppPreferences.instance.setLanguage('en');
    },
  );
  test(
    'bundled service thumbnails are local, small and exclude removed categories',
    () {
      var bytes = 0;
      for (final entry
          in MarketingServiceAssetPaths.byCategoryAndName.entries) {
        expect([
          'home_repair',
          'cleaning',
          'repair_technical',
          'handyman',
        ], contains(entry.key.split('|').first));
        expect(entry.value, startsWith('assets/optimized_services/'));
        final file = File(entry.value);
        expect(file.existsSync(), isTrue);
        bytes += file.lengthSync();
      }
      expect(bytes, lessThan(2 * 1024 * 1024));
      final manifest = File('pubspec.yaml').readAsStringSync();
      expect(manifest, contains('assets/optimized_services/'));
      expect(manifest, isNot(contains('assets/service_picture/')));
    },
  );
  test('app crash descriptions exclude sensitive exception contents', () {
    final safe = CrashReporting.safeDescription(
      StateError(
        'private chat, certificate number, address and payment reference',
      ),
    );
    expect(safe, isNot(contains('private chat')));
    expect(safe, isNot(contains('payment reference')));
    expect(CrashReporting.consent.value, isFalse);
  });
  for (final language in ['fil', 'ceb']) {
    testWidgets(
      'completion confirmation remains explicit in $language at a narrow width',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final booking = Booking.fromFirestore('b', {
          'customerId': 'c',
          'providerId': 'p',
          'status': 'Awaiting Confirmation',
          'scheduledDate': Timestamp.now(),
        });
        final strings = AppStrings(language);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [
              Locale('en'),
              Locale('fil'),
              Locale('ceb'),
            ],
            localizationsDelegates: const [
              AppStrings.delegate,
              MarketplaceMaterialDelegate(),
              MarketplaceWidgetsDelegate(),
              MarketplaceCupertinoDelegate(),
            ],
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkCompletionCard(booking: booking, asCustomer: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.text('Confirm work complete')));
        await tester.pumpAndSettle();
        expect(
          find.text(strings.text('Confirm deliverables complete')),
          findsOneWidget,
        );
        await tester.tap(find.text(strings.text('Back')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
