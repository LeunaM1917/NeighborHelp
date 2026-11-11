import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/functions_config.dart';
import '../utils/geo_location.dart';

class ServiceLocationPicker extends StatefulWidget {
  const ServiceLocationPicker({
    super.key,
    required this.address,
    required this.onSelected,
    this.origin,
    this.pinTitle = 'Pin the service address',
    this.preserveAddressText = false,
    this.lookupAddress,
  });
  final TextEditingController address;
  final GeoPoint? origin;
  final String pinTitle;
  final bool preserveAddressText;
  final Future<Map<String, dynamic>> Function(String)? lookupAddress;
  final ValueChanged<GeoPoint> onSelected;
  @override
  State<ServiceLocationPicker> createState() => _ServiceLocationPickerState();
}

class _ServiceLocationPickerState extends State<ServiceLocationPicker> {
  bool _busy = false;
  Future<void> _lookup() async {
    setState(() => _busy = true);
    try {
      final requested = widget.address.text.trim();
      final Map<String, dynamic> data;
      if (widget.lookupAddress != null) {
        data = await widget.lookupAddress!(requested);
      } else {
        final result = await FirebaseFunctions.instanceFor(
          region: kNeighborHelpFunctionsRegion,
        ).httpsCallable('geocodeServiceAddress').call({'address': requested});
        data = Map<String, dynamic>.from(result.data as Map);
      }
      if (!mounted || widget.address.text.trim() != requested) return;
      if (!widget.preserveAddressText) {
        widget.address.text = data['address'] as String;
      }
      widget.onSelected(
        GeoPoint(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FirebaseFunctionsException &&
                      error.code == 'failed-precondition'
                  ? 'Address lookup is unavailable. Choose a map pin or use your current location.'
                  : 'Could not locate the address. Add your barangay and city, or choose a map pin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pin() async {
    final origin = geoPointOrNull(widget.origin);
    var selected = LatLng(
      origin?.latitude ?? kDefaultPanaboLatLng.latitude,
      origin?.longitude ?? kDefaultPanaboLatLng.longitude,
    );
    var chosen = false;
    final result = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(widget.pinTitle),
          content: SizedBox(
            width: 600,
            height: 360,
            child: GoogleMap(
              mapType: MapType.normal,
              minMaxZoomPreference: const MinMaxZoomPreference(6, 17),
              initialCameraPosition: CameraPosition(target: selected, zoom: 14),
              onTap: (point) => update(() {
                selected = point;
                chosen = true;
              }),
              markers: chosen
                  ? {
                      Marker(
                        markerId: const MarkerId('service'),
                        position: selected,
                      ),
                    }
                  : {},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosen ? () => Navigator.pop(ctx, selected) : null,
              child: const Text('Use this pin'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      widget.onSelected(GeoPoint(result.latitude, result.longitude));
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      TextButton.icon(
        onPressed: _busy ? null : _lookup,
        icon: const Icon(Icons.search),
        label: Text(_busy ? 'Locating…' : 'Locate address'),
      ),
      TextButton.icon(
        onPressed: _busy ? null : _pin,
        icon: const Icon(Icons.pin_drop_outlined),
        label: const Text('Choose map pin'),
      ),
    ],
  );
}
