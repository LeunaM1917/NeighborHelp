import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/screens/customer/customer_service_detail_screen.dart';
import 'package:neighbor_help/theme/role_theme.dart';
import 'support/ui_test_support.dart';

void main() {
  setUpOfflineFonts();
  test('hourly listing rates survive parsing and editing', () {
    for (final value in ['hourly', 'Hourly', 'HOURLY']) {
      final service = ServiceListing.fromFirestore('s', {
        'priceType': value,
        'estimatedPrice': 125.5,
      });
      expect(service.priceType, 'hourly');
      expect(service.toMap()['priceType'], 'hourly');
      expect(service.estimatedPrice, 125.5);
    }
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'direct booking form supports hourly and fixed requests at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final location = TextEditingController(
          text: 'New Visayas, Panabo City',
        );
        final notes = TextEditingController();
        final fixed = TextEditingController(text: '500');
        addTearDown(location.dispose);
        addTearDown(notes.dispose);
        addTearDown(fixed.dispose);
        var mode = BookingPricingMode.hourly;
        var hours = 2.0;
        var sent = 0;
        var fixedChanged = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RoleThemeScope(
                palette: RoleTheme.customer,
                child: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, update) => BookingRequestPanel(
                      listing: ServiceListing.fromFirestore('s', {
                        'estimatedPrice': 100,
                      }),
                      location: location,
                      locationPicker: const Text('Service location confirmed'),
                      notes: notes,
                      fixedPrice: fixed,
                      preferredDate: DateTime(2026, 12, 1),
                      preferredTime: const TimeOfDay(hour: 9, minute: 0),
                      pricingMode: mode,
                      durationHours: hours,
                      hourlyRate: 100,
                      estimatedTotal: mode == BookingPricingMode.hourly
                          ? 100 * hours
                          : double.parse(fixed.text),
                      onPickDate: () {},
                      onPickTime: () {},
                      onPricingModeChanged: (value) =>
                          update(() => mode = value),
                      onDurationChanged: (value) => update(() => hours = value),
                      onFixedPriceChanged: () => fixedChanged++,
                      onSubmit: () => sent++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Booking request'), findsOneWidget);
        expect(
          find.textContaining('contract', findRichText: true),
          findsNothing,
        );
        expect(find.byType(CheckboxListTile), findsNothing);
        final send = find.text('Send booking request');
        await tester.ensureVisible(send);
        await tester.tap(send);
        expect(sent, 1);
        await tester.ensureVisible(find.text('Fixed rate'));
        await tester.tap(find.text('Fixed rate'));
        await tester.pumpAndSettle();
        expect(mode, BookingPricingMode.fixed);
        final price = find.byWidgetPredicate(
          (w) => w is TextField && w.controller == fixed,
        );
        await tester.ensureVisible(price);
        await tester.enterText(price, '750.25');
        expect(fixedChanged, 1);
        await tester.ensureVisible(send);
        await tester.tap(send);
        expect(sent, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
