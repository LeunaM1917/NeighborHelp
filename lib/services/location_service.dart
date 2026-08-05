import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Future<bool> ensureServiceEnabled() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      enabled = await Geolocator.openLocationSettings();
    }
    return enabled;
  }

  Future<LocationPermission> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Uses permission_handler for clearer UX on Android; falls back to Geolocator.
  Future<bool> requestFineLocation() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await ensureServiceEnabled()) return null;
    final perm = await requestPermission();
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
