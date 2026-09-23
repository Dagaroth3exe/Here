import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';

class ReachablePerson {
  const ReachablePerson({required this.id, required this.name});

  final String id;
  final String name;

  factory ReachablePerson.fromJson(Map<String, dynamic> json) =>
      ReachablePerson(id: json['id'] as String, name: json['name'] as String);
}

class IncomingPing {
  const IncomingPing({required this.fromId, required this.fromName});

  final String fromId;
  final String fromName;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.targetId,
    required this.targetName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String fromId;
  final String fromName;
  final String targetId;
  final String targetName;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        fromId: json['fromId'] as String,
        fromName: json['fromName'] as String,
        targetId: json['targetId'] as String,
        targetName: json['targetName'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Connects to the backend's realtime gateway over a plain WebSocket. Being
/// connected at all *is* being "Reachable" — the server's presence list is
/// just who currently has a socket open.
///
/// One shared instance for the whole app (Home toggles the connection,
/// Discover reads the people list, both read incoming pings) — mirrors the
/// [AuthSession] singleton pattern already used for the session.
class RealtimeService {
  RealtimeService._();

  static final instance = RealtimeService._();

  static String get _baseUrl => Platform.isAndroid ? '10.0.2.2:3000' : 'localhost:3000';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _peopleController = StreamController<List<ReachablePerson>>.broadcast();
  final _pingController = StreamController<IncomingPing>.broadcast();
  final _chatController = StreamController<ChatMessage>.broadcast();

  Stream<List<ReachablePerson>> get peopleStream => _peopleController.stream;
  Stream<IncomingPing> get pingStream => _pingController.stream;
  Stream<ChatMessage> get chatStream => _chatController.stream;

  bool get isConnected => _channel != null;

  void connect(String accessToken) {
    if (_channel != null) return;

    final channel = WebSocketChannel.connect(Uri.parse('ws://$_baseUrl?token=$accessToken'));
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleMessage,
      onDone: _reset,
      onError: (_) => _reset(),
      cancelOnError: true,
    );
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _reset();
  }

  void sendPing(String targetId) {
    _channel?.sink.add(jsonEncode({
      'event': 'ping',
      'data': {'targetId': targetId},
    }));
  }

  void sendChat(String targetId, String body) {
    _channel?.sink.add(jsonEncode({
      'event': 'chat:send',
      'data': {'targetId': targetId, 'body': body},
    }));
  }

  void _handleMessage(dynamic raw) {
    final message = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (message['event']) {
      case 'people':
        final people = (message['data'] as List)
            .cast<Map<String, dynamic>>()
            .map(ReachablePerson.fromJson)
            .toList();
        _peopleController.add(people);
      case 'ping':
        final data = message['data'] as Map<String, dynamic>;
        _pingController.add(IncomingPing(fromId: data['fromId'] as String, fromName: data['fromName'] as String));
      case 'chat:message':
        _chatController.add(ChatMessage.fromJson(message['data'] as Map<String, dynamic>));
    }
  }

  void _reset() {
    _channel = null;
    _subscription = null;
    _peopleController.add(const []);
  }

  void dispose() {
    disconnect();
    _peopleController.close();
    _pingController.close();
    _chatController.close();
  }
}
