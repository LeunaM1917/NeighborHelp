import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';

class ImageUploadFormat {
  const ImageUploadFormat(this.extension, this.contentType);
  final String extension;
  final String contentType;
  static const maxBytes = 5 * 1024 * 1024;

  static ImageUploadFormat inspect(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('The selected image is empty. Choose another photo.');
    }
    if (bytes.length > maxBytes) {
      throw ArgumentError('Choose a photo up to 5 MB.');
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return const ImageUploadFormat('jpg', 'image/jpeg');
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= png.length &&
        List.generate(png.length, (i) => bytes[i] == png[i]).every((b) => b)) {
      return const ImageUploadFormat('png', 'image/png');
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return const ImageUploadFormat('webp', 'image/webp');
    }
    throw ArgumentError(
      'Choose a JPG, PNG or WebP photo. Convert HEIC photos before uploading.',
    );
  }
}

String profilePhotoError(Object error, {bool uploaded = false}) {
  if (uploaded) {
    return 'The photo uploaded, but your profile could not be saved. Please try again.';
  }
  if (error is ArgumentError && error.message is String) {
    return error.message as String;
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'Your account cannot upload this photo. Sign in again and try again.';
      case 'unauthenticated':
        return 'Sign in again before uploading a photo.';
      case 'retry-limit-exceeded':
        return 'Photo upload timed out. Check your connection and try again.';
      case 'canceled':
        return 'Photo upload was cancelled.';
    }
  }
  return 'Could not upload your photo. Check your connection and try again.';
}
