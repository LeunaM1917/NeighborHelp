/// Didit + admin verification fields stored on `users` and `serviceProviders`.
class IdentityVerification {
  const IdentityVerification({
    this.isVerified = false,
    this.verificationStatus = 'Pending',
    this.diditStatus = '',
    this.verificationProvider = '',
    this.verificationRetakeRequired = false,
    this.verificationIssueCodes = const [],
    this.governmentIdTypeCode = '',
    this.governmentIdTypeLabel = '',
  });

  final bool isVerified;
  final String verificationStatus;
  final String diditStatus;
  final String verificationProvider;
  final bool verificationRetakeRequired;
  final List<String> verificationIssueCodes;
  final String governmentIdTypeCode;
  final String governmentIdTypeLabel;

  factory IdentityVerification.fromMap(Map<String, dynamic> data) {
    return IdentityVerification(
      isVerified: data['isVerified'] as bool? ?? false,
      verificationStatus: data['verificationStatus'] as String? ?? 'Pending',
      diditStatus: data['diditStatus'] as String? ?? '',
      verificationProvider: data['verificationProvider'] as String? ?? '',
      verificationRetakeRequired: data['verificationRetakeRequired'] == true,
      verificationIssueCodes: readIssueCodes(data['verificationIssueCodes']),
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

  static List<String> readIssueCodes(Object? value) => value is List
      ? value
            .whereType<String>()
            .where((code) => RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(code))
            .toSet()
            .take(50)
            .toList(growable: false)
      : const [];

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

  bool get canAdminReview => hasStarted;
  bool get canAdminApprove =>
      hasStarted &&
      !verificationRetakeRequired &&
      const ['approved', 'active', 'in review'].contains(_diditNormalized);

  /// Capture has not finished; the customer can choose their document again.
  bool get isIncomplete =>
      !isVerifiedOnPlatform &&
      !isDeclined &&
      const [
        'not started',
        'in progress',
        'awaiting user',
        'resubmitted',
      ].contains(_diditNormalized);

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

  bool get hasStarted =>
      verificationProvider.isNotEmpty || diditStatus.isNotEmpty;
}
