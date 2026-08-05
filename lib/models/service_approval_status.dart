enum ServiceApprovalStatus {
  draft('Draft'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ServiceApprovalStatus(this.firestoreValue);

  final String firestoreValue;

  static ServiceApprovalStatus fromFirestore(String? value) {
    if (value == null || value.isEmpty) return ServiceApprovalStatus.approved;
    return ServiceApprovalStatus.values.firstWhere(
      (e) => e.firestoreValue.toLowerCase() == value.toLowerCase(),
      orElse: () => ServiceApprovalStatus.approved,
    );
  }

  bool get isPending => this == ServiceApprovalStatus.pending;

  bool get isApproved => this == ServiceApprovalStatus.approved;
}
