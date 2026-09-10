import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Thrown for any non-2xx response, carrying the backend's own error message.
class AuthApiException implements Exception {
  AuthApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TotpSetupResult {
  const TotpSetupResult({required this.secret, required this.otpauthUrl});
  final String secret;
  final String otpauthUrl;
}

/// Talks to the backend's email+TOTP auth endpoints.
///
/// The Android emulator can't reach the host machine via `localhost` — it
/// has to use the special `10.0.2.2` alias instead. A real device would need
/// the host's actual LAN address or a deployed URL here.
class AuthApi {
  AuthApi._();

  static final String _baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<TotpSetupResult> setupTotp(String email) async {
    final json = await _post('/auth/totp/setup', {'email': email});
    return TotpSetupResult(secret: json['secret'] as String, otpauthUrl: json['otpauthUrl'] as String);
  }

  static Future<String> confirmTotp(String email, String code) async {
    final json = await _post('/auth/totp/confirm', {'email': email, 'code': code});
    return json['accessToken'] as String;
  }

  static Future<String> loginWithTotp(String email, String code) async {
    final json = await _post('/auth/totp/login', {'email': email, 'code': code});
    return json['accessToken'] as String;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, String> body) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }

    final json = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final message = json['message'];
    final text = message is List ? message.join(', ') : message?.toString();
    throw AuthApiException(text ?? 'Something went wrong (${response.statusCode})');
  }
}
