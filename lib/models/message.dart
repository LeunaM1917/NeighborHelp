import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  ChatMessage({
    required this.messageId,
    required this.bookingId,
    this.threadId,
    required this.senderId,
    required this.receiverId,
    this.messageText,
    this.mediaUrl,
    required this.messageType,
    required this.isRead,
    required this.sentAt,
  });

  final String messageId;
  final String bookingId;
  /// Groups messages across repeat bookings between the same customer and provider.
  final String? threadId;
  final String senderId;
  final String receiverId;
  final String? messageText;
  final String? mediaUrl;
  final String messageType;
  final bool isRead;
  final Timestamp sentAt;

  factory ChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    return ChatMessage(
      messageId: id,
      bookingId: data['bookingId'] as String? ?? '',
      threadId: data['threadId'] as String?,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      messageText: data['messageText'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      messageType: data['messageType'] as String? ?? 'Text',
      isRead: data['isRead'] as bool? ?? false,
      sentAt: data['sentAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      if (threadId != null) 'threadId': threadId,
      'senderId': senderId,
      'receiverId': receiverId,
      'messageText': messageText,
      'mediaUrl': mediaUrl,
      'messageType': messageType,
      'isRead': isRead,
      'sentAt': sentAt,
    };
  }
}
