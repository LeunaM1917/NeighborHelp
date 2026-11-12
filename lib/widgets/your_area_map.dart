import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../figma_ui/figma_colors.dart';
import '../models/app_user.dart';
import '../models/provider.dart';
import '../services/firestore_service.dart';
import '../services/provider_map_marker.dart';
import '../ui/app_ui_kit.dart';
import '../utils/geo_location.dart';
import '../utils/customer_map_data.dart';
import 'data_stream_builder.dart';
import 'profile_location_editor.dart';
import 'provider_map_alternative.dart';
import '../screens/customer/scheduled_provider_search_screen.dart';
export '../utils/customer_map_data.dart' show NearbyMapPin;

class YourAreaMapCard extends StatefulWidget {
  const YourAreaMapCard({super.key, required this.appUser, this.height = 500});
  final AppUser appUser;
  final double height;
  @override
  State<YourAreaMapCard> createState() => _YourAreaMapCardState();
}

class _YourAreaMapCardState extends State<YourAreaMapCard> {
  final _firestore = FirestoreService();
  int _revision = 0;
  bool _saving = false;
  Future<void> _setLocation() async {
    final point = await showProfileLocationDialog(
      context,
      initialLocation: widget.appUser.location,
      initialAddress: widget.appUser.address ?? '',
    );
    if (point == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _firestore.updateUserProfile(
        userId: widget.appUser.userId,
        data: {'location': point},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your map location was saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your location. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = geoPointOrNull(widget.appUser.location);
    final position = location == null ? null : latLngFromGeoPoint(location);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your Area',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: FigmaColors.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            position == null
                ? 'Set your location to see where providers can serve you. Showing Panabo City for now.'
                : 'Your saved location and providers whose service area reaches you.',
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ScheduledProviderSearchScreen(appUser: widget.appUser),
                  ),
                ),
                icon: const Icon(Icons.event_available),
                label: const Text('Find providers for a date'),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _setLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _saving
                      ? 'Saving?'
                      : position == null
                      ? 'Set my location'
                      : 'Change my location',
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _revision++),
                icon: const Icon(Icons.refresh),
                label: const Text('Reload map'),
              ),
            ],
          ),
          DataStreamBuilder<List<ServiceProviderProfile>>(
            stream: _firestore.serviceProvidersStream(),
            label: 'map providers',
            onRetry: () => _firestore.retryDataLoads(),
            builder: (context, providerSnap) => DataStreamBuilder<List<AppUser>>(
              stream: _firestore.allUsersStream(),
              label: 'provider names',
              onRetry: () => _firestore.retryDataLoads(),
              builder: (context, userSnap) {
                final providers = providerSnap.data ?? [];
                final pins = buildNearbyMapPins(
                  providers: providers,
                  origin: widget.appUser.location,
                  users: {for (final u in userSnap.data ?? []) u.userId: u},
                );
                final missing = providers
                    .where((p) => geoPointOrNull(p.location) == null)
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: widget.height,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: YourAreaMapView(
                          key: ValueKey(_revision),
                          userPosition: position,
                          pins: pins,
                          interactive: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (position != null) const Text('Blue dot: you'),
                        Text('Provider pins: ${pins.length}'),
                        TextButton.icon(
                          onPressed: () =>
                              _openExpandedMap(context, pins, position),
                          icon: const Icon(Icons.open_in_full),
                          label: const Text('Expand map'),
                        ),
                      ],
                    ),
                    if (missing > 0)
                      Text(
                        '$missing provider(s) still need to select their barangays before they can appear on this map.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (pins.isEmpty && missing == 0)
                      const Text(
                        'No providers with selected service barangays cover this area yet.',
                      ),
                    ProviderMapAlternative(pins: pins),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openExpandedMap(
    BuildContext context,
    List<NearbyMapPin> pins,
    LatLng? position,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: math.min(960, MediaQuery.sizeOf(ctx).width - 32),
          height: math.min(720, MediaQuery.sizeOf(ctx).height - 48),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Your Area')),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: YourAreaMapView(userPosition: position, pins: pins),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marker visibility never waits for photos or network image decoding.
class YourAreaMapView extends StatefulWidget {
  const YourAreaMapView({
    super.key,
    required this.userPosition,
    required this.pins,
    this.interactive = true,
  });
  final LatLng? userPosition;
  final List<NearbyMapPin> pins;
  final bool interactive;
  @override
  State<YourAreaMapView> createState() => _YourAreaMapViewState();
}

class _YourAreaMapViewState extends State<YourAreaMapView> {
  GoogleMapController? _controller;
  BitmapDescriptor? _customerIcon;
  static Future<BitmapDescriptor>? _icon;
  static Future<BitmapDescriptor>? _providerFallback;
  BitmapDescriptor? _providerFallbackIcon;
  final _providerIcons = <String, BitmapDescriptor>{};
  final _photoUrls = <String, String>{};
  @override
  void initState() {
    super.initState();
    unawaited(_loadIcon());
    unawaited(_loadProviderFallback());
    _syncProviderPhotos();
  }

  Future<void> _loadProviderFallback() async {
    try {
      final icon = await (_providerFallback ??= createProviderMapIcon());
      if (mounted) setState(() => _providerFallbackIcon = icon);
    } catch (_) {
      _providerFallback = null;
    }
  }

  void _syncProviderPhotos() {
    final ids = widget.pins.map((p) => p.id).toSet();
    _providerIcons.removeWhere((id, _) => !ids.contains(id));
    _photoUrls.removeWhere((id, _) => !ids.contains(id));
    for (final pin in widget.pins) {
      final url = pin.photoUrl?.trim() ?? '';
      if (_photoUrls[pin.id] == url) continue;
      _photoUrls[pin.id] = url;
      _providerIcons.remove(pin.id);
      if (url.isNotEmpty) unawaited(_loadProviderPhoto(pin.id, url));
    }
  }

  Future<void> _loadProviderPhoto(String id, String url) async {
    try {
      final icon = await createProviderMapIcon(photo: NetworkImage(url));
      if (mounted && _photoUrls[id] == url) {
        setState(() => _providerIcons[id] = icon);
      }
    } catch (_) {
      // Keep the visible fallback marker if bitmap rendering fails.
    }
  }

  Future<void> _loadIcon() async {
    try {
      final icon = await (_icon ??= _createCustomerIcon());
      if (mounted) setState(() => _customerIcon = icon);
    } catch (_) {
      _icon = null;
    }
  }

  String _geometry(YourAreaMapView view) => [
    view.userPosition.toString(),
    ...(view.pins.map((p) => '${p.id}:${p.position}').toList()..sort()),
  ].join('|');
  @override
  void didUpdateWidget(covariant YourAreaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncProviderPhotos();
    if (_geometry(oldWidget) != _geometry(widget)) unawaited(_fitCamera());
  }

  Future<void> _fitCamera() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      await controller.moveCamera(
        customerAreaCamera(customer: widget.userPosition, pins: widget.pins),
      );
    } catch (_) {
      if (!mounted || !identical(controller, _controller)) return;
      try {
        await controller.moveCamera(
          CameraUpdate.newLatLngZoom(
            widget.userPosition ?? kDefaultPanaboLatLng,
            13,
          ),
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GoogleMap(
    initialCameraPosition: CameraPosition(
      target: widget.userPosition ?? kDefaultPanaboLatLng,
      zoom: 13,
    ),
    mapType: MapType.normal,
    minMaxZoomPreference: const MinMaxZoomPreference(6, 17),
    markers: customerAreaMarkers(
      customer: widget.userPosition,
      pins: widget.pins,
      customerIcon: _customerIcon,
      providerIcons: _providerIcons,
      providerFallbackIcon: _providerFallbackIcon,
    ),
    myLocationButtonEnabled: false,
    zoomControlsEnabled: widget.interactive,
    scrollGesturesEnabled: widget.interactive,
    zoomGesturesEnabled: widget.interactive,
    rotateGesturesEnabled: false,
    tiltGesturesEnabled: false,
    mapToolbarEnabled: false,
    onMapCreated: (controller) {
      _controller = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(controller, _controller)) {
          unawaited(_fitCamera());
        }
      });
    },
  );
}

Future<BitmapDescriptor> _createCustomerIcon() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(const Offset(24, 24), 21, Paint()..color = Colors.white);
  canvas.drawCircle(
    const Offset(24, 24),
    16,
    Paint()..color = const Color(0xff2563eb),
  );
  canvas.drawCircle(const Offset(24, 24), 5, Paint()..color = Colors.white);
  final picture = recorder.endRecording();
  final image = await picture.toImage(48, 48);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: 36,
    height: 36,
  );
}
