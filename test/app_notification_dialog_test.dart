import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/theme/app_theme.dart';
import 'package:neighbor_help/ui/app_notification_dialog.dart';
import 'support/ui_test_support.dart';

void main() {
  setUpOfflineFonts();
  for (final width in [320.0, 560.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'notifications keep one size and usable controls at $width / $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final draft = TextEditingController(text: 'Unsaved service details');
          addTearDown(draft.dispose);
          String result = 'pending';
          Future<void> showNotice(BuildContext context, bool long) async {
            final answer = await showDialog<bool>(
              context: context,
              builder: (ctx) => AppNotificationDialog(
                title: const Text('Matching certificate required'),
                content: long
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < 20; i++) Text('Guidance line $i'),
                          const Text('Last guidance line'),
                        ],
                      )
                    : const Text('Your service details will stay here.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Upload certificate'),
                  ),
                ],
              ),
            );
            result = answer == null ? 'dismissed' : answer.toString();
          }

          await tester.pumpWidget(
            MaterialApp(
              theme: neighborHelpTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      TextField(controller: draft),
                      TextButton(
                        onPressed: () => showNotice(context, false),
                        child: const Text('Short notice'),
                      ),
                      TextButton(
                        onPressed: () => showNotice(context, true),
                        child: const Text('Long notice'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Short notice'));
          await tester.pumpAndSettle();
          final firstSize = tester.getSize(
            find.byKey(AppNotificationDialog.surfaceKey),
          );
          expect(firstSize.width, width < 592 ? width - 32 : 560);
          expect(firstSize.height, 360);
          await tester.tap(
            find.descendant(
              of: find.byType(AppNotificationDialog),
              matching: find.byTooltip('Close'),
            ),
          );
          await tester.pumpAndSettle();
          expect(result, 'dismissed');
          expect(draft.text, 'Unsaved service details');
          await tester.tap(find.text('Long notice'));
          await tester.pumpAndSettle();
          expect(
            tester.getSize(find.byKey(AppNotificationDialog.surfaceKey)),
            firstSize,
          );
          await tester.ensureVisible(find.text('Last guidance line'));
          await tester.ensureVisible(find.text('Upload certificate'));
          await tester.tap(find.text('Upload certificate'));
          await tester.pumpAndSettle();
          expect(result, 'true');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('notification fits a short viewport above the keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 500);
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: neighborHelpTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AppNotificationDialog(
                  title: const Text('Notice'),
                  content: const Text('Longer information stays scrollable.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(AppNotificationDialog.surfaceKey)).height,
      lessThanOrEqualTo(202),
    );
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(AppNotificationDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
