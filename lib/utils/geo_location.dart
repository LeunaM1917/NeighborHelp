import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Default map center when the user has no saved GPS (Panabo City).
const LatLng kDefaultPanaboLatLng = LatLng(7.3081, 125.6842);

/// Historical Manila placeholder. New profiles start with no saved coordinates.
const GeoPoint kDefaultSignupGeoPoint = GeoPoint(14.5995, 120.9842);

bool isValidGeoPoint(GeoPoint? point) {
  if (point == null) return false;
  if (!point.latitude.isFinite ||
      !point.longitude.isFinite ||
      point.latitude.abs() > 90 ||
      point.longitude.abs() > 180) {
    return false;
  }
  if (point.latitude == 0 && point.longitude == 0) return false;
  return true;
}

bool isDefaultSignupLocation(GeoPoint point) {
  return (point.latitude - kDefaultSignupGeoPoint.latitude).abs() < 0.000001 &&
      (point.longitude - kDefaultSignupGeoPoint.longitude).abs() < 0.000001;
}

LatLng latLngFromGeoPoint(GeoPoint point) =>
    LatLng(point.latitude, point.longitude);

GeoPoint? geoPointOrNull(GeoPoint? point) =>
    isValidGeoPoint(point) && !isDefaultSignupLocation(point!) ? point : null;

/// Human-readable distance for list labels.
/// [isDriving] — road distance from Distance Matrix; otherwise straight-line (Haversine).
String formatDistanceKm(double km, {bool isDriving = false}) {
  final suffix = isDriving ? ' drive' : ' away';
  if (km < 1) return '${(km * 1000).round()} m$suffix';
  if (km < 10) return '${km.toStringAsFixed(1)} km$suffix';
  return '${km.round()} km$suffix';
}
