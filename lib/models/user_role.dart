enum UserRole {
  customer('Customer'),
  provider('Provider'),
  administrator('Administrator'),
  verificationAgency('Verification Agency');

  const UserRole(this.firestoreValue);

  final String firestoreValue;

  static UserRole fromFirestore(String? value) {
    if (value == null) return UserRole.customer;
    final raw = value.trim();
    if (raw.isEmpty) return UserRole.customer;

    for (final role in UserRole.values) {
      if (role.firestoreValue == raw) return role;
    }

    final normalized = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return switch (normalized) {
      'provider' || 'serviceprovider' => UserRole.provider,
      'administrator' || 'admin' => UserRole.administrator,
      'verificationagency' || 'agency' || 'verifier' => UserRole.verificationAgency,
      'customer' || 'client' => UserRole.customer,
      _ => UserRole.customer,
    };
  }

  /// Prefer explicit [storedRole] on `users`. A stray `serviceProviders` doc alone
  /// must not turn a customer into a provider (e.g. mistaken Didit verification).
  static UserRole resolve({
    required UserRole storedRole,
    required bool hasProviderProfile,
  }) {
    if (storedRole == UserRole.administrator) return UserRole.administrator;
    if (storedRole == UserRole.verificationAgency) return UserRole.verificationAgency;
    if (storedRole == UserRole.provider) return UserRole.provider;
    if (storedRole == UserRole.customer) return UserRole.customer;
    if (hasProviderProfile) return UserRole.provider;
    return storedRole;
  }
}
