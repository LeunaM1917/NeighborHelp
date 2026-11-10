import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/inquiry.dart';
import '../models/message.dart';
import '../models/service.dart';
import 'firestore_service.dart';
import 'marketplace_service.dart';
import 'storage_service.dart';

/// The restored message layout uses the same protected conversation API.
class MessagingRepository {
  Stream<List<Inquiry>> inbox(String uid) => MarketplaceService.inbox(uid);
  Stream<List<Booking>> bookings(String uid, bool asCustomer) =>
      FirestoreService().bookingsForUser(uid, asCustomer: asCustomer);
  Stream<List<ChatMessage>> messages(String id) =>
      MarketplaceService.messages(id).map(
        (s) => s.docs.map((d) {
          final data = d.data();
          return ChatMessage.fromFirestore(d.id, {
            ...data,
            'threadId': id,
            'messageText': data['text'] ?? '',
            'messageType': (data['mediaUrl'] as String? ?? '').isEmpty
                ? 'Text'
                : 'Image',
          });
        }).toList(),
      );
  Future<void> synchronize() => MarketplaceService.syncBookingConversations();
  Future<String> inquiryForBooking(String id) =>
      MarketplaceService.bookingInquiry(id);
  Future<AppUser?> user(String id) => FirestoreService().getUser(id);
  Future<ServiceListing?> service(String id) =>
      FirestoreService().getService(id);
  String newId() => FirebaseFirestore.instance.collection('inquiries').doc().id;
  Future<void> command(
    String id,
    String action, {
    Map<String, dynamic> data = const {},
  }) async {
    await MarketplaceService.command('inquiryCommand', {
      'action': action,
      'inquiryId': id,
      ...data,
    });
  }

  Future<void> send(
    String id, {
    required String messageId,
    String text = '',
    String mediaUrl = '',
  }) => MarketplaceService.send(
    id,
    messageId: messageId,
    text: text,
    mediaUrl: mediaUrl,
  );
  Future<String> uploadPhoto(String id, String uid, Uint8List bytes) =>
      StorageService().uploadInquiryImage(
        inquiryId: id,
        senderId: uid,
        bytes: bytes,
      );
}
