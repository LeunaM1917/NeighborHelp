import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/screens/admin/widgets/admin_navigation.dart';
import 'package:neighbor_help/theme/role_theme.dart';
import 'package:neighbor_help/widgets/app_footer.dart';
import 'package:neighbor_help/widgets/workspace_navigation_rail.dart';

import 'support/ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();

  void resize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('admin groups preserve all thirteen original destination indices', () {
    final destinations = [
      for (final item in adminNavigationItems)
        if (item.index != null) item else ...item.children,
    ];
    final expected = {
      0: 'Overview',
      1: 'Customers',
      2: 'Providers',
      3: 'User Reports',
      4: 'Verification',
      5: 'Certificates',
      6: 'Services',
      7: 'Bookings',
      8: 'Reports',
      9: 'Activity',
      10: 'Notifications',
      11: 'Ranking',
      12: 'Settings',
    };
    expect(destinations.length, 13);
    expect({for (final item in destinations) item.index: item.label}, expected);
    expect(adminNavigationItems.length, 6);
  });

  testOnPlatform(
    'admin hover menus keep every original destination reachable',
    (tester) async {
      resize(tester, const Size(1280, 900));
      final selected = <int>[];
      await tester.pumpWidget(_AdminHarness(onSelect: selected.add));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.text('Customers'), findsNothing);
      expect(tester.getSize(find.byType(WorkspaceNavigationRail)).width, 96);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(800, 600));
      addTearDown(mouse.removePointer);
      for (final group in adminNavigationItems.where(
        (item) => item.children.isNotEmpty,
      )) {
        for (final destination in group.children) {
          await mouse.moveTo(
            tester.getCenter(find.widgetWithText(TextButton, group.label)),
          );
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 250));
          final target = find.widgetWithText(MenuItemButton, destination.label);
          expect(target, findsOneWidget);
          await mouse.moveTo(tester.getCenter(target));
          await tester.pump(const Duration(milliseconds: 250));
          expect(
            target,
            findsOneWidget,
            reason: 'Flyout stays open while entering it',
          );
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(selected.last, destination.index);
          expect(find.byType(MenuItemButton), findsNothing);
          final active = tester.widget<TextButton>(
            find.widgetWithText(TextButton, group.label),
          );
          expect(
            active.style!.foregroundColor!.resolve({}),
            RoleTheme.admin.primary,
          );
          await mouse.moveTo(const Offset(800, 600));
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
      expect(selected.toSet(), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12});
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'mouse click keeps a hover-opened category available for selection',
    (tester) async {
      resize(tester, const Size(1280, 900));
      final selected = <int>[];
      await tester.pumpWidget(_AdminHarness(onSelect: selected.add));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(800, 600));
      addTearDown(mouse.removePointer);
      final people = tester.getCenter(
        find.widgetWithText(TextButton, 'People'),
      );
      await mouse.moveTo(people);
      await tester.pump(const Duration(milliseconds: 300));
      await mouse.down(people);
      await mouse.up();
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(800, 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.widgetWithText(MenuItemButton, 'Providers'), findsOneWidget);
      await tester.tap(find.widgetWithText(MenuItemButton, 'Providers'));
      await tester.pumpAndSettle();
      expect(selected, [2]);
      expect(find.byType(MenuItemButton), findsNothing);
    },
  );

  testOnPlatform('hover menus close on exit, Escape and outside click', (
    tester,
  ) async {
    resize(tester, const Size(1280, 900));
    await tester.pumpWidget(const _AdminHarness());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(800, 600));
    addTearDown(mouse.removePointer);
    final people = find.widgetWithText(TextButton, 'People');

    await mouse.moveTo(tester.getCenter(people));
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsOneWidget);
    await mouse.moveTo(const Offset(800, 600));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsNothing);

    await tester.tap(people);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Customers'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsNothing);

    await tester.tap(people);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(800, 600));
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testOnPlatform('keyboard can open a category and choose a destination', (
    tester,
  ) async {
    resize(tester, const Size(1280, 900));
    final selected = <int>[];
    await tester.pumpWidget(_AdminHarness(onSelect: selected.add));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, isNotEmpty);
    expect({1, 2}, contains(selected.last));
    expect(find.byType(MenuItemButton), findsNothing);
  });

  testOnPlatform(
    'admin phone menus work by touch without hover',
    (tester) async {
      resize(tester, const Size(320, 760));
      final selected = <int>[];
      await tester.pumpWidget(
        _AdminHarness(compact: true, onSelect: selected.add),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Trust'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Certificates'));
      await tester.pumpAndSettle();
      expect(selected, [5]);
      await tester.tap(find.widgetWithText(TextButton, 'More'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Settings'));
      await tester.pumpAndSettle();
      expect(selected, [5, 12]);
      expect(tester.takeException(), isNull);
    },
    platform: TargetPlatform.android,
  );

  for (final width in [320.0, 840.0, 1280.0]) {
    testOnPlatform(
      'light footer wraps and keeps its information links at $width',
      (tester) async {
        resize(tester, Size(width, 800));
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: AppFooter())),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            '© ${DateTime.now().year} NeighborHelp. All rights reserved.',
          ),
          findsOneWidget,
        );
        for (final label in [
          'How bookings work',
          'Trust & safety',
          'Privacy',
          'Contact',
        ]) {
          await tester.tap(find.widgetWithText(TextButton, label));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          if (label == 'Contact') {
            expect(
              find.textContaining('support@neighborhelp.com'),
              findsOneWidget,
            );
            expect(find.textContaining('Davao del Norte'), findsOneWidget);
          }
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform(
    'cached footer remains hidden in native mobile layouts',
    (tester) async {
      resize(tester, const Size(390, 800));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CachedAppFooter.customer())),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppFooter), findsNothing);
    },
    platform: TargetPlatform.iOS,
  );
}

class _AdminHarness extends StatefulWidget {
  const _AdminHarness({this.compact = false, this.onSelect});
  final bool compact;
  final ValueChanged<int>? onSelect;

  @override
  State<_AdminHarness> createState() => _AdminHarnessState();
}

class _AdminHarnessState extends State<_AdminHarness> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: RoleThemeScope(
      palette: RoleTheme.admin,
      child: Scaffold(
        body: Align(
          alignment: widget.compact ? Alignment.bottomLeft : Alignment.topLeft,
          child: AdminNavigation(
            compact: widget.compact,
            currentIndex: selected,
            onSelect: (index) {
              widget.onSelect?.call(index);
              setState(() => selected = index);
            },
          ),
        ),
      ),
    ),
  );
}
