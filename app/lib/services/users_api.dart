import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_api.dart';

class UserSearchResult {
  const UserSearchResult({required this.id, required this.username});

  final String id;
  final String username;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(id: json['id'] as String, username: json['username'] as String);
}

/// Talks to the backend's `/users/search` endpoint — finding an account by
/// name regardless of whether they're currently online, unlike Discover
/// (which only ever shows who's Reachable right now).
class UsersApi {
  UsersApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<List<UserSearchResult>> search(String accessToken, String query) async {
    if (query.trim().isEmpty) return [];

    late final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$_baseUrl/users/search').replace(queryParameters: {'q': query}),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List<dynamic>)
          .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw AuthApiException('Something went wrong (${response.statusCode})');
  }
}
