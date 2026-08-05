import 'package:flutter/material.dart';

/// Persists bottom-nav tab index across shell remounts (e.g. after profile save).
class AppShellTabStorage {
  AppShellTabStorage._();

  static PageStorageKey keyForRole(String role) => PageStorageKey('app_shell_tab_$role');

  static int read(BuildContext context, PageStorageKey key) {
    final bucket = PageStorage.maybeOf(context);
    if (bucket == null) return 0;
    return bucket.readState(context, identifier: key) as int? ?? 0;
  }

  static void write(BuildContext context, PageStorageKey key, int index) {
    PageStorage.maybeOf(context)?.writeState(context, index, identifier: key);
  }
}
