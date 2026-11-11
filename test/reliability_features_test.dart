import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  test('workflow English copy retains its labels and important notices', () {
    for (final row in messages.entries) {
      expect(row.value.trim(), isNotEmpty, reason: row.key);
    }
    const strings = AppStrings();
    expect(strings.text('Confirm work complete'), isNotEmpty);
    expect(
      strings.text('Payment record notice'),
      isNot('Payment record notice'),
    );
  });
  test('unknown English copy keys retain their original text', () {
    expect(const AppStrings().text('New workflow label'), 'New workflow label');
  });
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
  for (final width in [360.0, 1024.0]) {
    testWidgets(
      'English completion confirmation remains explicit at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final booking = Booking.fromFirestore('b', {
          'customerId': 'c',
          'providerId': 'p',
          'status': 'Awaiting Confirmation',
          'scheduledDate': Timestamp.now(),
        });
        const strings = AppStrings();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
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
