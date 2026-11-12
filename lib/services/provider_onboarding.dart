/// Signup hands this intent to the first ready provider dashboard in this session.
/// Existing account logins do not mark an onboarding intent.
class ProviderOnboarding {
  static final Set<String> _pending = {};
  static void mark(String uid) => _pending.add(uid);
  static bool consume(String uid) => _pending.remove(uid);
}
