enum ServiceApprovalStatus {
  draft('Draft'),
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const ServiceApprovalStatus(this.firestoreValue);

  final String firestoreValue;

  static ServiceApprovalStatus fromFirestore(String? value) {
    final normalized = value?.trim().toLowerCase();
    return ServiceApprovalStatus.values.firstWhere(
      (e) => e.firestoreValue.toLowerCase() == normalized,
      orElse: () => ServiceApprovalStatus.pending,
    );
  }

  bool get isPending => this == ServiceApprovalStatus.pending;

  bool get isApproved => this == ServiceApprovalStatus.approved;
}
