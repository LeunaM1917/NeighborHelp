import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/utils/geo_location.dart';

void main() {
  test('formatDistanceKm driving suffix', () {
    expect(formatDistanceKm(0.4, isDriving: true), '400 m drive');
    expect(formatDistanceKm(2.3), '2.3 km away');
  });

  test('isDefaultSignupLocation detects Manila placeholder', () {
    expect(isDefaultSignupLocation(kDefaultSignupGeoPoint), isTrue);
    expect(isDefaultSignupLocation(const GeoPoint(7.31, 125.68)), isFalse);
  });
}
