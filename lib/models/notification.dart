import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  AppNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.relatedBookingId,
    required this.isRead,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String notificationType;
  final String? relatedBookingId;
  final bool isRead;
  final Timestamp createdAt;

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return AppNotification(
      notificationId: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      notificationType: data['notificationType'] as String? ?? '',
      relatedBookingId: data['relatedBookingId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'notificationType': notificationType,
      'relatedBookingId': relatedBookingId,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }
}
