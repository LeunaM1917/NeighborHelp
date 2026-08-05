import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/utils/haversine.dart';

void main() {
  test('haversine distance Manila to Cebu is hundreds of km', () {
    final d = haversineDistanceKm(
      lat1Deg: 14.5995,
      lon1Deg: 120.9842,
      lat2Deg: 10.3157,
      lon2Deg: 123.8854,
    );
    expect(d, greaterThan(400));
    expect(d, lessThan(700));
  });

  test('same point is ~0 km', () {
    final d = haversineDistanceKm(
      lat1Deg: 14.6,
      lon1Deg: 121.0,
      lat2Deg: 14.6,
      lon2Deg: 121.0,
    );
    expect(d, lessThan(0.05));
  });

  test('GeoPoint helper matches raw haversine', () {
    const a = GeoPoint(7.31, 125.68);
    const b = GeoPoint(7.32, 125.69);
    final raw = haversineDistanceKm(
      lat1Deg: a.latitude,
      lon1Deg: a.longitude,
      lat2Deg: b.latitude,
      lon2Deg: b.longitude,
    );
    expect(haversineDistanceKmFromGeoPoints(a, b), closeTo(raw, 0.001));
  });
}
