import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/figma_ui/marketing_featured_services.dart';
import 'package:neighbor_help/figma_ui/marketing_service_catalog.dart';
import 'package:neighbor_help/figma_ui/marketing_service_images.dart';
import 'package:neighbor_help/figma_ui/service_categories.dart';
import 'package:neighbor_help/models/service.dart';
import 'package:neighbor_help/utils/approved_service_catalog.dart';

void main() {
  test(
    'plumbing and electrical repair are selectable and have bundled photos',
    () {
      final category = MarketingServiceCatalog.categoryById(
        'repair_technical',
      )!;
      for (final title in ['Plumbing Repair', 'Electrical Repair']) {
        expect(
          ServiceCategories.serviceNamesForCategory(category.name),
          contains(title),
        );
        expect(category.services.map((item) => item.name), contains(title));
        expect(
          MarketingFeaturedServices.all.map((item) => item.title),
          contains(title),
        );
        final image = MarketingServiceImages.urlFor(
          serviceName: title,
          categoryId: category.id,
        );
        expect(image, startsWith('assets/optimized_services/'));
        expect(File(image).existsSync(), isTrue);
        expect(
          ServiceListing.fromFirestore(title, {
            'serviceTitle': title,
            'category': category.name,
            'isActive': true,
            'approvalStatus': 'Approved',
          }).isMarketplaceVisible,
          isTrue,
        );
      }
    },
  );

  test(
    'all eight construction options are absent from browse and new listing choices',
    () {
      expect(ServiceCategories.categoryNames, isNot(contains('Construction')));
      expect(MarketingServiceCatalog.categoryById('construction'), isNull);
      for (final title in [
        'Masonry',
        'Concrete Block Laying',
        'Bricklaying',
        'Wall Plastering',
        'Construction Carpentry',
        'Tile Installation',
        'Tile Repair',
        'Construction Painting',
      ]) {
        expect(isSupportedService('Construction', title), isFalse);
        // Old records retain their title and provider link while staying out of discovery.
        final historical = ServiceListing.fromFirestore('old-service', {
          'serviceTitle': title,
          'category': 'Construction',
          'providerId': 'provider',
          'isActive': true,
          'approvalStatus': 'Approved',
        });
        expect(historical.serviceTitle, title);
        expect(historical.providerId, 'provider');
        expect(historical.isMarketplaceVisible, isFalse);
      }
    },
  );
}
