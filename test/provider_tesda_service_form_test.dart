import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/screens/provider/provider_service_form_screen.dart';

import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'provider can choose masonry and see its certificate requirement at $width',
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
        await tester.tap(find.text('Construction').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Masonry'));
        await tester.tap(find.text('Masonry'));
        await tester.pumpAndSettle();
        final fields = tester.widgetList<TextField>(
          find.byType(TextField),
        );
        expect(
          fields
              .firstWhere((w) => w.decoration?.labelText == 'Service title *')
              .controller!
              .text,
          'Masonry',
        );
        expect(
          fields
              .firstWhere(
                (w) => w.decoration?.labelText?.startsWith('Price (') == true,
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(find.textContaining('Requires Masonry NC II'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
