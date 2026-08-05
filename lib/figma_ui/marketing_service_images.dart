import 'marketing_service_asset_paths.dart';

/// Service thumbnails: bundled [assets/service_picture] first, then Unsplash fallbacks.
abstract final class MarketingServiceImages {
  static String _u(String photoId, {int w = 800}) =>
      'https://images.unsplash.com/$photoId?auto=format&fit=crop&w=$w&q=80';

  static String _normalize(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[/\-–—]'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Catalog titles that differ slightly from asset filenames.
  static const _aliases = <String, String>{
    'home maintenance check': 'home maintenance',
    'basic phone troubleshooting': 'basic phone',
    'internet wi fi setup': 'internetwi fi setup',
    'elderly companion assistance': 'elderly companion',
    'manicure pedicure home service': 'manicurepedicure',
    'aircon repair': 'aircon cleaning',
  };

  static const _categoryHeroKeys = <String, String>{
    'home_repair': 'home repair',
    'cleaning': 'cleaning',
    'repair_technical': 'repair and technical services',
    'handyman': 'furniture assembly',
    'tutoring': 'math tutoring',
    'personal_care': 'babysitting',
    'moving_errands': 'furniture moving',
    'food_event': 'home cooking service',
    'pet_care': 'dog walking',
    'community': 'gardening',
  };

  /// Bundled asset path for a catalog / listing title, if available.
  static String? assetPathFor({
    required String serviceName,
    String? categoryId,
    String? categoryName,
  }) {
    final id = categoryId ?? _categoryIdFromName(categoryName);
    if (id == null || serviceName.trim().isEmpty) return null;

    var norm = _normalize(serviceName);
    norm = _aliases[norm] ?? norm;

    final exact = MarketingServiceAssetPaths.byCategoryAndName['$id|$norm'];
    if (exact != null) return exact;

    String? best;
    var bestLen = 0;
    for (final entry in MarketingServiceAssetPaths.byCategoryAndName.entries) {
      if (!entry.key.startsWith('$id|')) continue;
      final key = entry.key.substring(id.length + 1);
      if (norm.contains(key) || key.contains(norm)) {
        if (key.length > bestLen) {
          bestLen = key.length;
          best = entry.value;
        }
      }
    }
    return best;
  }

  static bool isAssetPath(String path) => path.startsWith('assets/');

  /// Hero image per category (grid tiles, fallbacks).
  static const categoryHero = <String, String>{
    'home_repair': 'photo-1562259929-b4e1fd3aef09',
    'cleaning': 'photo-1581578949510-fa7315c4c350',
    'repair_technical': 'photo-1621905251189-08b45d6a269e',
    'handyman': 'photo-1504142130710-b3142bb061ef',
    'tutoring': 'photo-1427504496584-b135e10950e8',
    'personal_care': 'photo-1573497019940-2a588b7adf16',
    'moving_errands': 'photo-1600880292203-757a62a4b573',
    'food_event': 'photo-1555244162-7a29496b5069',
    'pet_care': 'photo-1450778869070-9d0607a076de',
    'community': 'photo-1416879595882-3373a0480b5b',
  };

  static final Map<String, List<String>> _categoryPools = {
    'home_repair': [
      'photo-1562259929-b4e1fd3aef09',
      'photo-1581244277948-d028f406d8ab',
      'photo-1504307653734-434519af1c60',
      'photo-1560518883-ce09059eeffa',
      'photo-1484154218962-a197022b5858',
    ],
    'cleaning': [
      'photo-1581578949510-fa7315c4c350',
      'photo-1628177140244-619303eede9e',
      'photo-1527515637462-de3050e398cb',
      'photo-1585421514288-70b7c02155bb',
      'photo-1558618666-fcd25c85cd64',
    ],
    'repair_technical': [
      'photo-1621905251189-08b45d6a269e',
      'photo-1607472586893-edb57bdc0e39',
      'photo-1558618666-fcd25c85cd64',
      'photo-1504328345606-18bbc8c9d7d1',
      'photo-1581092795360-fd9fdb3e2d0f',
    ],
    'handyman': [
      'photo-1504142130710-b3142bb061ef',
      'photo-1555041469-a586be75c243',
      'photo-1503387762-592deb58ef4e',
      'photo-1581578949510-fa7315c4c350',
      'photo-1562259929-b4e1fd3aef09',
    ],
    'tutoring': [
      'photo-1427504496584-b135e10950e8',
      'photo-1503676260728-1c00da280a0e',
      'photo-1522202176988-66273c2fd55f',
      'photo-1434030214721-48bfc9345444',
      'photo-1516321318423-f06f8e853bcc',
    ],
    'personal_care': [
      'photo-1573497019940-2a588b7adf16',
      'photo-1519494026892-17fba2917a15',
      'photo-1559839734-2b71ea197ec2',
      'photo-1576091160399-112ba8d25d1d',
      'photo-1582750433449-648ed127bb54',
    ],
    'moving_errands': [
      'photo-1600880292203-757a62a4b573',
      'photo-1566576912321-d1dbc7c928ad',
      'photo-1607083206869-4a20f256d03c',
      'photo-1586528116311-ad8dd3c8310d',
      'photo-1578574577314-32ee31c61669',
    ],
    'food_event': [
      'photo-1555244162-7a29496b5069',
      'photo-1414235077428-338989a2e8c0',
      'photo-1504674900247-0877df9cc836',
      'photo-1467003909585-2f8a727fb644',
      'photo-1556910103-1c02745aae4d',
    ],
    'pet_care': [
      'photo-1450778869070-9d0607a076de',
      'photo-1548199973-03cce0bbc87b',
      'photo-1583511655857-d19b40a7a548',
      'photo-1516734212186-a967f81ad0d8',
      'photo-1530281700549-e82e7bf110d6',
    ],
    'community': [
      'photo-1416879595882-3373a0480b5b',
      'photo-1558618666-fcd25c85cd64',
      'photo-1486262715619-67b85e443408',
      'photo-1601362840517-7c0e01731416',
      'photo-1506905925346-21bda4d32df4',
    ],
  };

  /// Keyword overrides for more specific thumbnails (network fallback only).
  static const _serviceKeywords = <String, String>{
    'roof': 'photo-1632778143955-f949e0a122e9',
    'door': 'photo-1555041469-a586be75c243',
    'window': 'photo-1484154218962-a197022b5858',
    'tile': 'photo-1615874959473-3a9b9d7b8f9b',
    'plumb': 'photo-1607472586893-edb57bdc0e39',
    'electr': 'photo-1621905251189-08b45d6a269e',
    'aircon': 'photo-1631545806609-5fb4e1b0f9a0',
    'appliance': 'photo-1558618666-fcd25c85cd64',
    'computer': 'photo-1517694712202-14dd953075aa',
    'laptop': 'photo-1496181133206-80ce9b88a853',
    'tutor': 'photo-1427504496584-b135e10950e8',
    'math': 'photo-1635070041078-e363dbe005cb',
    'music': 'photo-1511379938547-133d8a0d4b0a',
    'babysit': 'photo-1587654780291-39fe4efce7f5',
    'elderly': 'photo-1519494026892-17fba2917a15',
    'meal': 'photo-1504674900247-0877df9cc836',
    'makeup': 'photo-1522335789203-aabd1fc54bc9',
    'haircut': 'photo-1560066984-138dadb4c035',
    'grocery': 'photo-1542838132-92c53300491e',
    'deliver': 'photo-1566576912321-d1dbc7c928ad',
    'moving': 'photo-1600880292203-757a62a4b573',
    'cater': 'photo-1414235077428-338989a2e8c0',
    'cook': 'photo-1556910103-1c02745aae4d',
    'dog': 'photo-1548199973-03cce0bbc87b',
    'pet': 'photo-1450778869070-9d0607a076de',
    'garden': 'photo-1416879595882-3373a0480b5b',
    'lawn': 'photo-1558618666-fcd25c85cd64',
    'car wash': 'photo-1601362840517-7c0e01731416',
    'clean': 'photo-1581578949510-fa7315c4c350',
    'laundry': 'photo-1615990887947-1b55e5c8c2e0',
    'paint': 'photo-1562259949-e8e7689d7828',
    'cctv': 'photo-1557597774-9d273605fbe0',
    'wifi': 'photo-1544197150-b99a580bb7a8',
  };

  static String urlFor({
    required String serviceName,
    String? categoryId,
    String? categoryName,
  }) {
    final asset = assetPathFor(
      serviceName: serviceName,
      categoryId: categoryId,
      categoryName: categoryName,
    );
    if (asset != null) return asset;

    final id = categoryId ?? _categoryIdFromName(categoryName);
    final lower = serviceName.toLowerCase();
    for (final entry in _serviceKeywords.entries) {
      if (lower.contains(entry.key)) {
        return _u(entry.value);
      }
    }
    if (id != null) {
      final pool = _categoryPools[id];
      if (pool != null && pool.isNotEmpty) {
        final hash = serviceName.codeUnits.fold<int>(0, (a, b) => a + b);
        return _u(pool[hash % pool.length]);
      }
      final hero = categoryHero[id];
      if (hero != null) return _u(hero);
    }
    return _u('photo-1521791136064-7986c2920216');
  }

  static String? categoryImageUrl(String? categoryId) {
    if (categoryId == null) return null;
    final heroKey = _categoryHeroKeys[categoryId];
    if (heroKey != null) {
      final asset = MarketingServiceAssetPaths.byCategoryAndName['$categoryId|$heroKey'];
      if (asset != null) return asset;
    }
    final hero = categoryHero[categoryId];
    return hero != null ? _u(hero) : null;
  }

  static String? _categoryIdFromName(String? name) {
    if (name == null) return null;
    for (final entry in _categoryNameToId.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  static const _categoryNameToId = {
    'Home Repair': 'home_repair',
    'Cleaning': 'cleaning',
    'Repair and Technical': 'repair_technical',
    'Handyman': 'handyman',
    'Tutoring': 'tutoring',
    'Personal and Care': 'personal_care',
    'Moving and Errands': 'moving_errands',
    'Food and Event': 'food_event',
    'Pet Care': 'pet_care',
    'Community': 'community',
    'More': 'community',
    'Education': 'tutoring',
    'Lawn': 'community',
    'Fitness': 'personal_care',
    'Home Improvement': 'home_repair',
  };
}
