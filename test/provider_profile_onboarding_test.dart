import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/screens/provider/provider_certification_dialog.dart';
import 'package:neighbor_help/screens/provider/provider_education_dialog.dart';
import 'package:neighbor_help/screens/provider/provider_employment_dialog.dart';
import 'package:neighbor_help/screens/provider/provider_overview_settings_screen.dart';
import 'package:neighbor_help/screens/provider/provider_portfolio_flow.dart';
import 'package:neighbor_help/screens/provider/provider_profile_completion.dart';
import 'package:neighbor_help/screens/provider/provider_profile_editor_dialog.dart';
import 'package:neighbor_help/screens/provider/provider_profile_section_dialogs.dart';
import 'package:neighbor_help/theme/app_theme.dart';
import 'package:neighbor_help/services/provider_onboarding.dart';
import 'support/ui_test_support.dart';

final member = AppUser.fromFirestore('provider', {
  'role': 'Provider',
  'fullName': 'Test Provider',
  'email': 'test@example.test',
  'accountStatus': 'Active',
});
ServiceProviderProfile profile({bool overviewDone = false}) =>
    ServiceProviderProfile.fromFirestore('provider', {
      'userId': 'provider',
      'bio': overviewDone
          ? 'Experienced local household service provider.'
          : '',
    });

void main() {
  setUpOfflineFonts();
  testOnPlatform(
    'new provider signup opens the checklist once, after its profile is ready',
    (tester) async {
      ProviderOnboarding.mark('provider');
      Widget screen(ServiceProviderProfile? current) => MaterialApp(
        theme: neighborHelpTheme(),
        home: Scaffold(
          body: ProviderOnboardingPrompt(
            data: ProviderProfileCompletionData(
              appUser: member,
              profile: current,
              services: [],
              reviewCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(null));
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsNothing);
      await tester.pumpWidget(screen(profile()));
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsOneWidget);
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsNothing);
      await tester.pumpWidget(screen(profile()));
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsNothing);
    },
  );
  for (final width in [360.0, 1280.0]) {
    testOnPlatform(
      'closing a checklist editor returns to the checklist at $width and updates progress',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: neighborHelpTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showProviderProfileCompletionDialog(
                    context,
                    appUser: member,
                    profile: profile(),
                    services: [],
                    reviewCount: 0,
                    onRequirementTap: (_) => ProviderEducationDialog.open(
                      context,
                      providerId: 'provider',
                    ),
                    reload: () async => ProviderProfileCompletionData(
                      appUser: member,
                      profile: profile(overviewDone: true),
                      services: [],
                      reviewCount: 0,
                    ),
                  ),
                  child: const Text('Open checklist'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open checklist'));
        await tester.pumpAndSettle();
        expect(find.text('Complete your profile'), findsOneWidget);
        final overview = find.text('Overview');
        await tester.ensureVisible(overview);
        await tester.tap(overview);
        await tester.pumpAndSettle();
        expect(find.text('Add education'), findsOneWidget);
        expect(
          find.byKey(ProviderProfileEditorDialog.closeKey),
          findsOneWidget,
        );
        await tester.tap(find.byKey(ProviderProfileEditorDialog.closeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(ProviderProfileEditorDialog.closeKey), findsNothing);
        await tester.drag(find.byType(ListView).first, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text('Complete your profile'), findsOneWidget);
        expect(find.text('12% complete'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testOnPlatform(
      'every profile editor has the same sticky X and fits at $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final editors = <Future<bool?> Function(BuildContext)>[
          (c) => ProviderOverviewSettingsScreen.open(
            c,
            appUser: member,
            profile: profile(),
          ),
          (c) => ProviderEducationDialog.open(c, providerId: 'provider'),
          (c) => ProviderEmploymentDialog.open(c, providerId: 'provider'),
          (c) => ProviderPortfolioFlow.open(c, providerId: 'provider'),
          (c) => ProviderCertificationDialog.open(c, providerId: 'provider'),
          (c) => ProviderOtherExperiencesDialog.open(
            c,
            providerId: 'provider',
            initialLines: [],
          ),
          (c) => ProviderLinkedAccountsDialog.open(
            c,
            providerId: 'provider',
            initial: {},
          ),
        ];
        for (var editorIndex = 0; editorIndex < editors.length; editorIndex++) {
          final editor = editors[editorIndex];
          await tester.pumpWidget(
            MaterialApp(
              theme: neighborHelpTheme(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => editor(context),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Edit'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(ProviderProfileEditorDialog.closeKey),
            findsOneWidget,
          );
          final surface = tester.getRect(
            find.byKey(ProviderProfileEditorDialog.surfaceKey),
          );
          final close = tester.getRect(
            find.byKey(ProviderProfileEditorDialog.closeKey),
          );
          expect(close.top - surface.top, 8);
          expect(surface.right - close.right, 8);
          expect(surface.width, lessThanOrEqualTo(width - 32));
          expect(tester.takeException(), isNull, reason: 'editor $editorIndex');
          // Scrolling a long editor never scrolls its close control away.
          final scrolls = find.byType(SingleChildScrollView);
          if (scrolls.evaluate().isNotEmpty) {
            await tester.drag(scrolls.first, const Offset(0, -250));
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(ProviderProfileEditorDialog.closeKey)),
              close,
            );
          }
          await tester.tap(find.byKey(ProviderProfileEditorDialog.closeKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'editor $editorIndex');
        }
      },
    );
  }
}
