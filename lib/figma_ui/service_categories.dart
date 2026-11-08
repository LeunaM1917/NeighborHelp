import 'marketing_service_catalog.dart';
import '../utils/approved_service_catalog.dart';

/// Category and service names for provider listing forms.
abstract final class ServiceCategories {
  static List<String> get categoryNames =>
      approvedServiceCatalog.keys.toList(growable: false);

  static List<String> serviceNamesForCategory(String categoryName) {
    return approvedServiceCatalog[categoryName]?.keys.toList(growable: false) ??
        const [];
  }

  static String? categoryIdForName(String categoryName) {
    return MarketingServiceCatalog.categoryByName(categoryName)?.id;
  }
}
