import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<ui.Image> _resolvePhoto(ImageProvider photo) async {
  final result = Completer<ui.Image>();
  final stream = photo.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      if (!result.isCompleted) result.complete(info.image.clone());
    },
    onError: (Object error, StackTrace? stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    return await result.future.timeout(const Duration(seconds: 8));
  } finally {
    stream.removeListener(listener);
  }
}

/// A circular profile photo, with a neutral avatar when a photo is unavailable.
Future<BitmapDescriptor> createProviderMapIcon({ImageProvider? photo}) async {
  ui.Image? portrait;
  if (photo != null) {
    try {
      portrait = await _resolvePhoto(photo);
    } catch (_) {
      // A broken profile photo must not remove a provider from the map.
    }
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const center = Offset(56, 56);
  final outline = Path()..addOval(Rect.fromCircle(center: center, radius: 50));
  canvas.drawShadow(outline, Colors.black.withValues(alpha: .35), 3, true);
  canvas.drawCircle(center, 50, Paint()..color = Colors.white);
  canvas.drawCircle(center, 47, Paint()..color = const Color(0xff4d7c2e));
  const face = Rect.fromLTWH(12, 12, 88, 88);
  canvas.save();
  canvas.clipPath(Path()..addOval(face));
  if (portrait != null) {
    final edge = math.min(portrait.width, portrait.height).toDouble();
    canvas.drawImageRect(
      portrait,
      Rect.fromLTWH(
        (portrait.width - edge) / 2,
        (portrait.height - edge) / 2,
        edge,
        edge,
      ),
      face,
      Paint()..filterQuality = FilterQuality.high,
    );
  } else {
    canvas.drawCircle(center, 44, Paint()..color = const Color(0xffe8f2df));
    final paint = Paint()..color = const Color(0xff4d7c2e);
    canvas.drawCircle(const Offset(56, 42), 13, paint);
    canvas.drawOval(const Rect.fromLTWH(28, 61, 56, 48), paint);
  }
  canvas.restore();
  portrait?.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(112, 112);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 48,
      height: 48,
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}
