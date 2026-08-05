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
import '../services/provider_recommendation_service.dart';
import '../ui/app_ui_kit.dart';
import '../utils/geo_location.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/stream_snapshot.dart';

/// Map pin for the customer home "Your Area" widget.
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

/// "Your Area" map card (500px) — tap to open full-screen dialog.
class YourAreaMapCard extends StatefulWidget {
  const YourAreaMapCard({
    super.key,
    required this.appUser,
    this.height = 500,
  });

  final AppUser appUser;
  final double height;

  @override
  State<YourAreaMapCard> createState() => _YourAreaMapCardState();
}

class _YourAreaMapCardState extends State<YourAreaMapCard> {
  final FirestoreService _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your Area',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: FigmaColors.gray900),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ServiceProviderProfile>>(
            stream: _firestore.serviceProvidersStream(),
            builder: (context, providerSnap) {
              if (isStreamWaiting(providerSnap)) {
                return SizedBox(
                  height: widget.height,
                  child: const Center(child: LoadingIndicator(message: 'Loading map…')),
                );
              }
              return StreamBuilder<List<AppUser>>(
                stream: _firestore.allUsersStream(),
                builder: (context, userSnap) {
                  final Map<String, AppUser> users = {
                    for (final u in userSnap.data ?? []) u.userId: u,
                  };
                  final pins = _buildPins(
                    customer: widget.appUser,
                    providers: providerSnap.data ?? [],
                    users: users,
                  );
                  return _MapPreview(
                    height: widget.height,
                    userPosition: _userLatLng(widget.appUser),
                    pins: pins,
                    onTap: () => _openExpandedMap(context, pins),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _openExpandedMap(BuildContext context, List<NearbyMapPin> pins) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: math.min(960, MediaQuery.sizeOf(ctx).width - 48),
            height: math.min(720, MediaQuery.sizeOf(ctx).height - 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Area',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: YourAreaMapView(
                    userPosition: _userLatLng(widget.appUser),
                    pins: pins,
                    interactive: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.height,
    required this.userPosition,
    required this.pins,
    required this.onTap,
  });

  final double height;
  final LatLng userPosition;
  final List<NearbyMapPin> pins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: YourAreaMapView(
                  userPosition: userPosition,
                  pins: pins,
                  interactive: false,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: FigmaColors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full, size: 16, color: FigmaColors.gray700),
                      const SizedBox(width: 6),
                      Text('Expand map', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FigmaColors.gray700)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Google Map with user pin (green) and provider avatar pins.
class YourAreaMapView extends StatefulWidget {
  const YourAreaMapView({
    super.key,
    required this.userPosition,
    required this.pins,
    this.interactive = true,
  });

  final LatLng userPosition;
  final List<NearbyMapPin> pins;
  final bool interactive;

  @override
  State<YourAreaMapView> createState() => _YourAreaMapViewState();
}

class _YourAreaMapViewState extends State<YourAreaMapView> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};
  bool _iconsReady = false;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  @override
  void didUpdateWidget(covariant YourAreaMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pins != widget.pins || oldWidget.userPosition != widget.userPosition) {
      _loadMarkers();
    }
  }

  Future<void> _loadMarkers() async {
    setState(() => _iconsReady = false);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('you'),
        position: widget.userPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'You', snippet: 'Your location'),
        zIndexInt: 2,
      ),
    };

    for (final pin in widget.pins) {
      final icon = await _avatarMarkerIcon(
        photoUrl: pin.photoUrl,
        initials: pin.label.isNotEmpty ? pin.label[0].toUpperCase() : 'P',
      );
      markers.add(
        Marker(
          markerId: MarkerId(pin.id),
          position: pin.position,
          icon: icon,
          infoWindow: InfoWindow(title: pin.label, snippet: pin.isDemo ? 'Preview provider' : 'Service provider'),
          zIndexInt: 1,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
      _iconsReady = true;
    });
    _fitBounds();
  }

  Future<void> _fitBounds() async {
    final controller = _controller;
    if (controller == null) return;
    final points = [widget.userPosition, ...widget.pins.map((p) => p.position)];
    if (points.length < 2) return;

    var minLat = points.first.latitude;
    var maxLat = minLat;
    var minLng = points.first.longitude;
    var maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || _controller == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
    } catch (_) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(widget.userPosition, 13));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_iconsReady) {
      return const ColoredBox(
        color: FigmaColors.gray100,
        child: Center(child: LoadingIndicator(message: 'Loading map…')),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.userPosition, zoom: 13),
      markers: _markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: widget.interactive,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        _fitBounds();
      },
    );
  }
}

