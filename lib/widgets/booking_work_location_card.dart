import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../figma_ui/figma_colors.dart';
import '../models/booking.dart';
import '../ui/app_ui_kit.dart';
import '../ui/workflow_ui.dart';
import '../utils/geo_location.dart';

/// Uses only the location saved with this private booking, never a profile pin.
Uri? bookingDirectionsUrl(Booking booking) {
  final point = geoPointOrNull(booking.location);
  final destination = point == null
      ? booking.serviceLocation.trim()
      : '${point.latitude},${point.longitude}';
  if (destination.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
  });
}

class BookingWorkLocationCard extends StatefulWidget {
  const BookingWorkLocationCard({
    super.key,
    required this.booking,
    required this.viewerId,
    this.openMaps,
  });
  final Booking booking;
  final String viewerId;
  final Future<bool> Function(Uri)? openMaps;
  @override
  State<BookingWorkLocationCard> createState() =>
      _BookingWorkLocationCardState();
}

class _BookingWorkLocationCardState extends State<BookingWorkLocationCard> {
  bool _opening = false;
  Future<void> _directions() async {
    if (_opening || widget.viewerId != widget.booking.providerId) return;
    final url = bookingDirectionsUrl(widget.booking);
    if (url == null) return;
    setState(() => _opening = true);
    try {
      final opened =
          await (widget.openMaps?.call(url) ??
              launchUrl(
                url,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (!opened) throw StateError('Maps could not open');
    } catch (_) {
      if (!mounted || widget.viewerId != widget.booking.providerId) return;
      final point = geoPointOrNull(widget.booking.location);
      await showDialog<void>(
        context: context,
        builder: (ctx) => WorkflowDialog(
          scrollable: true,
          title: const Text('Could not open Google Maps'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Allow your browser to open a new tab, or open Google Maps and search using the saved work location below. You can also confirm directions with the customer in messages.',
              ),
              const SizedBox(height: 12),
              SelectableText(widget.booking.serviceLocation.trim()),
              if (point != null)
                SelectableText('${point.latitude}, ${point.longitude}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewerId != widget.booking.providerId) {
      return const SizedBox.shrink();
    }
    final booking = widget.booking;
    final point = geoPointOrNull(booking.location);
    final position = point == null ? null : latLngFromGeoPoint(point);
    final hasAddress = booking.serviceLocation.trim().isNotEmpty;
    return AppSection(
      title: 'Work location',
      child: AppSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              hasAddress
                  ? booking.serviceLocation.trim()
                  : 'No street address was saved for this booking.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FigmaColors.gray900,
              ),
            ),
            const SizedBox(height: 12),
            if (position != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).width < 600 ? 220 : 260,
                  child: GoogleMap(
                    key: ValueKey(
                      'work-location:${booking.bookingId}:${position.latitude},${position.longitude}',
                    ),
                    initialCameraPosition: CameraPosition(
                      target: position,
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('work-location'),
                        position: position,
                        infoWindow: const InfoWindow(title: 'Work location'),
                      ),
                    },
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Work location saved with this booking. Confirm landmarks and access instructions in messages.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.5,
                  color: FigmaColors.gray600,
                ),
              ),
            ] else
              Text(
                hasAddress
                    ? 'No valid map pin was saved with this booking. Google Maps will search the address; ask the customer to confirm the exact work location.'
                    : 'Ask the customer to confirm the work address and pin in messages.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: FigmaColors.gray600,
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _opening || bookingDirectionsUrl(booking) == null
                  ? null
                  : _directions,
              icon: const Icon(Icons.directions_outlined),
              label: Text(
                _opening ? 'Opening Google Maps…' : 'Open in Google Maps',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
