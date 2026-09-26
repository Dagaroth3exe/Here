import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_api.dart';

/// What can be reported, matching the backend's `/safety/reports` targets.
enum ReportTarget { user, message, askQuestion, askAnswer }

/// Why — shown to the reporter as a short list.
enum ReportReason { spam, harassment, inappropriate, scam, unsafe, other }

class BlockedPerson {
  const BlockedPerson({required this.userId, required this.name});

  final String userId;
  final String name;

  factory BlockedPerson.fromJson(Map<String, dynamic> json) =>
      BlockedPerson(userId: json['userId'] as String, name: json['name'] as String);
}

/// Blocking and reporting (`/safety/*`).
class SafetyApi {
  SafetyApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<void> block(String accessToken, String userId) =>
      _request('POST', '/safety/blocks', accessToken, {'userId': userId});

  static Future<void> unblock(String accessToken, String userId) =>
      _request('DELETE', '/safety/blocks/$userId', accessToken);

  static Future<List<BlockedPerson>> blocked(String accessToken) async {
    final json = await _request('GET', '/safety/blocks', accessToken) as List;
    return json.cast<Map<String, dynamic>>().map(BlockedPerson.fromJson).toList();
  }

  static Future<void> report(
    String accessToken, {
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String details = '',
  }) =>
      _request('POST', '/safety/reports', accessToken, {
        'targetType': switch (target) {
          ReportTarget.user => 'user',
          ReportTarget.message => 'message',
          ReportTarget.askQuestion => 'ask_question',
          ReportTarget.askAnswer => 'ask_answer',
        },
        'targetId': targetId,
        'reason': reason.name,
        if (details.trim().isNotEmpty) 'details': details.trim(),
      });

  static Future<Object?> _request(String method, String path, String accessToken, [Object? body]) async {
    late final http.Response response;
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'});
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 10)));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException('Something went wrong (${response.statusCode})');
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }
}
