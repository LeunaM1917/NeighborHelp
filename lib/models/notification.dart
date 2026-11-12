import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  AppNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.relatedBookingId,
    this.relatedInquiryId,
    this.relatedServiceId,
    this.relatedCertificationId,
    this.relatedProviderId,
    this.relatedUserId,
    this.relatedReportId,
    this.relatedReviewId,
    this.relatedProposalId,
    this.sourceCollection,
    this.adminTab,
    required this.isRead,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String notificationType;
  final String? relatedBookingId;
  final String? relatedInquiryId;
  final String? relatedServiceId, relatedCertificationId, relatedProviderId,
      relatedUserId, relatedReportId, relatedReviewId, relatedProposalId, sourceCollection;
  final int? adminTab;
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
      relatedInquiryId: data['relatedInquiryId'] as String?,
      relatedServiceId: data['relatedServiceId'] as String?,
      relatedCertificationId: data['relatedCertificationId'] as String? ?? data['relatedCertificateId'] as String?,
      relatedProviderId: data['relatedProviderId'] as String?,
      relatedUserId: data['relatedUserId'] as String?,
      relatedReportId: data['relatedReportId'] as String?,
      relatedReviewId: data['relatedReviewId'] as String?,
      relatedProposalId: data['relatedProposalId'] as String?,
      sourceCollection: data['sourceCollection'] as String?,
      adminTab: data['adminTab'] is int ? data['adminTab'] as int : null,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'notificationType': notificationType,
      'relatedBookingId': relatedBookingId,
      'relatedInquiryId': relatedInquiryId,
      if (relatedServiceId != null) 'relatedServiceId': relatedServiceId,
      if (relatedCertificationId != null) 'relatedCertificationId': relatedCertificationId,
      if (relatedProviderId != null) 'relatedProviderId': relatedProviderId,
      if (relatedUserId != null) 'relatedUserId': relatedUserId,
      if (relatedReportId != null) 'relatedReportId': relatedReportId,
      if (relatedReviewId != null) 'relatedReviewId': relatedReviewId,
      if (relatedProposalId != null) 'relatedProposalId': relatedProposalId,
      if (sourceCollection != null) 'sourceCollection': sourceCollection,
      if (adminTab != null) 'adminTab': adminTab,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }
}
