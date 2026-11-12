import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:neighbor_help/services/provider_map_marker.dart';
import 'package:neighbor_help/utils/customer_map_data.dart';

void main() {
  testWidgets(
    'provider markers contain the profile photo and retain a fallback on image errors',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 20, 40),
          Paint()..color = const Color(0xffce7149),
        );
        final picture = recorder.endRecording();
        final photo = await picture.toImage(20, 40);
        final png = await photo.toByteData(format: ui.ImageByteFormat.png);
        photo.dispose();
        picture.dispose();
        final icon =
            await createProviderMapIcon(
                  photo: MemoryImage(png!.buffer.asUint8List()),
                )
                as BytesMapBitmap;
        final codec = await ui.instantiateImageCodec(icon.byteData);
        final frame = await codec.getNextFrame();
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final center = (56 * 112 + 56) * 4;
        expect(pixels!.buffer.asUint8List().sublist(center, center + 4), [
          206,
          113,
          73,
          255,
        ]);
        expect(
          pixels.getUint8(3),
          0,
        ); // Circular avatar leaves transparent corners.
        frame.image.dispose();
        codec.dispose();
        final fallback = await createProviderMapIcon() as BytesMapBitmap;
        final broken =
            await createProviderMapIcon(
                  photo: MemoryImage(Uint8List.fromList([1, 2, 3])),
                )
                as BytesMapBitmap;
        expect(broken.byteData, fallback.byteData);
        final markers = customerAreaMarkers(
          customer: const LatLng(7.3, 125.6),
          pins: [
            const NearbyMapPin(
              id: 'p',
              position: LatLng(7.31, 125.6),
              label: 'Provider',
            ),
          ],
          providerIcons: {'p': icon},
          providerFallbackIcon: fallback,
        );
        final provider = markers.singleWhere((m) => m.markerId.value == 'p');
        expect(provider.icon, same(icon));
        expect(provider.anchor, const Offset(.5, .5));
        expect(provider.position, const LatLng(7.31, 125.6));
      });
      expect(tester.takeException(), isNull);
    },
  );
}
