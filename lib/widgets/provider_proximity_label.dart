import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../services/distance_service.dart';
import '../utils/geo_location.dart';

/// Subtitle for a nearby provider row: area, straight-line, or driving distance.
class ProviderProximityLabel extends StatefulWidget {
  const ProviderProximityLabel({
    super.key,
    required this.customer,
    required this.profile,
    this.style,
  });

  final AppUser customer;
  final ServiceProviderProfile profile;
  final TextStyle? style;

  @override
  State<ProviderProximityLabel> createState() => _ProviderProximityLabelState();
}

class _ProviderProximityLabelState extends State<ProviderProximityLabel> {
  String? _label;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ProviderProximityLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customer.location != widget.customer.location ||
        oldWidget.profile.location != widget.profile.location ||
        oldWidget.profile.serviceArea != widget.profile.serviceArea) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _label = null;
    });

    final text = await _buildLabel(widget.customer, widget.profile);
    if (!mounted) return;
    setState(() {
      _label = text;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        GoogleFonts.inter(fontSize: 13, color: FigmaColors.gray500);

    if (_loading && _label == null) {
      return Text('…', maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return Text(
      _label ?? 'Nearby',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

Future<String> _buildLabel(AppUser customer, ServiceProviderProfile profile) async {
  final area = profile.serviceArea.trim();
  final customerLoc = geoPointOrNull(customer.location);
  final providerLoc = geoPointOrNull(profile.location);

  if (customerLoc == null) {
    return area.isNotEmpty ? area : 'In your community';
  }
  if (providerLoc == null) {
    return area.isNotEmpty ? area : 'Nearby';
  }

  final straightKm = DistanceService.instance.straightLineKm(customerLoc, providerLoc);
  if (area.isNotEmpty && (straightKm > 80 || isDefaultSignupLocation(providerLoc))) {
    return area;
  }

  final driving = await DistanceService.instance.drivingDistancesKm(
    origin: customerLoc,
    destinations: [(id: profile.providerId, point: providerLoc)],
  );
  final drivingKm = driving[profile.providerId];
  if (drivingKm != null) {
    return formatDistanceKm(drivingKm, isDriving: true);
  }
  return formatDistanceKm(straightKm);
}

/// Batch-resolve driving distances for provider list subtitles (fewer API calls).
Future<Map<String, String>> resolveProviderProximityLabels({
  required AppUser customer,
  required List<ServiceProviderProfile> profiles,
}) async {
  final labels = <String, String>{};
  final customerLoc = geoPointOrNull(customer.location);
  if (customerLoc == null) {
    for (final p in profiles) {
      final area = p.serviceArea.trim();
      labels[p.providerId] = area.isNotEmpty ? area : 'In your community';
    }
    return labels;
  }

  final forDriving = <({String id, GeoPoint point})>[];
  for (final p in profiles) {
    final area = p.serviceArea.trim();
    final providerLoc = geoPointOrNull(p.location);
    if (providerLoc == null) {
      labels[p.providerId] = area.isNotEmpty ? area : 'Nearby';
      continue;
    }
    final straightKm = DistanceService.instance.straightLineKm(customerLoc, providerLoc);
    if (area.isNotEmpty && (straightKm > 80 || isDefaultSignupLocation(providerLoc))) {
      labels[p.providerId] = area;
      continue;
    }
    forDriving.add((id: p.providerId, point: providerLoc));
  }

  final drivingKm = await DistanceService.instance.drivingDistancesKm(
    origin: customerLoc,
    destinations: forDriving,
  );

  for (final entry in forDriving) {
    final straightKm = DistanceService.instance.straightLineKm(customerLoc, entry.point);
    final road = drivingKm[entry.id];
    labels[entry.id] = road != null ? formatDistanceKm(road, isDriving: true) : formatDistanceKm(straightKm);
  }

  return labels;
}
