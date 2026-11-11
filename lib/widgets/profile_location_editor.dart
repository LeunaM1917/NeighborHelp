import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/geo_location.dart';
import 'service_location_picker.dart';

/// Coordinates are chosen explicitly, never inferred from a signup placeholder.
class ProfileLocationEditor extends StatefulWidget {
  const ProfileLocationEditor({
    super.key,
    required this.address,
    required this.location,
    required this.onChanged,
    this.providerLocation = false,
  });
  final TextEditingController address;
  final GeoPoint? location;
  final ValueChanged<GeoPoint> onChanged;
  final bool providerLocation;
  @override
  State<ProfileLocationEditor> createState() => _ProfileLocationEditorState();
}

class _ProfileLocationEditorState extends State<ProfileLocationEditor> {
  bool _busy = false;
  Future<void> _currentLocation() async {
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services, or choose a map pin.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location access is blocked. Allow it in your browser/device settings, or choose a map pin.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final point = GeoPoint(position.latitude, position.longitude);
      if (geoPointOrNull(point) == null) {
        throw StateError(
          'A valid location was not returned. Choose a map pin instead.',
        );
      }
      if (mounted) {
        widget.onChanged(point);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Could not get your location. Choose a map pin instead.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.providerLocation
            ? 'Service base on the map'
            : 'Your location on the map',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      Text(
        geoPointOrNull(widget.location) == null
            ? 'No map location selected. Choose a pin or use your current location.'
            : 'Location selected. Save to update your map and nearby providers.',
      ),
      if (widget.providerLocation)
        const Text(
          'Choose the base you work from. Customers can see this service location.',
        ),
      const SizedBox(height: 4),
      ServiceLocationPicker(
        address: widget.address,
        preserveAddressText: true,
        origin: geoPointOrNull(widget.location),
        pinTitle: widget.providerLocation
            ? 'Pin your service base'
            : 'Pin your location',
        onSelected: widget.onChanged,
      ),
      TextButton.icon(
        onPressed: _busy ? null : _currentLocation,
        icon: const Icon(Icons.my_location),
        label: Text(_busy ? 'Getting location…' : 'Use my current location'),
      ),
    ],
  );
}

Future<GeoPoint?> showProfileLocationDialog(
  BuildContext context, {
  required GeoPoint? initialLocation,
  required String initialAddress,
}) => showDialog<GeoPoint>(
  context: context,
  builder: (_) => _ProfileLocationDialog(
    initialLocation: initialLocation,
    initialAddress: initialAddress,
  ),
);

class _ProfileLocationDialog extends StatefulWidget {
  const _ProfileLocationDialog({
    required this.initialLocation,
    required this.initialAddress,
  });
  final GeoPoint? initialLocation;
  final String initialAddress;
  @override
  State<_ProfileLocationDialog> createState() => _ProfileLocationDialogState();
}

class _ProfileLocationDialogState extends State<_ProfileLocationDialog> {
  late final TextEditingController _address;
  GeoPoint? _selected;
  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.initialAddress);
    _selected = geoPointOrNull(widget.initialLocation);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set your map location'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address or service area',
              ),
            ),
            const SizedBox(height: 16),
            ProfileLocationEditor(
              address: _address,
              location: _selected,
              onChanged: (point) => setState(() => _selected = point),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _selected == null
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('Save location'),
      ),
    ],
  );
}
