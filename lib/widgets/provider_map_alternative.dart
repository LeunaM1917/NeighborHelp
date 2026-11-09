import 'package:flutter/material.dart';
import '../utils/customer_map_data.dart';

/// The same providers as the map, available to keyboards and screen readers.
class ProviderMapAlternative extends StatelessWidget {
  const ProviderMapAlternative({super.key, required this.pins});
  final List<NearbyMapPin> pins;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text('Provider list (${pins.length})'),
    subtitle: const Text(
      'Alternative to the map. Pins show approximate barangay centers.',
    ),
    children: [
      for (final pin in pins)
        ListTile(
          title: Text(pin.label),
          subtitle: Text(
            pin.area.isEmpty ? 'Approximate service barangay' : pin.area,
          ),
        ),
    ],
  );
}
