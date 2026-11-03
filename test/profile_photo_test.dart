import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/utils/image_upload.dart';
import 'package:neighbor_help/widgets/profile_avatar.dart';

void main() {
  test('JPEG, PNG and WebP content determines the upload MIME type', () {
    expect(
      ImageUploadFormat.inspect(
        Uint8List.fromList([255, 216, 255, 224]),
      ).contentType,
      'image/jpeg',
    );
    expect(
      ImageUploadFormat.inspect(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ).extension,
      'png',
    );
    expect(
      ImageUploadFormat.inspect(
        Uint8List.fromList('RIFF0000WEBP'.codeUnits),
      ).contentType,
      'image/webp',
    );
  });

  test(
    'empty, unsupported and oversized photos are rejected before uploading',
    () {
      expect(
        () => ImageUploadFormat.inspect(Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => ImageUploadFormat.inspect(
          Uint8List.fromList('not an image'.codeUnits),
        ),
        throwsArgumentError,
      );
      expect(
        () => ImageUploadFormat.inspect(
          Uint8List(ImageUploadFormat.maxBytes + 1),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'upload errors distinguish validation, permissions, connectivity and profile saving',
    () {
      expect(
        profilePhotoError(ArgumentError('Choose a smaller image.')),
        'Choose a smaller image.',
      );
      expect(
        profilePhotoError(
          FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
        ),
        contains('Sign in again'),
      );
      expect(
        profilePhotoError(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'retry-limit-exceeded',
          ),
        ),
        contains('timed out'),
      );
      expect(
        profilePhotoError(StateError('save'), uploaded: true),
        contains('uploaded, but your profile could not be saved'),
      );
    },
  );

  for (final width in [360.0, 1280.0]) {
    testWidgets('profile initials survive a failed image at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileAvatar(
              photoUrl: 'https://example.invalid/missing-photo.jpg',
              fallback: Text('KH'),
            ),
          ),
        ),
      );
      // The widget test HTTP client returns 400: exercise the actual image error path.
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('KH'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('blank photo URLs render initials without a network request', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(photoUrl: ' ', fallback: Text('KH')),
        ),
      ),
    );
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.foregroundImage, isNull);
    expect(find.text('KH'), findsOneWidget);
  });
}
