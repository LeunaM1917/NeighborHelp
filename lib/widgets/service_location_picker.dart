import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/functions_config.dart';

class ServiceLocationPicker extends StatefulWidget {
  const ServiceLocationPicker({
    super.key,
    required this.address,
    required this.onSelected,
    this.origin,
  });
  final TextEditingController address;
  final GeoPoint? origin;
  final ValueChanged<GeoPoint> onSelected;
  @override
  State<ServiceLocationPicker> createState() => _ServiceLocationPickerState();
}

class _ServiceLocationPickerState extends State<ServiceLocationPicker> {
  bool _busy = false;
  Future<void> _lookup() async {
    setState(() => _busy = true);
    try {
      final result =
          await FirebaseFunctions.instanceFor(
            region: kNeighborHelpFunctionsRegion,
          ).httpsCallable('geocodeServiceAddress').call({
            'address': widget.address.text.trim(),
          });
      final data = Map<String, dynamic>.from(result.data as Map);
      widget.address.text = data['address'] as String;
      widget.onSelected(
        GeoPoint(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not locate the address. Add your barangay and city, or choose a map pin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pin() async {
    var selected = LatLng(
      widget.origin?.latitude ?? 7.3081,
      widget.origin?.longitude ?? 125.6842,
    );
    var chosen = false;
    final result = await showDialog<LatLng>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Pin the service address'),
          content: SizedBox(
            width: 600,
            height: 360,
            child: GoogleMap(
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
