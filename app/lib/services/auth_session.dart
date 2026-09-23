import 'dart:convert';

/// Holds the current session in memory for this app run.
///
/// Nothing in the app yet calls an authenticated endpoint with this token,
/// so there's no persistence (secure storage) wired up yet — add that
/// before this needs to survive an app restart.
class AuthSession {
  AuthSession._();

  static String? _accessToken;
  static String? _name;

  static bool get isLoggedIn => _accessToken != null;
  static String? get accessToken => _accessToken;
  static String? get name => _name;

  /// The `sub` (user id) claim from the JWT — derived on the fly rather than
  /// stored separately, so it can never drift out of sync with the token.
  static String? get userId {
    final token = _accessToken;
    if (token == null) return null;
    final payloadSegment = token.split('.')[1];
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payloadSegment)))) as Map<String, dynamic>;
    return payload['sub'] as String?;
  }

  static void set(String name, String accessToken) {
    _name = name;
    _accessToken = accessToken;
  }

  static void clear() {
    _name = null;
    _accessToken = null;
  }
}
