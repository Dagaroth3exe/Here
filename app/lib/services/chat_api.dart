import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_api.dart';
import 'realtime_service.dart';

/// Where a conversation stands for the viewer: `incoming` is a chat request
/// waiting for them, `outgoing` one they're waiting on, `declined` their
/// request that was turned down, `none` no contact yet (the first message
/// will be a request).
enum ChatStatus { none, accepted, incoming, outgoing, declined }

ChatStatus _status(String? value) => ChatStatus.values.asNameMap()[value] ?? ChatStatus.accepted;

class ConversationSummary {
  const ConversationSummary({
    required this.userId,
    required this.name,
    required this.lastBody,
    required this.lastAt,
    this.lastFromMe = false,
    this.status = ChatStatus.accepted,
    this.unreadCount = 0,
  });

  final String userId;
  final String name;
  final String lastBody;
  final DateTime lastAt;
  final bool lastFromMe;
  final ChatStatus status;
  final int unreadCount;

  ConversationSummary copyWith({
    String? lastBody,
    DateTime? lastAt,
    bool? lastFromMe,
    ChatStatus? status,
    int? unreadCount,
  }) =>
      ConversationSummary(
        userId: userId,
        name: name,
        lastBody: lastBody ?? this.lastBody,
        lastAt: lastAt ?? this.lastAt,
        lastFromMe: lastFromMe ?? this.lastFromMe,
        status: status ?? this.status,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        userId: json['userId'] as String,
        name: json['name'] as String,
        lastBody: json['lastBody'] as String,
        lastAt: DateTime.parse(json['lastAt'] as String),
        lastFromMe: json['lastFromMe'] as bool? ?? false,
        status: _status(json['status'] as String?),
        unreadCount: json['unreadCount'] as int? ?? 0,
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

/// A page of a conversation (oldest first) plus where it stands.
class ChatHistory {
  const ChatHistory({
    required this.messages,
    required this.hasMore,
    required this.status,
    required this.otherLastReadAt,
    required this.blocked,
  });

  final List<HistoryMessage> messages;

  /// Whether there are older messages before this page.
  final bool hasMore;
  final ChatStatus status;

  /// How far the other person has read — your messages up to here are "Seen".
  final DateTime? otherLastReadAt;

  /// Either of you blocked the other; nothing can be sent.
  final bool blocked;

  factory ChatHistory.fromJson(Map<String, dynamic> json) => ChatHistory(
        messages: (json['messages'] as List).cast<Map<String, dynamic>>().map(HistoryMessage.fromJson).toList(),
        hasMore: json['hasMore'] as bool,
        status: _status(json['status'] as String?),
        otherLastReadAt: json['otherLastReadAt'] == null ? null : DateTime.parse(json['otherLastReadAt'] as String),
        blocked: json['blocked'] as bool? ?? false,
      );
}

class UnreadCounts {
  const UnreadCounts({required this.messages, required this.requests});

  final int messages;
  final int requests;

  int get total => messages + requests;
}

/// A request the server refused, carrying its explanation (e.g. "Wait for
/// Priya to accept your chat request") so it can be shown as-is.
class ChatApiException extends AuthApiException {
  ChatApiException(super.message, this.statusCode);

  final int statusCode;
}

/// Talks to the backend's `/chat/*` REST endpoints — persisted conversations,
/// chat requests and read state, as opposed to [RealtimeService]'s live
/// delivery of new messages.
class ChatApi {
  ChatApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<List<ConversationSummary>> getConversations(String accessToken) async {
    final json = await _request('GET', '/chat/conversations', accessToken) as List;
    return json.map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The latest page, or the page before [before] when scrolling back.
  static Future<ChatHistory> getMessages(String accessToken, String otherUserId, {DateTime? before}) async {
    final query = before == null ? '' : '?before=${Uri.encodeQueryComponent(before.toUtc().toIso8601String())}';
    return ChatHistory.fromJson(
      await _request('GET', '/chat/messages/$otherUserId$query', accessToken) as Map<String, dynamic>,
    );
  }

  static Future<UnreadCounts> getUnread(String accessToken) async {
    final json = await _request('GET', '/chat/unread', accessToken) as Map<String, dynamic>;
    return UnreadCounts(messages: json['messages'] as int, requests: json['requests'] as int);
  }

  static Future<void> markRead(String accessToken, String otherUserId) =>
      _request('POST', '/chat/read/$otherUserId', accessToken);

  static Future<void> acceptRequest(String accessToken, String userId) =>
      _request('POST', '/chat/requests/$userId/accept', accessToken);

  static Future<void> declineRequest(String accessToken, String userId) =>
      _request('POST', '/chat/requests/$userId/decline', accessToken);

  /// Sends over plain HTTP rather than the realtime socket, so it works (and
  /// fails loudly) whether or not you're Reachable. The server still pushes
  /// the message live to both parties' sockets.
  static Future<ChatMessage> sendMessage(String accessToken, String targetId, String body) async {
    final json = await _request('POST', '/chat/messages', accessToken, {'targetId': targetId, 'body': body});
    return ChatMessage.fromJson(json as Map<String, dynamic>);
  }

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
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    throw ChatApiException(_serverMessage(response) ?? 'Something went wrong (${response.statusCode})', response.statusCode);
  }

  /// Nest puts the reason in `message` (a string, or a list for validation errors).
  static String? _serverMessage(http.Response response) {
    try {
      final message = (jsonDecode(response.body) as Map<String, dynamic>)['message'];
      return message is List ? message.join(', ') : message as String?;
    } catch (_) {
      return null;
    }
  }
}
