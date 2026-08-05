import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Earth radius in kilometers (WGS84 mean).
const double earthRadiusKm = 6371;

/// Haversine distance between two WGS84 coordinates in kilometers.
double haversineDistanceKm({
  required double lat1Deg,
  required double lon1Deg,
  required double lat2Deg,
  required double lon2Deg,
}) {
  final lat1 = lat1Deg * math.pi / 180;
  final lat2 = lat2Deg * math.pi / 180;
  final dLat = (lat2Deg - lat1Deg) * math.pi / 180;
  final dLon = (lon2Deg - lon1Deg) * math.pi / 180;

  final a = math.pow(math.sin(dLat / 2), 2).toDouble() +
      math.cos(lat1) *
          math.cos(lat2) *
          math.pow(math.sin(dLon / 2), 2).toDouble();
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double haversineDistanceKmFromGeoPoints(GeoPoint from, GeoPoint to) {
  return haversineDistanceKm(
    lat1Deg: from.latitude,
    lon1Deg: from.longitude,
    lat2Deg: to.latitude,
    lon2Deg: to.longitude,
  );
}

double haversineDistanceKmFromLatLng(LatLng from, LatLng to) {
  return haversineDistanceKm(
    lat1Deg: from.latitude,
    lon1Deg: from.longitude,
    lat2Deg: to.latitude,
    lon2Deg: to.longitude,
  );
}