Future<BitmapDescriptor> _avatarMarkerIcon({
  required String? photoUrl,
  required String initials,
}) async {
  const size = 96.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  const radius = 36.0;

  canvas.drawCircle(center, radius + 5, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius + 2, Paint()..color = FigmaColors.gray200);
  canvas.drawCircle(center, radius, Paint()..color = FigmaColors.gray100);

  var drewPhoto = false;
  if (photoUrl != null && photoUrl.isNotEmpty) {
    try {
      final imageProvider = NetworkImage(photoUrl);
      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(const ImageConfiguration(size: Size(size, size)));
      late ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        stream.removeListener(listener);
        completer.complete(info);
      }, onError: (_, __) {
        stream.removeListener(listener);
        completer.completeError(Exception('image'));
      });
      stream.addListener(listener);
      final info = await completer.future.timeout(const Duration(seconds: 4));
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: center, radius: radius - 1),
        image: info.image,
        fit: BoxFit.cover,
      );
      drewPhoto = true;
    } catch (_) {
      drewPhoto = false;
    }
  }
  if (!drewPhoto) {
    final tp = TextPainter(
      text: TextSpan(
        text: initials,
        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: FigmaColors.gray700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 48, height: 48);
}

LatLng _userLatLng(AppUser user) {
  final loc = geoPointOrNull(user.location);
  if (loc != null) return latLngFromGeoPoint(loc);
  return kDefaultPanaboLatLng;
}

bool _hasRealProviderGeo(ServiceProviderProfile profile) {
  final loc = geoPointOrNull(profile.location);
  return loc != null && !isDefaultSignupLocation(loc);
}

LatLng _offsetKm(LatLng origin, double kmNorth, double kmEast) {
  final latRad = origin.latitude * math.pi / 180;
  final dLat = kmNorth / 111.0;
  final dLng = kmEast / (111.0 * math.cos(latRad));
  return LatLng(origin.latitude + dLat, origin.longitude + dLng);
}

List<NearbyMapPin> _buildPins({
  required AppUser customer,
  required List<ServiceProviderProfile> providers,
  required Map<String, AppUser> users,
}) {
  final origin = _userLatLng(customer);

  final ranked = rankProvidersByRecommendation(
    providers: providers,
    customerOrigin: customer.location,
  );
  final rankedWithGeo = ranked.where((r) => _hasRealProviderGeo(r.profile)).toList();

  if (rankedWithGeo.isNotEmpty) {
    return _pinsFromProfiles(
      rankedWithGeo.take(5).map((r) => r.profile).toList(),
      users: users,
      isDemo: false,
    );
  }

  // No ranked providers with real coordinates — optional preview offsets only.
  final verified = providers.where((p) => p.isVerifiedProvider).toList();
  final withoutRealGeo = verified.where((p) => !_hasRealProviderGeo(p)).toList();
  const demoOffsets = [
    (0.8, 1.2),
    (-1.0, 0.6),
    (0.4, -1.4),
    (-1.2, -0.8),
    (1.3, -0.5),
  ];
  var demoIndex = 0;
  final pins = <NearbyMapPin>[];
  for (final p in withoutRealGeo.take(5)) {
    final user = users[p.userId];
    final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'Provider';
    final off = demoOffsets[demoIndex % demoOffsets.length];
    demoIndex++;
    pins.add(
      NearbyMapPin(
        id: p.providerId,
        position: _offsetKm(origin, off.$1, off.$2),
        label: name,
        photoUrl: user?.profilePhotoUrl,
        isDemo: true,
      ),
    );
  }
  return pins;
}

List<NearbyMapPin> _pinsFromProfiles(
  List<ServiceProviderProfile> profiles, {
  required Map<String, AppUser> users,
  required bool isDemo,
}) {
  return [
    for (final p in profiles)
      NearbyMapPin(
        id: p.providerId,
        position: latLngFromGeoPoint(p.location),
        label: () {
          final user = users[p.userId];
          return user?.fullName.isNotEmpty == true ? user!.fullName : 'Provider';
        }(),
        photoUrl: users[p.userId]?.profilePhotoUrl,
        isDemo: isDemo,
      ),
  ];
}
