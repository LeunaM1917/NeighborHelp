import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/panabo_barangays.dart';
import '../data/panabo_city.dart';

final _barangaysById = {for (final b in panaboBarangays) b['id'] as String: b};

double _segmentDistanceSquared(GeoPoint point, List a, List b) {
  final dx = (b[0] as num) - (a[0] as num);
  final dy = (b[1] as num) - (a[1] as num);
  final length = dx * dx + dy * dy;
  final t = length == 0
      ? 0.0
      : (((point.longitude - (a[0] as num)) * dx +
                    (point.latitude - (a[1] as num)) * dy) /
                length)
            .clamp(0.0, 1.0);
  final x = point.longitude - (a[0] as num) - t * dx;
  final y = point.latitude - (a[1] as num) - t * dy;
  return x * x + y * y;
}

double _ringDistanceSquared(GeoPoint point, List ring) {
  var distance = double.infinity;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    distance = math.min(
      distance,
      _segmentDistanceSquared(point, ring[j] as List, ring[i] as List),
    );
  }
  return distance;
}

bool _inRing(GeoPoint point, List ring) {
  if (_ringDistanceSquared(point, ring) <= 1e-20) return true;
  var inside = false;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i] as List, b = ring[j] as List;
    final xi = a[0] as num, yi = a[1] as num;
    final xj = b[0] as num, yj = b[1] as num;
    if ((yi > point.latitude) != (yj > point.latitude) &&
        point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

bool _inPolygon(GeoPoint point, List rings) =>
    _inRing(point, rings.first as List) &&
    !rings.skip(1).any((ring) => _inRing(point, ring as List));

bool barangaysCover(List<String> ids, GeoPoint point) {
  if (ids.isEmpty || ids.any((id) => !_barangaysById.containsKey(id))) {
    return false;
  }
  final selected = ids.toSet();
  final containing = panaboBarangays
      .where(
        (b) => (b['polygons'] as List).any(
          (rings) => _inPolygon(point, rings as List),
        ),
      )
      .toList();
  if (containing.isNotEmpty) {
    return containing.any((b) => selected.contains(b['id']));
  }

  // Match the server's bounded handling of upstream simplification gaps.
  // Known unselected areas, excluded holes and outside-city points stay out.
  if (!panaboCityPolygons.any((rings) => _inPolygon(point, rings)) ||
      panaboBarangays.any(
        (b) => (b['polygons'] as List).any(
          (rings) => (rings as List)
              .skip(1)
              .any((ring) => _inRing(point, ring as List)),
        ),
      )) {
    return false;
  }
  String? nearestId;
  var distance = double.infinity;
  for (final b in panaboBarangays) {
    final candidate = (b['polygons'] as List)
        .map(
          (rings) => _ringDistanceSquared(point, (rings as List).first as List),
        )
        .reduce(math.min);
    if (candidate < distance - 1e-16) {
      distance = candidate;
      nearestId = b['id'] as String;
    }
  }
  return distance <=
          panaboCoverageGapToleranceDegrees *
              panaboCoverageGapToleranceDegrees &&
      selected.contains(nearestId);
}
