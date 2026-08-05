import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One [ScrollController] per app-shell tab; supports scroll-to-top on re-tap.
class AppShellTabScroll {
  AppShellTabScroll(int tabCount)
      : controllers = List.generate(tabCount, (_) => ScrollController());

  final List<ScrollController> controllers;

  ScrollController controllerFor(int index) => controllers[index];

  void scrollToTop(int index) {
    if (index < 0 || index >= controllers.length) return;
    final controller = controllers[index];

    void go() {
      if (!controller.hasClients) return;
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }

    go();
    SchedulerBinding.instance.addPostFrameCallback((_) => go());
  }

  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
  }
}
