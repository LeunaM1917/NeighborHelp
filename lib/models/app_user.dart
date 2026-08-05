import 'package:cloud_firestore/cloud_firestore.dart';

import 'account_status.dart';
import 'identity_verification.dart';
import 'user_role.dart';

class AppUser {
  AppUser({
    required this.userId,
    required this.fullName,
    required this.email,
    this.contactNumber,
    required this.role,
    this.profilePhotoUrl,
    this.address,
    this.bio,
    this.location,
    required this.accountStatus,
    required this.createdAt,
    required this.updatedAt,
    this.lastActive,
    IdentityVerification? identityVerification,
  }) : identityVerification = identityVerification ?? const IdentityVerification();

  final IdentityVerification identityVerification;

  final String userId;
  final String fullName;
  final String email;
  final String? contactNumber;
  final UserRole role;
  final String? profilePhotoUrl;
  final String? address;
  final String? bio;
  final GeoPoint? location;
  final AccountStatus accountStatus;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? lastActive;

  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) {
    return AppUser(
      userId: id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      contactNumber: data['contactNumber'] as String?,
      role: UserRole.fromFirestore(data['role']?.toString()),
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      address: data['address'] as String?,
      bio: data['bio'] as String?,
      location: data['location'] as GeoPoint?,
      accountStatus: AccountStatus.fromFirestore(data['accountStatus'] as String?),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      lastActive: data['lastActive'] as Timestamp?,
      identityVerification: IdentityVerification.fromMap(data),
    );
  }

  bool get isVerifiedCustomer => identityVerification.isVerifiedOnPlatform;

  bool get isAwaitingVerificationApproval => identityVerification.isAwaitingAdminApproval;

  bool get isVerificationInReview => identityVerification.isInReview;

  bool get isVerificationDeclined => identityVerification.isDeclined;

  bool get canAdminReviewVerification => identityVerification.canAdminReview;

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'contactNumber': contactNumber,
      'role': role.firestoreValue,
      'profilePhotoUrl': profilePhotoUrl,
      'address': address,
      if (bio != null) 'bio': bio,
      'location': location,
      'accountStatus': accountStatus.firestoreValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastActive': lastActive,
    };
  }
}
