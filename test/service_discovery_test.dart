import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/data/panabo_barangays.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/utils/service_search.dart';

void main() {
  final covered = panaboBarangays.first;
  final profile = ServiceProviderProfile.fromFirestore('p', {
    'serviceArea': 'A different base barangay, Panabo City',
    'serviceBarangayIds': [covered['id']],
  });
  test(
    'location searches include service coverage beyond the provider base',
    () {
      expect(
        matchesServiceSearch(
          query: '  ${covered['name']}  ',
          title: 'House Cleaning',
          category: 'Cleaning',
          providerName: 'Maria',
          area: profile.serviceArea,
          profile: profile,
        ),
        isTrue,
      );
      expect(
        matchesServiceFilters(
          price: 100,
          rating: 4.5,
          area: profile.serviceArea,
          profile: profile,
          location: covered['name'] as String,
        ),
        isTrue,
      );
    },
  );
  test(
    'search still matches service, category and provider, and rejects unrelated places',
    () {
      for (final query in ['House', 'cleaning', 'MARIA', 'Panabo City', '']) {
        expect(
          matchesServiceSearch(
            query: query,
            title: 'House Cleaning',
            category: 'Cleaning',
            providerName: 'Maria',
            area: profile.serviceArea,
            profile: profile,
          ),
          isTrue,
        );
      }
      expect(
        matchesServiceSearch(
          query: 'Outside Service Area',
          title: 'House Cleaning',
          category: 'Cleaning',
          providerName: 'Maria',
          area: profile.serviceArea,
          profile: profile,
        ),
        isFalse,
      );
    },
  );
}
