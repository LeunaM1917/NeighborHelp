import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void setUpOfflineFonts() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Supply font assets in memory so layout tests never need network access.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin' || key == 'AssetManifest.bin.json') {
            final manifest = const StandardMessageCodec().encodeMessage({
              for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold'])
                'test-fonts/Inter-$weight.ttf': [
                  {'asset': 'test-fonts/Inter-$weight.ttf'},
                ],
            })!;
            return key.endsWith('.json')
                ? ByteData.sublistView(
                    utf8.encode(
                      jsonEncode(base64Encode(manifest.buffer.asUint8List())),
                    ),
                  )
                : manifest;
          }
          if (key == 'AssetManifest.json') {
            return ByteData.sublistView(
              utf8.encode(
                jsonEncode({
                  for (final weight in [
                    'Regular',
                    'Medium',
                    'SemiBold',
                    'Bold',
                  ])
                    'test-fonts/Inter-$weight.ttf': [
                      'test-fonts/Inter-$weight.ttf',
                    ],
                }),
              ),
            );
          }
          if (key.startsWith('test-fonts/')) return ByteData(0);
          return null;
        });
  });

  tearDown(() {
    GoogleFonts.config.allowRuntimeFetching = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
}

void testOnPlatform(
  String description,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.windows,
}) {
  testWidgets(
    description,
    (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip:
        kIsWeb &&
        (platform == TargetPlatform.android || platform == TargetPlatform.iOS),
  );
}
