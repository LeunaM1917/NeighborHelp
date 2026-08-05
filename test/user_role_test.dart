import 'package:flutter_test/flutter_test.dart';
import 'package:neighbor_help/models/user_role.dart';

void main() {
  group('UserRole.fromFirestore', () {
    test('accepts canonical Firestore values', () {
      expect(UserRole.fromFirestore('Provider'), UserRole.provider);
      expect(UserRole.fromFirestore('Customer'), UserRole.customer);
      expect(UserRole.fromFirestore('Administrator'), UserRole.administrator);
    });

    test('accepts common variants', () {
      expect(UserRole.fromFirestore('provider'), UserRole.provider);
      expect(UserRole.fromFirestore('Service Provider'), UserRole.provider);
      expect(UserRole.fromFirestore('client'), UserRole.customer);
    });
  });

  group('UserRole.resolve', () {
    test('uses provider profile when stored role is customer', () {
      expect(
        UserRole.resolve(storedRole: UserRole.customer, hasProviderProfile: true),
        UserRole.provider,
      );
    });

    test('keeps administrator', () {
      expect(
        UserRole.resolve(storedRole: UserRole.administrator, hasProviderProfile: true),
        UserRole.administrator,
      );
    });
  });
}
