import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messages.dart';

class AppPreferences extends ChangeNotifier {
  static final instance = AppPreferences();
  Locale locale = const Locale('en');
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('preferred_language');
      if (['en', 'fil', 'ceb'].contains(saved)) locale = Locale(saved!);
    } catch (_) {
      /* English remains available if local preferences cannot be read. */
    }
  }

  Future<void> setLanguage(String language) async {
    if (!['en', 'fil', 'ceb'].contains(language)) return;
    locale = Locale(language);
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(
        'preferred_language',
        language,
      );
    } catch (_) {
      /* This session still uses the selected language. */
    }
  }
}

class AppStrings {
  const AppStrings(this.language);
  final String language;
  String text(String key) =>
      messages[key]?[language == 'fil'
          ? 1
          : language == 'ceb'
          ? 2
          : 0] ??
      key;
  static const delegate = _StringsDelegate();
}

extension MarketplaceTranslations on BuildContext {
  String tr(String key) =>
      (Localizations.of<AppStrings>(this, AppStrings) ?? const AppStrings('en'))
          .text(key);
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      ['en', 'fil', 'ceb'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale.languageCode));
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

// Flutter's built-in controls use English where a target locale is unavailable.
// Product strings use the selected language; accepted contract text is preserved.
class MarketplaceMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const MarketplaceMaterialDelegate();
  @override
  bool isSupported(Locale locale) =>
      ['en', 'fil', 'ceb'].contains(locale.languageCode);
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(
        GlobalMaterialLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );
  @override
  bool shouldReload(MarketplaceMaterialDelegate old) => false;
}

class MarketplaceCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const MarketplaceCupertinoDelegate();
  @override
  bool isSupported(Locale locale) =>
      ['en', 'fil', 'ceb'].contains(locale.languageCode);
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(
        GlobalCupertinoLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );
  @override
  bool shouldReload(MarketplaceCupertinoDelegate old) => false;
}

class MarketplaceWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const MarketplaceWidgetsDelegate();
  @override
  bool isSupported(Locale locale) =>
      ['en', 'fil', 'ceb'].contains(locale.languageCode);
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(
        GlobalWidgetsLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );
  @override
  bool shouldReload(MarketplaceWidgetsDelegate old) => false;
}

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: context.tr('Language'),
    icon: const Icon(Icons.translate),
    onSelected: AppPreferences.instance.setLanguage,
    itemBuilder: (_) => [
      for (final entry in const {
        'en': 'English',
        'fil': 'Tagalog',
        'ceb': 'Cebuano / Bisaya',
      }.entries)
        CheckedPopupMenuItem(
          value: entry.key,
          checked: AppPreferences.instance.locale.languageCode == entry.key,
          child: Text(entry.value),
        ),
    ],
  );
}
