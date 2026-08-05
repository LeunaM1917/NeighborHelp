import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/functions_config.dart';
import '../utils/geo_location.dart';
import '../utils/haversine.dart';

/// Driving distances via Cloud Functions (Distance Matrix) with Haversine fallback.
class DistanceService {
  DistanceService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: kNeighborHelpFunctionsRegion);

  static final DistanceService instance = DistanceService();

  final FirebaseFunctions _functions;
  final Map<String, double> _drivingKmCache = {};

  double straightLineKm(GeoPoint from, GeoPoint to) => haversineDistanceKmFromGeoPoints(from, to);

  /// Batch driving distances in km keyed by destination [id]. Missing keys → use [straightLineKm].
  Future<Map<String, double>> drivingDistancesKm({
    required GeoPoint origin,
    required List<({String id, GeoPoint point})> destinations,
  }) async {
    if (destinations.isEmpty) return {};

    final out = <String, double>{};
    final pending = <({String id, GeoPoint point})>[];

    for (final d in destinations) {
      if (!isValidGeoPoint(d.point)) continue;
      final key = _cacheKey(origin, d.point);
      final cached = _drivingKmCache[key];
      if (cached != null) {
        out[d.id] = cached;
      } else {
        pending.add(d);
      }
    }

    if (pending.isEmpty) return out;

    for (var i = 0; i < pending.length; i += 25) {
      final chunk = pending.sublist(i, i + 25 > pending.length ? pending.length : i + 25);
      try {
        final callable = _functions.httpsCallable('getDrivingDistances');
        final result = await callable.call<Map<String, dynamic>>({
          'origin': {'lat': origin.latitude, 'lng': origin.longitude},
          'destinations': [
            for (final d in chunk)
              {'id': d.id, 'lat': d.point.latitude, 'lng': d.point.longitude},
          ],
        });
        final distances = result.data['distances'];
        if (distances is Map) {
          for (final entry in distances.entries) {
            if (entry.value is! num) continue;
            final km = (entry.value as num).toDouble();
            if (km <= 0) continue;
            final id = entry.key.toString();
            out[id] = km;
            for (final d in chunk) {
              if (d.id == id) {
                _drivingKmCache[_cacheKey(origin, d.point)] = km;
                break;
              }
            }
          }
        }
      } on FirebaseFunctionsException catch (e) {
        debugPrint('getDrivingDistances: ${e.code} ${e.message}');
        break;
      } catch (e, st) {
        debugPrint('getDrivingDistances failed: $e\n$st');
        break;
      }
    }

    return out;
  }

  String _cacheKey(GeoPoint origin, GeoPoint dest) {
    String r(double v) => v.toStringAsFixed(4);
    return '${r(origin.latitude)},${r(origin.longitude)}->${r(dest.latitude)},${r(dest.longitude)}';
  }
}

/// Sorts providers by straight-line distance, then rating.
List<T> sortByStraightLineDistance<T>({
  required List<T> items,
  required GeoPoint origin,
  required GeoPoint Function(T item) locationOf,
  required double Function(T item) ratingOf,
}) {
  final copy = [...items];
  copy.sort((a, b) {
    final da = haversineDistanceKmFromGeoPoints(origin, locationOf(a));
    final db = haversineDistanceKmFromGeoPoints(origin, locationOf(b));
    final cmp = da.compareTo(db);
    if (cmp != 0) return cmp;
    return ratingOf(b).compareTo(ratingOf(a));
  });
  return copy;
}
