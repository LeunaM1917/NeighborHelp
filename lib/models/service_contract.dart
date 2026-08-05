import 'package:cloud_firestore/cloud_firestore.dart';

/// Ongoing work relationship between one customer and one provider (Upwork-style contract).
class ServiceContract {
  ServiceContract({
    required this.contractId,
    required this.customerId,
    required this.providerId,
    required this.status,
    required this.milestoneCount,
    required this.createdAt,
    required this.updatedAt,
    this.endedAt,
    this.endedByUserId,
    this.endedByRole,
  });

  final String contractId;
  final String customerId;
  final String providerId;
  /// `active` or `ended`
  final String status;
  /// Highest milestone number assigned so far on this contract.
  final int milestoneCount;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? endedAt;
  final String? endedByUserId;
  /// `customer` or `provider`
  final String? endedByRole;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isEnded => status.toLowerCase() == 'ended';

  factory ServiceContract.fromFirestore(String id, Map<String, dynamic> data) {
    return ServiceContract(
      contractId: id,
      customerId: data['customerId'] as String? ?? '',
      providerId: data['providerId'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      milestoneCount: (data['milestoneCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      endedAt: data['endedAt'] as Timestamp?,
      endedByUserId: data['endedByUserId'] as String?,
      endedByRole: data['endedByRole'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'providerId': providerId,
      'status': status,
      'milestoneCount': milestoneCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (endedAt != null) 'endedAt': endedAt,
      if (endedByUserId != null) 'endedByUserId': endedByUserId,
      if (endedByRole != null) 'endedByRole': endedByRole,
    };
  }
}
