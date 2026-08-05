import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsService {
  /// Forward geocode a free-text address (platform geocoder).
  Future<LatLng?> geocodeAddress(String address) async {
    final locations = await locationFromAddress(address);
    if (locations.isEmpty) return null;
    final first = locations.first;
    return LatLng(first.latitude, first.longitude);
  }

  Future<String?> reverseGeocode(LatLng point) async {
    final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;
    return [p.street, p.subLocality, p.locality, p.administrativeArea, p.country]
        .where((e) => (e ?? '').isNotEmpty)
        .cast<String>()
        .join(', ');
  }
}
