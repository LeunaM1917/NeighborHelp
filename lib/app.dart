import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/root/root_gate.dart';
import 'theme/app_theme.dart';

class NeighborHelpApp extends StatelessWidget {
  const NeighborHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeighborHelp',
      debugShowCheckedModeBanner: false,
      theme: neighborHelpLightTheme(),
      darkTheme: neighborHelpDarkTheme(),
      // Keep the product visually aligned with the light landing page design.
      // Users were seeing navy/dark form fields when the OS was in dark mode.
      themeMode: ThemeMode.light,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      home: const RootGate(),
    );
  }
}
