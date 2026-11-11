import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:neighbor_help/models/booking.dart';
import 'package:neighbor_help/widgets/booking_work_location_card.dart';
import 'support/ui_test_support.dart';

class _Maps extends MethodChannelGoogleMapsFlutter {
  final ids = <int>{};
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
            (call) async => null,
          );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onPlatformViewCreated(creationId),
      );
    }
    return SizedBox.expand(key: ValueKey('map-$creationId'));
  }
}

Booking booking({
  GeoPoint point = const GeoPoint(7.3, 125.6),
  String address = 'New Visayas, Panabo City',
  String status = 'Pending',
}) => Booking.fromFirestore('private-booking', {
  'customerId': 'customer',
  'providerId': 'provider',
  'serviceId': 'service',
  'serviceLocation': address,
  'location': point,
  'status': status,
});

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

  Future<void> show(
    WidgetTester tester,
    Booking value, {
    double width = 390,
    String viewer = 'provider',
    Future<bool> Function(Uri)? open,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BookingWorkLocationCard(
              booking: value,
              viewerId: viewer,
              openMaps: open ?? (_) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'directions use exact saved pin without sending account or booking identifiers',
    () {
      final url = bookingDirectionsUrl(booking())!;
      expect(url.scheme, 'https');
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters, {'api': '1', 'destination': '7.3,125.6'});
      expect(url.toString(), isNot(contains('private-booking')));
      expect(url.toString(), isNot(contains('customer')));
      expect(url.queryParameters.containsKey('origin'), false);
    },
  );

  test(
    'legacy address search is encoded and missing locations have no directions URL',
    () {
      final value = booking(
        point: const GeoPoint(0, 0),
        address: 'Block 1 & 2, A. O. Floirendo',
      );
      final url = bookingDirectionsUrl(value)!;
      expect(url.queryParameters['destination'], value.serviceLocation);
      expect(url.queryParameters.keys, unorderedEquals(['api', 'destination']));
      expect(
        bookingDirectionsUrl(booking(point: const GeoPoint(0, 0), address: '')),
        isNull,
      );
      expect(
        bookingDirectionsUrl(
          booking(point: const GeoPoint(14.5995, 120.9842)),
        )!.queryParameters['destination'],
        'New Visayas, Panabo City',
      );
    },
  );

  for (final width in [390.0, 1280.0]) {
    testOnPlatform(
      'provider sees saved work pin and opens directions at $width',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Uri? opened;
        await show(
          tester,
          booking(),
          width: width,
          open: (url) async {
            opened = url;
            return true;
          },
        );
        expect(find.text('Work location'), findsOneWidget);
        expect(find.text('New Visayas, Panabo City'), findsOneWidget);
        final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
        expect(map.initialCameraPosition.target, const LatLng(7.3, 125.6));
        expect(map.markers.single.position, const LatLng(7.3, 125.6));
        expect(map.markers.single.draggable, false);
        expect(map.onTap, isNull);
        expect(map.myLocationEnabled, false);
        expect(map.myLocationButtonEnabled, false);
        await tester.tap(find.text('Open in Google Maps'));
        await tester.pumpAndSettle();
        expect(opened!.queryParameters['destination'], '7.3,125.6');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform(
    'work map follows saved booking updates without changing the pin',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final status in [
        'Pending',
        'Accepted',
        'In Progress',
        'Milestone Complete',
      ]) {
        await show(tester, booking(status: status));
        expect(
          tester
              .widget<GoogleMap>(find.byType(GoogleMap))
              .markers
              .single
              .position,
          const LatLng(7.3, 125.6),
        );
      }
      await show(tester, booking(point: const GeoPoint(7.31, 125.61)));
      expect(
        tester
            .widget<GoogleMap>(find.byType(GoogleMap))
            .initialCameraPosition
            .target,
        const LatLng(7.31, 125.61),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform('other viewers do not render the private location card', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final viewer in ['stranger', 'another-provider', 'customer']) {
      await show(tester, booking(), viewer: viewer);
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.text('New Visayas, Panabo City'), findsNothing);
      expect(find.text('Open in Google Maps'), findsNothing);
    }
  });

  testOnPlatform(
    'missing pin shows address-search guidance instead of a fabricated marker',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? opened;
      await show(
        tester,
        booking(point: const GeoPoint(0, 0)),
        open: (uri) async {
          opened = uri;
          return true;
        },
      );
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.textContaining('No valid map pin'), findsOneWidget);
      await tester.tap(find.text('Open in Google Maps'));
      await tester.pumpAndSettle();
      expect(
        opened!.queryParameters['destination'],
        'New Visayas, Panabo City',
      );
      await show(tester, booking(point: const GeoPoint(0, 0), address: ''));
      final button = tester.widget<OutlinedButton>(
        find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      expect(button.onPressed, isNull);
      expect(
        find.textContaining('Ask the customer to confirm'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final throws in [false, true]) {
    testOnPlatform(
      'failed maps launch shows a useful popup and permits retry (throws: $throws)',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await show(
          tester,
          booking(),
          open: (_) async {
            calls++;
            if (calls > 1) return true;
            if (throws) throw StateError('launch failed');
            return false;
          },
        );
        await tester.tap(find.text('Open in Google Maps'));
        await tester.pumpAndSettle();
        expect(find.text('Could not open Google Maps'), findsOneWidget);
        expect(find.text('7.3, 125.6'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open in Google Maps'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(find.text('Could not open Google Maps'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testOnPlatform(
    'directions cannot be opened twice while a launch is pending',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = Completer<bool>();
      var calls = 0;
      await show(
        tester,
        booking(),
        open: (_) {
          calls++;
          return result.future;
        },
      );
      await tester.tap(find.text('Open in Google Maps'));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byWidgetPredicate((w) => w is OutlinedButton),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      result.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Open in Google Maps'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testOnPlatform(
    'a failed pending launch does not show private details after the viewer changes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = Completer<bool>();
      await show(tester, booking(), open: (_) => result.future);
      await tester.tap(find.text('Open in Google Maps'));
      await tester.pump();
      await show(tester, booking(), viewer: 'another-provider');
      result.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Could not open Google Maps'), findsNothing);
      expect(find.text('New Visayas, Panabo City'), findsNothing);
      expect(find.byType(GoogleMap), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
