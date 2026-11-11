// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neighbor_help/app.dart';
import 'package:neighbor_help/l10n/app_strings.dart';
import 'package:neighbor_help/screens/auth/login_screen.dart';
import 'package:neighbor_help/widgets/app_preferences_panel.dart';
import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  for (final previousLanguage in ['fil', 'ceb']) {
    testWidgets(
      'English overrides a saved $previousLanguage preference and device locale',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'preferred_language': previousLanguage,
        });
        tester.binding.platformDispatcher.localesTestValue = [
          Locale(previousLanguage),
        ];
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              final config =
                  const NeighborHelpApp().build(context) as MaterialApp;
              expect(config.locale, const Locale('en'));
              expect(config.supportedLocales, [const Locale('en')]);
              return MaterialApp(
                locale: config.locale,
                supportedLocales: config.supportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        Text(Localizations.localeOf(context).languageCode),
                        Text(context.tr('Prepare contract offer')),
                        Text(context.tr('Agreement review notice')),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('en'), findsOneWidget);
        expect(find.text('Prepare contract offer'), findsOneWidget);
        expect(
          find.text('Read the complete agreed document before accepting.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.translate), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'login retains its controls without a language selector at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1100);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            // Offline Ahem glyphs are wider than Inter in the existing login rows.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.65)),
              child: child!,
            ),
            home: const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.translate), findsNothing);
        expect(find.byTooltip('Language'), findsNothing);
        expect(find.text('Email'), findsWidgets);
        expect(find.text('Password'), findsWidgets);
        expect(find.text('Log in'), findsWidgets);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'preferences do not show language controls or leave an empty language card',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppPreferencesPanel())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsNothing);
      expect(find.byIcon(Icons.translate), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
