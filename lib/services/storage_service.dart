import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'marketplace_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/image_upload.dart';

class StorageService {
  StorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  Future<String> uploadInquiryImage({
    required String inquiryId,
    required String senderId,
    required Uint8List bytes,
  }) async {
    if (bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Choose an image up to 5 MB.');
    }
    final format = ImageUploadFormat.inspect(bytes);
    final permit = await MarketplaceService.command('inquiryCommand', {
      'action': 'authorizeUpload',
      'inquiryId': inquiryId,
      'permitId': FirebaseFirestore.instance
          .collection('inquiryUploads')
          .doc()
          .id,
      'extension': format.extension,
    });
    final ref = _storage.ref(
      'inquiries/$inquiryId/$senderId/${permit['fileName']}',
    );
    await ref.putData(bytes, SettableMetadata(contentType: format.contentType));
    return 'gs://${ref.bucket}/${ref.fullPath}';
  }

  Future<String> uploadCertificate({
    required String providerId,
    required String certificateId,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (bytes.length > 5 * 1024 * 1024 ||
        !['pdf', 'jpg', 'jpeg', 'png'].contains(extension)) {
      throw ArgumentError('Use a PDF, JPG or PNG file up to 5 MB.');
    }
    final contentType = extension == 'pdf'
        ? 'application/pdf'
        : extension == 'png'
        ? 'image/png'
        : 'image/jpeg';
    final ref = _storage.ref(
      'certificates/$providerId/$certificateId/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return 'gs://${ref.bucket}/${ref.fullPath}';
  }

  Future<String> uploadMessageImage({
    required String bookingId,
    required String senderId,
    required Uint8List bytes,
  }) async {
    final id = await MarketplaceService.bookingInquiry(bookingId);
    return uploadInquiryImage(inquiryId: id, senderId: senderId, bytes: bytes);
  }

  Future<String> readableUrl(String value) => value.startsWith('gs://')
      ? _storage.refFromURL(value).getDownloadURL()
      : Future.value(value);

  /// Each upload gets a new URL so an older cached photo is never reused.
  Future<String> uploadProfilePhoto({
    required String userId,
    required dynamic file,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Use uploadProfilePhotoBytes on web.');
    }
    return uploadProfilePhotoBytes(
      userId: userId,
      bytes: await (file as File).readAsBytes(),
    );
  }

  Future<String> uploadProfilePhotoBytes({
    required String userId,
    required Uint8List bytes,
  }) async {
    final format = ImageUploadFormat.inspect(bytes);
    final ref = _storage.ref(
      'users/$userId/profile-${DateTime.now().microsecondsSinceEpoch}.${format.extension}',
    );
    await ref.putData(bytes, SettableMetadata(contentType: format.contentType));
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
