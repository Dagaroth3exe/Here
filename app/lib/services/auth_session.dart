import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the current session, persisted to platform-backed secure storage
/// (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on Android)
/// so it survives an app restart.
class AuthSession {
  AuthSession._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'here_access_token';
  static const _nameKey = 'here_display_name';

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

  /// Loads any previously persisted session. Call once at app startup,
  /// before deciding whether to route to the auth screen or straight in.
  static Future<void> restore() async {
    _accessToken = await _storage.read(key: _tokenKey);
    _name = await _storage.read(key: _nameKey);
  }

  static Future<void> set(String name, String accessToken) async {
    _name = name;
    _accessToken = accessToken;
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _nameKey, value: name);
  }

  static Future<void> clear() async {
    _name = null;
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _nameKey);
  }
}
