/// Firebase administrator account for the admin console (development).
///
/// Create this user in Firebase Authentication, then set `users/{uid}.role` to
/// `Administrator` in Firestore. Login with username `admin` / password below
/// will use this email for Firebase sign-in and full Firestore access.
abstract final class AdminConfig {
  static const firebaseEmail = 'admin@neighborhelp.com';
  static const defaultPassword = 'admin123';
}
