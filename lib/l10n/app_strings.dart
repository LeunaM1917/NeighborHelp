import 'package:flutter/material.dart';
import 'messages.dart';

/// Shared English copy for workflow labels and notices.
class AppStrings {
  const AppStrings();
  String text(String key) => messages[key] ?? key;
}

extension MarketplaceCopy on BuildContext {
  String tr(String key) => const AppStrings().text(key);
}
