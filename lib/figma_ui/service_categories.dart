import 'marketing_service_catalog.dart';

/// Category and service names for provider listing forms.
abstract final class ServiceCategories {
  static List<String> get categoryNames =>
      MarketingServiceCatalog.categories.map((c) => c.name).toList(growable: false);

  static List<String> serviceNamesForCategory(String categoryName) {
    final cat = MarketingServiceCatalog.categoryByName(categoryName);
    if (cat == null) return const [];
    return cat.services.map((s) => s.name).toList(growable: false);
  }

  static String? categoryIdForName(String categoryName) {
    return MarketingServiceCatalog.categoryByName(categoryName)?.id;
  }
}
