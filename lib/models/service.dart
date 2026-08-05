import 'package:cloud_firestore/cloud_firestore.dart';

import 'service_approval_status.dart';

class ServiceListing {
  ServiceListing({
    required this.serviceId,
    required this.providerId,
    required this.serviceTitle,
    required this.category,
    required this.description,
    required this.estimatedPrice,
    required this.priceType,
    required this.estimatedDuration,
    required this.availability,
    required this.serviceImages,
    required this.isActive,
    required this.approvalStatus,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason = '',
  });

  final String serviceId;
  final String providerId;
  final String serviceTitle;
  final String category;
  final String description;
  final double estimatedPrice;
  final String priceType;
  final String estimatedDuration;
  final Map<String, dynamic> availability;
  final List<String> serviceImages;
  final bool isActive;
  final ServiceApprovalStatus approvalStatus;
  final String rejectionReason;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  /// Visible on customer browse, search, and booking.
  bool get isMarketplaceVisible => approvalStatus.isApproved && isActive;

  factory ServiceListing.fromFirestore(String id, Map<String, dynamic> data) {
    return ServiceListing(
      serviceId: id,
      providerId: data['providerId'] as String? ?? '',
      serviceTitle: data['serviceTitle'] as String? ?? '',
      category: data['category'] as String? ?? '',
      description: data['description'] as String? ?? '',
      estimatedPrice: (data['estimatedPrice'] as num?)?.toDouble() ?? 0,
      priceType: data['priceType'] as String? ?? 'negotiable',
      estimatedDuration: data['estimatedDuration'] as String? ?? '',
      availability: Map<String, dynamic>.from(
        data['availability'] as Map? ?? {},
      ),
      serviceImages: List<String>.from(data['serviceImages'] as List? ?? []),
      isActive: data['isActive'] as bool? ?? true,
      approvalStatus: ServiceApprovalStatus.fromFirestore(
        data['approvalStatus'] as String?,
      ),
      rejectionReason: data['rejectionReason'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'serviceTitle': serviceTitle,
      'category': category,
      'description': description,
      'estimatedPrice': estimatedPrice,
      'priceType': priceType,
      'estimatedDuration': estimatedDuration,
      'availability': availability,
      'serviceImages': serviceImages,
      'isActive': isActive,
      'approvalStatus': approvalStatus.firestoreValue,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
