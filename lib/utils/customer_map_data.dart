import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../services/provider_recommendation_service.dart';
import 'geo_location.dart';

class NearbyMapPin {
  const NearbyMapPin({
    required this.id,
    required this.position,
    required this.label,
    this.photoUrl,
    this.isDemo = false,
  });
  final String id;
  final LatLng position;
  final String label;
  final String? photoUrl;
  final bool isDemo;
}

class CustomerProviderDiscovery {
  CustomerProviderDiscovery({
    required List<ServiceProviderProfile> providers,
    GeoPoint? origin,
  }) {
    nearby = rankProvidersByRecommendation(
      providers: providers
          .where((p) => geoPointOrNull(p.location) != null)
          .toList(),
      customerOrigin:
          geoPointOrNull(origin) ??
          GeoPoint(
            kDefaultPanaboLatLng.latitude,
            kDefaultPanaboLatLng.longitude,
          ),
    );
    awaitingLocation = rankProvidersByRecommendation(
      providers: providers
          .where((p) => geoPointOrNull(p.location) == null)
          .toList(),
    );
  }
  late final List<RankedProvider> nearby;
  late final List<RankedProvider> awaitingLocation;
  List<RankedProvider> hiredBefore(Set<String> hiredIds) =>
      [...nearby, ...awaitingLocation]
          .where(
            (r) =>
                hiredIds.contains(r.profile.providerId) ||
                hiredIds.contains(r.profile.userId),
          )
          .toList();
}

List<NearbyMapPin> buildNearbyMapPins({
  required List<ServiceProviderProfile> providers,
  required Map<String, AppUser> users,
  GeoPoint? origin,
}) => [
  for (final ranked in CustomerProviderDiscovery(
    providers: providers,
    origin: origin,
  ).nearby)
    NearbyMapPin(
      id: ranked.profile.providerId,
      position: latLngFromGeoPoint(ranked.profile.location),
      label: users[ranked.profile.userId]?.fullName.trim().isNotEmpty == true
          ? users[ranked.profile.userId]!.fullName
          : 'Provider',
      photoUrl: users[ranked.profile.userId]?.profilePhotoUrl,
    ),
];

Set<Marker> customerAreaMarkers({
  required LatLng? customer,
  required List<NearbyMapPin> pins,
  BitmapDescriptor? customerIcon,
}) => {
  if (customer != null)
    Marker(
      markerId: const MarkerId('you'),
      position: customer,
      icon: customerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: const InfoWindow(
        title: 'You',
        snippet: 'Your saved map location',
      ),
      zIndexInt: 2,
    ),
  for (final pin in pins)
    Marker(
      markerId: MarkerId(pin.id),
      position: pin.position,
      infoWindow: InfoWindow(title: pin.label, snippet: 'Service base'),
      zIndexInt: 1,
    ),
};

/// Equal/near-equal points use a fixed city zoom, never a zero-area fit to zoom 22.
CameraUpdate customerAreaCamera({
  required LatLng? customer,
  required List<NearbyMapPin> pins,
}) {
  final points = [
    if (customer != null) customer,
    ...pins.map((p) => p.position),
  ];
  if (points.isEmpty) {
    return CameraUpdate.newLatLngZoom(kDefaultPanaboLatLng, 13);
  }
  var south = points.first.latitude,
      north = south,
      west = points.first.longitude,
      east = west;
  for (final point in points) {
    south = math.min(south, point.latitude);
    north = math.max(north, point.latitude);
    west = math.min(west, point.longitude);
    east = math.max(east, point.longitude);
  }
  if (north - south < 0.001 && east - west < 0.001) {
    return CameraUpdate.newLatLngZoom(points.first, 14);
  }
  return CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    ),
    48,
  );
}
