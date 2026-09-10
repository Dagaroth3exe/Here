/// Holds the current session in memory for this app run.
///
/// Nothing in the app yet calls an authenticated endpoint with this token,
/// so there's no persistence (secure storage) wired up yet — add that
/// before this needs to survive an app restart.
class AuthSession {
  AuthSession._();

  static String? _accessToken;
  static String? _email;

  static bool get isLoggedIn => _accessToken != null;
  static String? get accessToken => _accessToken;
  static String? get email => _email;

  static void set(String email, String accessToken) {
    _email = email;
    _accessToken = accessToken;
  }

  static void clear() {
    _email = null;
    _accessToken = null;
  }
}
