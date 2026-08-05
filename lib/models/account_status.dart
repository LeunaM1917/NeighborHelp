enum AccountStatus {
  active('Active'),
  pending('Pending'),
  suspended('Suspended'),
  deactivated('Deactivated');

  const AccountStatus(this.firestoreValue);

  final String firestoreValue;

  static AccountStatus fromFirestore(String? value) {
    return AccountStatus.values.firstWhere(
      (e) => e.firestoreValue == value,
      orElse: () => AccountStatus.active,
    );
  }

  /// Suspended or deactivated — user cannot use customer/provider apps.
  bool get isBlocked => this == AccountStatus.suspended || this == AccountStatus.deactivated;

  String get blockedTitle => switch (this) {
        AccountStatus.suspended => 'Account suspended',
        AccountStatus.deactivated => 'Account deactivated',
        _ => 'Account restricted',
      };
}
