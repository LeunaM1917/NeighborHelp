/// Didit + admin verification fields stored on `users` and `serviceProviders`.
class IdentityVerification {
  const IdentityVerification({
    this.isVerified = false,
    this.verificationStatus = 'Pending',
    this.diditStatus = '',
    this.verificationProvider = '',
    this.governmentIdTypeCode = '',
    this.governmentIdTypeLabel = '',
  });

  final bool isVerified;
  final String verificationStatus;
  final String diditStatus;
  final String verificationProvider;
  final String governmentIdTypeCode;
  final String governmentIdTypeLabel;

  factory IdentityVerification.fromMap(Map<String, dynamic> data) {
    return IdentityVerification(
      isVerified: data['isVerified'] as bool? ?? false,
      verificationStatus: data['verificationStatus'] as String? ?? 'Pending',
      diditStatus: data['diditStatus'] as String? ?? '',
      verificationProvider: data['verificationProvider'] as String? ?? '',
      governmentIdTypeCode: data['governmentIdTypeCode'] as String? ?? '',
      governmentIdTypeLabel: data['governmentIdTypeLabel'] as String? ?? '',
    );
  }

  static const defaultFields = <String, dynamic>{
    'isVerified': false,
    'verificationStatus': 'Pending',
    'diditStatus': '',
    'diditSessionId': '',
    'verificationProvider': '',
    'governmentIdTypeCode': '',
    'governmentIdTypeLabel': '',
  };

  /// Platform badge — admin approval or legacy Approved status.
  bool get isVerifiedOnPlatform =>
      isVerified || verificationStatus.toLowerCase() == 'approved';

  String get _diditNormalized => diditStatus.trim().toLowerCase();
  String get _verificationNormalized => verificationStatus.trim().toLowerCase();

  /// Didit finished; waiting for NeighborHelp admin.
  bool get isAwaitingAdminApproval =>
      !isVerifiedOnPlatform &&
      (_diditNormalized == 'approved' || _diditNormalized == 'active') &&
      _verificationNormalized != 'rejected';

  bool get canAdminReview => isAwaitingAdminApproval;

  bool get isInReview =>
      !isVerifiedOnPlatform &&
      !isAwaitingAdminApproval &&
      (_diditNormalized == 'in review' ||
          _diditNormalized == 'in progress' ||
          _diditNormalized == 'awaiting user' ||
          _diditNormalized == 'resubmitted' ||
          _diditNormalized == 'not started');

  bool get isDeclined =>
      _verificationNormalized == 'rejected' || _diditNormalized == 'declined';

  bool get hasStarted => verificationProvider.isNotEmpty || diditStatus.isNotEmpty;
}
