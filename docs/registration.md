# Registration profile setup

Firebase Authentication emits a signed-in event before the registration method
finishes creating `users/{uid}` and, for providers, `serviceProviders/{uid}`.
Previously RootGate could start automatic recovery during that gap. Its default
profile then competed with registration; replacing registration fields is
correctly rejected by the existing Firestore rules.

All AuthService instances now share an account setup coordinator. Email/password
registration, login, and Google login/signup complete their profile work before
session consumers or automatic recovery proceed. A failed signup signs out before
releasing its queued session event. Recovery failures use the existing retry UI.

If Authentication reports that an email already exists, registration verifies the
submitted password before resuming a missing application profile or an unfinished
provider profile. Complete accounts still use login. Existing roles, approvals,
verification decisions, and private profile data are preserved. No security rules
or registration presentation were changed.

Checks:

- `flutter test test/auth_registration_test.dart` tests the auth/profile race,
  partial signup recovery, password checks, failure cleanup, and existing roles.
- `flutter test --platform chrome test/auth_registration_test.dart` additionally
  exercises the Google web path with a simulated successful OAuth response.
- `npm.cmd run test:registration --prefix functions` uses real disposable Auth
  emulator accounts to save both full registration payloads through the production
  Firestore rules, sign out/in, and verify privileged writes remain denied.
  Java must be available on PATH for the Firestore emulator.

These tests do not create production accounts or perform real Google OAuth.
