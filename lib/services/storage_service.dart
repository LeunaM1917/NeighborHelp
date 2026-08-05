import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Returns download URL for a profile photo at `users/{uid}/profile.jpg`.
  Future<String> uploadProfilePhoto({
    required String userId,
    required dynamic file,
  }) async {
    final ref = _storage.ref().child('users').child(userId).child('profile.jpg');
    if (kIsWeb) {
      throw UnsupportedError('Use uploadProfilePhotoBytes on web.');
    }
    final upload = await ref.putFile(file as File);
    return upload.ref.getDownloadURL();
  }

  Future<String> uploadProfilePhotoBytes({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref().child('users').child(userId).child('profile.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<String> uploadServiceImage({
    required String providerId,
    required String serviceId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final ref = _storage
        .ref()
        .child('services')
        .child(providerId)
        .child(serviceId)
        .child(filename);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> uploadPortfolioPhoto({
    required String providerId,
    required String projectId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final ref = _storage
        .ref()
        .child('portfolio')
        .child(providerId)
        .child(projectId)
        .child(filename);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
