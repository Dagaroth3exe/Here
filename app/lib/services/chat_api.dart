import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_api.dart';
import 'realtime_service.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.userId,
    required this.name,
    required this.lastBody,
    required this.lastAt,
  });

  final String userId;
  final String name;
  final String lastBody;
  final DateTime lastAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        userId: json['userId'] as String,
        name: json['name'] as String,
        lastBody: json['lastBody'] as String,
        lastAt: DateTime.parse(json['lastAt'] as String),
      );
}

class HistoryMessage {
  const HistoryMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;

  factory HistoryMessage.fromJson(Map<String, dynamic> json) => HistoryMessage(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        recipientId: json['recipientId'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Talks to the backend's `/chat/*` REST endpoints — persisted conversation
/// history, as opposed to [RealtimeService]'s live delivery of new messages.
class ChatApi {
  ChatApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<List<ConversationSummary>> getConversations(String accessToken) async {
    final json = await _get('/chat/conversations', accessToken);
    return json.map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<HistoryMessage>> getMessages(String accessToken, String otherUserId) async {
    final json = await _get('/chat/messages/$otherUserId', accessToken);
    return json.map((e) => HistoryMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Sends over plain HTTP rather than the realtime socket, so it works (and
  /// fails loudly) whether or not you're Reachable. The server still pushes
  /// the message live to both parties' sockets.
  static Future<ChatMessage> sendMessage(String accessToken, String targetId, String body) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/chat/messages'),
            headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
            body: jsonEncode({'targetId': targetId, 'body': body}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ChatMessage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw AuthApiException('Something went wrong (${response.statusCode})');
  }

  static Future<List<dynamic>> _get(String path, String accessToken) async {
    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_baseUrl$path'), headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw AuthApiException('Something went wrong (${response.statusCode})');
  }
}
