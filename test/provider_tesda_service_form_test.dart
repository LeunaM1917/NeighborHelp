import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/screens/provider/provider_service_form_screen.dart';

import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  for (final service in [
    ('Plumbing Repair', 'Plumbing NC II', '380'),
    (
      'Electrical Repair',
      'Electrical Installation and Maintenance NC II',
      '400',
    ),
  ]) {
    for (final width in [390.0, 1280.0]) {
      testOnPlatform(
        'provider can choose ${service.$1} and see its certificate requirement at $width',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1100);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final provider = AppUser.fromFirestore('provider', {
            'role': 'Provider',
            'accountStatus': 'Active',
          });
          await tester.pumpWidget(
            MaterialApp(home: ProviderServiceFormScreen(appUser: provider)),
          );
          await tester.pumpAndSettle();
          expect(find.text('Add your service'), findsOneWidget);
          expect(find.text('Choose a TESDA-aligned service'), findsOneWidget);
          await tester.tap(find.byType(DropdownMenu<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Repair and Technical Services').last);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(service.$1));
          await tester.tap(find.text(service.$1));
          await tester.pumpAndSettle();
          final fields = tester.widgetList<TextField>(find.byType(TextField));
          expect(
            fields
                .firstWhere((w) => w.decoration?.labelText == 'Service title *')
                .controller!
                .text,
            service.$1,
          );
          expect(
            fields
                .firstWhere(
                  (w) => w.decoration?.labelText?.startsWith('Price (') == true,
                )
                .controller!
                .text,
            service.$3,
          );
          expect(find.textContaining('Requires ${service.$2}'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
