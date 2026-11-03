import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:neighbor_help/models/app_user.dart';
import 'package:neighbor_help/models/provider.dart';
import 'package:neighbor_help/utils/customer_map_data.dart';
import 'package:neighbor_help/utils/geo_location.dart';
import 'package:neighbor_help/widgets/customer_service_card.dart';
import 'package:neighbor_help/widgets/profile_location_editor.dart';
import 'package:neighbor_help/widgets/provider_proximity_label.dart';
import 'package:neighbor_help/widgets/your_area_map.dart';
import 'support/ui_test_support.dart';

class _Maps extends MethodChannelGoogleMapsFlutter {
  final ids = <int>{};
  final cameras = <dynamic>[];
  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates updates, {
    required int mapId,
  }) async {}
  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    if (ids.add(creationId)) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('plugins.flutter.io/google_maps_$creationId'),
            (call) async {
              if (call.method == 'camera#move') cameras.add(call.arguments);
              return null;
            },
          );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onPlatformViewCreated(creationId),
      );
    }
    return SizedBox.expand(key: ValueKey('map-$creationId'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpOfflineFonts();
  late GoogleMapsFlutterPlatform previous;
  late _Maps maps;
  setUp(() {
    previous = GoogleMapsFlutterPlatform.instance;
    maps = _Maps();
    GoogleMapsFlutterPlatform.instance = maps;
  });
  tearDown(() {
    GoogleMapsFlutterPlatform.instance = previous;
    for (final id in maps.ids) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('plugins.flutter.io/google_maps_$id'),
            null,
          );
    }
  });
  ServiceProviderProfile provider(
    String id, {
    GeoPoint? point,
    double radius = 15,
  }) => ServiceProviderProfile.fromFirestore(id, {
    'userId': id,
    'isVerified': true,
    'location': point,
    'serviceRadiusKm': radius,
  });
  final origin = GeoPoint(
    kDefaultPanaboLatLng.latitude,
    kDefaultPanaboLatLng.longitude,
  );

  test(
    'signup placeholders and absent GPS never become real customer/provider coordinates',
    () {
      expect(geoPointOrNull(null), isNull);
      expect(geoPointOrNull(const GeoPoint(0, 0)), isNull);
      expect(geoPointOrNull(kDefaultSignupGeoPoint), isNull);
      expect(geoPointOrNull(const GeoPoint(14.6, 120.985)), isNotNull);
      final result = CustomerProviderDiscovery(
        providers: [provider('p', point: kDefaultSignupGeoPoint)],
        origin: origin,
      );
      expect(result.nearby, isEmpty);
      expect(result.awaitingLocation, hasLength(1));
      expect(
        buildNearbyMapPins(
          providers: [provider('p', point: kDefaultSignupGeoPoint)],
          users: {},
          origin: origin,
        ),
        isEmpty,
      );
    },
  );
  test(
    'previously hired providers remain in nearby results when they cover the customer',
    () {
      final p = provider('hired', point: const GeoPoint(7.309, 125.684));
      final result = CustomerProviderDiscovery(providers: [p], origin: origin);
      expect(result.nearby.single.profile.providerId, 'hired');
      expect(result.hiredBefore({'hired'}).single.profile.providerId, 'hired');
      expect(
        buildNearbyMapPins(providers: [p], users: {}, origin: origin).single.id,
        'hired',
      );
    },
  );
  test(
    'provider radius and customer search radius still exclude out-of-coverage locations',
    () {
      final result = CustomerProviderDiscovery(
        providers: [
          provider('in', point: const GeoPoint(7.309, 125.684)),
          provider('far', point: const GeoPoint(8.0, 125.684), radius: 100),
          provider(
            'outside-base',
            point: const GeoPoint(7.35, 125.684),
            radius: 1,
          ),
        ],
        origin: origin,
      );
      expect(result.nearby.map((r) => r.profile.providerId), ['in']);
    },
  );
  test('there is no fake customer pin; providers do not wait for a photo', () {
    final pin = NearbyMapPin(
      id: 'p',
      position: const LatLng(7.31, 125.68),
      label: 'Provider',
      photoUrl: 'https://invalid.example/photo.jpg',
    );
    expect(
      customerAreaMarkers(
        customer: null,
        pins: [pin],
      ).map((m) => m.markerId.value),
      ['p'],
    );
    expect(
      customerAreaMarkers(customer: const LatLng(7.3, 125.6), pins: [pin]),
      hasLength(2),
    );
  });
  test('identical customer/provider positions use a safe fixed zoom', () {
    const point = LatLng(7.3, 125.6);
    final camera =
        customerAreaCamera(
              customer: point,
              pins: [const NearbyMapPin(id: 'p', position: point, label: 'P')],
            ).toJson()
            as List;
    expect(camera.first, 'newLatLngZoom');
    expect(camera.last, lessThanOrEqualTo(17));
  });
  test(
    'unknown provider coordinates never produce a misleading nearby label',
    () async {
      final customer = AppUser.fromFirestore('c', {'location': origin});
      final labels = await resolveProviderProximityLabels(
        customer: customer,
        profiles: [provider('p', point: kDefaultSignupGeoPoint)],
      );
      expect(labels['p'], 'Map location not set');
    },
  );
  testWidgets(
    'map is immediately mounted and stays mounted as marker data changes',
    (tester) async {
      Widget app(List<NearbyMapPin> pins) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: YourAreaMapView(
              userPosition: const LatLng(7.3, 125.6),
              pins: pins,
              interactive: false,
            ),
          ),
        ),
      );
      final pin = NearbyMapPin(
        id: 'p',
        position: const LatLng(7.31, 125.6),
        label: 'P',
        photoUrl: 'https://invalid.example/photo.jpg',
      );
      await tester.pumpWidget(app([pin]));
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers, hasLength(2));
      expect(map.mapType, MapType.normal);
      expect(map.minMaxZoomPreference.maxZoom, 17);
      expect(map.scrollGesturesEnabled, isFalse);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
      await tester.pumpWidget(
        app([
          pin,
          const NearbyMapPin(
            id: 'second',
            position: LatLng(7.32, 125.6),
            label: 'Second',
          ),
        ]),
      );
      await tester.pump();
      expect(maps.ids, hasLength(1));
      expect(
        tester.widget<GoogleMap>(find.byType(GoogleMap)).markers,
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('map pin selection reaches the profile location callback', (
    tester,
  ) async {
    final address = TextEditingController();
    GeoPoint? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileLocationEditor(
            address: address,
            location: null,
            onChanged: (p) => chosen = p,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose map pin'));
    await tester.pumpAndSettle();
    tester.widget<GoogleMap>(find.byType(GoogleMap)).onTap!(
      const LatLng(7.31, 125.68),
    );
    await tester.pump();
    await tester.tap(find.text('Use this pin'));
    await tester.pumpAndSettle();
    expect(chosen, const GeoPoint(7.31, 125.68));
    await tester.pumpWidget(const SizedBox());
    address.dispose();
  });
  testWidgets(
    'GPS permission is only requested on a user action and denial keeps manual pin available',
    (tester) async {
      final calls = <String>[];
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return call.method == 'isLocationServiceEnabled' ? true : 0;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final address = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileLocationEditor(
              address: address,
              location: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(calls, isEmpty);
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(calls, contains('requestPermission'));
      expect(calls, isNot(contains('getCurrentPosition')));
      expect(find.textContaining('Location access is blocked'), findsOneWidget);
      expect(find.text('Choose map pin'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      address.dispose();
    },
  );
  for (final valid in [true, false]) {
    testWidgets(
      'current-location selection validates device coordinates (valid=$valid)',
      (tester) async {
        const channel = MethodChannel('flutter.baseflow.com/geolocator');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'isLocationServiceEnabled') return true;
              if (call.method == 'checkPermission') return 2;
              if (call.method == 'getCurrentPosition') {
                return {
                  'latitude': valid ? 7.31 : 0.0,
                  'longitude': valid ? 125.68 : 0.0,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'accuracy': 10.0,
                  'altitude': 0.0,
                  'altitude_accuracy': 0.0,
                  'heading': 0.0,
                  'heading_accuracy': 0.0,
                  'speed': 0.0,
                  'speed_accuracy': 0.0,
                };
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final address = TextEditingController();
        GeoPoint? chosen;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileLocationEditor(
                address: address,
                location: null,
                onChanged: (point) => chosen = point,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Use my current location'));
        await tester.pumpAndSettle();
        if (valid) {
          expect(chosen, const GeoPoint(7.31, 125.68));
        } else {
          expect(chosen, isNull);
          expect(
            find.textContaining('A valid location was not returned'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox());
        address.dispose();
      },
    );
  }

  for (final width in [200.0, 360.0, 1280.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'service card fits two-line ratings at width $width and text scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1400, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      height: CustomerServiceCard.heightFor(
                        TextScaler.linear(scale),
                      ),
                      child: CustomerServiceCard(
                        title: 'House cleaning and maintenance',
                        category: 'Cleaning services',
                        imageUrl: 'assets/not-present.png',
                        providerName: 'A provider with a long display name',
                        price: 12500,
                        onTap: () {},
                        rating: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '4.8 (1200)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Overall 4.9 (2500)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
