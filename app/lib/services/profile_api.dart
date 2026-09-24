import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_api.dart';

class UserProfile {
  const UserProfile({required this.categories, required this.interests});

  final List<String> categories;
  final List<String> interests;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        categories: (json['categories'] as List<dynamic>).cast<String>(),
        interests: (json['interests'] as List<dynamic>).cast<String>(),
      );
}

/// Talks to the backend's `/users/me` endpoints — the real, persisted
/// reachability categories and interest tags, replacing what used to be
/// hardcoded UI copy.
class ProfileApi {
  ProfileApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<UserProfile> getMe(String accessToken) async {
    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_baseUrl/users/me'), headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw AuthApiException('Something went wrong (${response.statusCode})');
  }

  static Future<UserProfile> updateMe(
    String accessToken, {
    List<String>? categories,
    List<String>? interests,
  }) async {
    late final http.Response response;
    try {
      response = await http
          .patch(
            Uri.parse('$_baseUrl/users/me'),
            headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
            body: jsonEncode({
              if (categories != null) 'categories': categories,
              if (interests != null) 'interests': interests,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw AuthApiException('Something went wrong (${response.statusCode})');
  }
}
