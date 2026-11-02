import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadCertificate({required String providerId, required String certificateId, required Uint8List bytes, required String extension}) async {
    if (bytes.length > 5 * 1024 * 1024 || !['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) throw ArgumentError('Use a PDF, JPG or PNG file up to 5 MB.');
    final contentType = extension == 'pdf' ? 'application/pdf' : extension == 'png' ? 'image/png' : 'image/jpeg';
    final ref = _storage.ref('certificates/$providerId/$certificateId/${DateTime.now().microsecondsSinceEpoch}.$extension');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return 'gs://${ref.bucket}/${ref.fullPath}';
  }

  Future<String> uploadMessageImage({required String bookingId, required String senderId, required Uint8List bytes}) async {
    if (bytes.length > 5 * 1024 * 1024) throw ArgumentError('Choose an image up to 5 MB.');
    final ref = _storage.ref('messages/$bookingId/$senderId/${DateTime.now().microsecondsSinceEpoch}.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return 'gs://${ref.bucket}/${ref.fullPath}';
  }

  Future<String> readableUrl(String value) => value.startsWith('gs://')
      ? _storage.refFromURL(value).getDownloadURL() : Future.value(value);

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
