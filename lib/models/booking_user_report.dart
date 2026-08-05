import 'package:cloud_firestore/cloud_firestore.dart';

/// Moderation report submitted by a customer or provider for a booking's other party.
///
/// Example: customer submits report about the provider for `bookingId`.
class BookingUserReport {
  BookingUserReport({
    required this.reportId,
    required this.bookingId,
    required this.reporterId,
    required this.reporterRole,
    required this.reportedUserId,
    required this.reportedRole,
    required this.reason,
    this.details = '',
    this.status = 'open',
    required this.createdAt,
    this.adminNotes = '',
    this.resolvedAt,
  });

  final String reportId;
  final String bookingId;
  final String reporterId;
  final String reporterRole; // 'customer' | 'provider'
  final String reportedUserId;
  final String reportedRole; // 'customer' | 'provider'
  final String reason;
  final String details;
  final String status; // 'open' | 'resolved' | 'dismissed'
  final Timestamp createdAt;
  final String adminNotes;
  final Timestamp? resolvedAt;

  static const statusOpen = 'open';
  static const statusResolved = 'resolved';
  static const statusDismissed = 'dismissed';

  factory BookingUserReport.fromFirestore(String id, Map<String, dynamic> data) {
    return BookingUserReport(
      reportId: id,
      bookingId: data['bookingId'] as String? ?? '',
      reporterId: data['reporterId'] as String? ?? '',
      reporterRole: data['reporterRole'] as String? ?? 'customer',
      reportedUserId: data['reportedUserId'] as String? ?? '',
      reportedRole: data['reportedRole'] as String? ?? 'provider',
      reason: (data['reason'] as String?)?.trim() ?? '',
      details: (data['details'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim().toLowerCase() ?? statusOpen,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      adminNotes: (data['adminNotes'] as String?)?.trim() ?? '',
      resolvedAt: data['resolvedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'reporterId': reporterId,
      'reporterRole': reporterRole,
      'reportedUserId': reportedUserId,
      'reportedRole': reportedRole,
      'reason': reason,
      'details': details,
      'status': status,
      'createdAt': createdAt,
      'adminNotes': adminNotes,
      'resolvedAt': resolvedAt,
    };
  }
}

