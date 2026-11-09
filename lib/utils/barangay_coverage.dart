import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/panabo_barangays.dart';

bool barangaysCover(List<String> ids, GeoPoint point) {
  bool inside(List ring) {
    var result = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i] as List, b = ring[j] as List;
      final xi = a[0] as num,
          yi = a[1] as num,
          xj = b[0] as num,
          yj = b[1] as num;
      if ((yi > point.latitude) != (yj > point.latitude) &&
          point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
        result = !result;
      }
    }
    return result;
  }

  return panaboBarangays
      .where((b) => ids.contains(b['id']))
      .any(
        (b) => (b['polygons'] as List).any((p) {
          final rings = p as List;
          return inside(rings.first as List) &&
              !rings.skip(1).any((r) => inside(r as List));
        }),
      );
}
