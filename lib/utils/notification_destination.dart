import '../models/notification.dart';
import '../models/user_role.dart';

enum NotificationDestinationKind { booking, conversation, service, certificate, verification, report, review, user, section, details }

class NotificationDestination {
  const NotificationDestination(this.kind, {this.id, this.ownerId, this.tab});
  final NotificationDestinationKind kind;
  final String? id, ownerId;
  final int? tab;
}

/// Supported entity IDs only; notification text never becomes a URL or route.
NotificationDestination notificationDestination(AppNotification note, UserRole role) {
  final admin = role == UserRole.administrator;
  final provider = role == UserRole.provider;
  final type = note.notificationType.toLowerCase();
  String? id(String? value) => value != null && value.trim().isNotEmpty ? value.trim() : null;
  final booking = id(note.relatedBookingId), inquiry = id(note.relatedInquiryId);
  final service = id(note.relatedServiceId), certificate = id(note.relatedCertificationId);
  final report = id(note.relatedReportId), review = id(note.relatedReviewId);
  final owner = id(note.relatedProviderId) ?? id(note.relatedUserId);
  if (inquiry != null) return NotificationDestination(NotificationDestinationKind.conversation, id: inquiry, tab: admin ? 3 : 3);
  if (report != null) return NotificationDestination(NotificationDestinationKind.report, id: report, tab: admin ? 3 : 2);
  if (certificate != null) return NotificationDestination(NotificationDestinationKind.certificate, id: certificate, ownerId: owner, tab: admin ? 5 : 4);
  if (service != null) return NotificationDestination(NotificationDestinationKind.service, id: service, tab: admin ? 6 : provider ? 1 : 1);
  if (type.contains('verif') || admin && note.adminTab == 4) return NotificationDestination(NotificationDestinationKind.verification, id: owner, tab: admin ? 4 : 4);
  if (review != null) return NotificationDestination(NotificationDestinationKind.review, id: review, tab: admin ? 7 : 2);
  if (booking != null) return NotificationDestination(type.contains('message') || type.contains('chat') || type == 'inquiry'
    ? NotificationDestinationKind.conversation : NotificationDestinationKind.booking, id: booking, ownerId: 'booking', tab: admin ? 7 : 2);
  if (admin && id(note.relatedUserId) != null) return NotificationDestination(NotificationDestinationKind.user, id: note.relatedUserId, tab: note.adminTab == 2 ? 2 : 1);
  if (admin && note.adminTab != null && note.adminTab! >= 0 && note.adminTab! <= 13 && note.adminTab != 10) return NotificationDestination(NotificationDestinationKind.section, tab: note.adminTab);
  if (type.contains('certificate')) return NotificationDestination(NotificationDestinationKind.section, tab: admin ? 5 : 4);
  if (type.contains('service') || id(note.relatedProposalId) != null) return NotificationDestination(NotificationDestinationKind.section, tab: admin ? 6 : 1);
  if (type.contains('booking') || type.contains('review') || type.contains('payment') || type.contains('report')) return NotificationDestination(NotificationDestinationKind.section, tab: admin ? type.contains('report') ? 3 : 7 : 2);
  if (type.contains('message') || type.contains('inquiry') || type.contains('chat')) return NotificationDestination(NotificationDestinationKind.section, tab: admin ? 3 : 3);
  if (type.contains('account') || type.contains('security')) return NotificationDestination(NotificationDestinationKind.section, tab: admin ? 12 : 4);
  return const NotificationDestination(NotificationDestinationKind.details);
}
