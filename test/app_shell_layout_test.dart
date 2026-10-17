import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:neighbor_help/figma_ui/app_shell_layout.dart';
import 'package:neighbor_help/figma_ui/app_shell_sidebar.dart';
import 'package:neighbor_help/figma_ui/app_shell_tab.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/theme/role_theme.dart';

const _customerTabs = [
  AppShellTab(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  AppShellTab(
    label: 'Browse',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
  ),
  AppShellTab(
    label: 'Bookings',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
  ),
  AppShellTab(
    label: 'Messages',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
  ),
  AppShellTab(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];
const _providerTabs = [
  AppShellTab(
    label: 'Dashboard',
    shortLabel: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  AppShellTab(
    label: 'Services',
    icon: Icons.home_repair_service_outlined,
    selectedIcon: Icons.home_repair_service,
  ),
  AppShellTab(
    label: 'Jobs',
    icon: Icons.work_outline,
    selectedIcon: Icons.work,
  ),
  AppShellTab(
    label: 'Messages',
    shortLabel: 'Chat',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
  ),
  AppShellTab(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Supply font assets in memory so layout tests never need network access.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin' || key == 'AssetManifest.bin.json') {
            final manifest = const StandardMessageCodec().encodeMessage({
              for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
                'test-fonts/Inter-$weight.ttf': [
                  {'asset': 'test-fonts/Inter-$weight.ttf'},
                ],
            })!;
            return key.endsWith('.json')
                ? ByteData.sublistView(
                    utf8.encode(
                      jsonEncode(base64Encode(manifest.buffer.asUint8List())),
                    ),
                  )
                : manifest;
          }
          if (key == 'AssetManifest.json') {
            return ByteData.sublistView(
              utf8.encode(
                jsonEncode({
                  for (final weight in [
                    'Regular',
                    'Medium',
                    'SemiBold',
                    'Bold',
                  ])
                    'test-fonts/Inter-$weight.ttf': [
                      'test-fonts/Inter-$weight.ttf',
                    ],
                }),
              ),
            );
          }
          if (key.startsWith('test-fonts/')) return ByteData(0);
          return null;
        });
  });

  tearDown(() {
    GoogleFonts.config.allowRuntimeFetching = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  void setSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final provider in [false, true]) {
    final role = provider ? 'Provider' : 'Customer';
    final tabs = provider ? _providerTabs : _customerTabs;

    testShell('$role sidebar selects every destination and supports re-taps', (
      tester,
    ) async {
      setSize(tester, const Size(1280, 800));
      final taps = <int>[];
      await tester.pumpWidget(
        _Harness(provider: provider, onTabChanged: taps.add),
      );
      await tester.pumpAndSettle();

      final sidebar = find.byType(AppShellSidebar);
      expect(sidebar, findsOneWidget);
      expect(tester.getSize(sidebar).width, AppShellSidebar.width);
      expect(find.text('${role.toUpperCase()} WORKSPACE'), findsOneWidget);
      expect(find.text(provider ? 'Browse' : 'Services'), findsNothing);

      for (var i = 0; i < tabs.length; i++) {
        await tester.tap(
          find.descendant(of: sidebar, matching: find.text(tabs[i].label)),
        );
        await tester.pumpAndSettle();
        final tile = tester.widget<ListTile>(
          find.widgetWithText(ListTile, tabs[i].label),
        );
        expect(tile.selected, isTrue);
        expect(
          tile.selectedColor,
          (provider ? RoleTheme.provider : RoleTheme.customer).primary,
        );
        expect(find.text('Current page: $i'), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(ListTile, 'Profile'));
      await tester.pumpAndSettle();
      expect(taps, [0, 1, 2, 3, 4, 4]);
      expect(tester.takeException(), isNull);
    });

    testShell('$role keeps tab state across desktop and mobile resizing', (
      tester,
    ) async {
      setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(_Harness(provider: provider));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remember this page'));
      await tester.tap(find.widgetWithText(ListTile, 'Profile'));
      await tester.pumpAndSettle();

      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(_PageStateProbe),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      position.jumpTo(200);
      await tester.pumpAndSettle();

      for (final width in [839.0, 600.0, 390.0, 320.0, 840.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 800);
        await tester.pumpAndSettle();
        expect(
          find.byType(AppShellSidebar),
          width >= 840 ? findsOneWidget : findsNothing,
        );
        expect(find.text('Current page: 4'), findsOneWidget);
        expect(find.text('Remembered: 1'), findsOneWidget);
        expect(position.pixels, 200);
        expect(tester.takeException(), isNull, reason: '$role at width $width');
      }
    });

    testShell(
      '$role bottom navigation preserves all destinations and short labels',
      (tester) async {
        setSize(tester, const Size(390, 800));
        final taps = <int>[];
        await tester.pumpWidget(
          _Harness(provider: provider, onTabChanged: taps.add),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppShellSidebar), findsNothing);

        for (var i = 0; i < tabs.length; i++) {
          final label = tabs[i].navLabel(compact: true);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(find.text('Current page: $i'), findsOneWidget);
        }
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(taps, [0, 1, 2, 3, 4, 4]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testShell('$platform keeps bottom navigation at tablet widths', (
      tester,
    ) async {
      setSize(tester, const Size(1024, 768));
      await tester.pumpWidget(const _Harness(provider: true));
      await tester.pumpAndSettle();
      expect(find.byType(AppShellSidebar), findsNothing);
      expect(find.text('Chat'), findsOneWidget);
      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      expect(find.text('Current page: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, platform: platform);
  }

  for (final width in [320.0, 840.0, 1280.0]) {
    testShell(
      'brand returns home and sign out uses its existing callback at $width',
      (tester) async {
        setSize(tester, Size(width, 800));
        final taps = <int>[];
        var signedOut = false;
        await tester.pumpWidget(
          _Harness(
            provider: true,
            onTabChanged: taps.add,
            onSignOut: () => signedOut = true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Image).first);
        await tester.pumpAndSettle();
        expect(taps.last, 0);
        expect(find.text('Current page: 0'), findsOneWidget);
        await tester.tap(find.byTooltip('Account'));
        await tester.pumpAndSettle();
        expect(find.text('Jamie Santos'), findsOneWidget);
        expect(find.text('jamie@example.test'), findsOneWidget);
        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();
        expect(signedOut, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void testShell(
  String description,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.windows,
}) {
  testWidgets(
    description,
    (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip:
        kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS),
  );
}

class _Harness extends StatefulWidget {
  const _Harness({required this.provider, this.onTabChanged, this.onSignOut});
  final bool provider;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onSignOut;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int currentIndex = 0;
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: RoleThemeScope(
      palette: widget.provider ? RoleTheme.provider : RoleTheme.customer,
      child: Scaffold(
        body: AppShellLayout(
          tabs: widget.provider ? _providerTabs : _customerTabs,
          currentIndex: currentIndex,
          scrollController: _controller,
          onTabChanged: (index) {
            widget.onTabChanged?.call(index);
            setState(() => currentIndex = index);
          },
          appUser: AppUser.fromFirestore('test-user', {
            'fullName': 'Jamie Santos',
            'email': 'jamie@example.test',
            'role': widget.provider ? 'provider' : 'customer',
          }),
          roleBadge: widget.provider ? 'Provider' : 'Customer',
          onSignOut: widget.onSignOut ?? () {},
          // No backend is needed to verify the layout and navigation contract.
          showUtilityActions: false,
          child: _PageStateProbe(index: currentIndex, controller: _controller),
        ),
      ),
    ),
  );
}

class _PageStateProbe extends StatefulWidget {
  const _PageStateProbe({required this.index, required this.controller});
  final int index;
  final ScrollController controller;

  @override
  State<_PageStateProbe> createState() => _PageStateProbeState();
}

class _PageStateProbeState extends State<_PageStateProbe> {
  int count = 0;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: widget.controller,
    child: Column(
      children: [
        Text('Current page: ${widget.index}'),
        Text('Remembered: $count'),
        TextButton(
          onPressed: () => setState(() => count++),
          child: const Text('Remember this page'),
        ),
        const SizedBox(height: 1400),
      ],
    ),
  );
}
