import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

class ReachablePerson {
  const ReachablePerson({required this.id, required this.name, this.lat, this.lng});

  final String id;
  final String name;

  /// Approximate position (the server rounds it to ~110 m), or null if this
  /// person hasn't shared a location yet.
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  factory ReachablePerson.fromJson(Map<String, dynamic> json) => ReachablePerson(
        id: json['id'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );
}

/// The other person read the conversation up to [at] — shows "Seen".
class ReadReceipt {
  const ReadReceipt({required this.byId, required this.at});

  final String byId;
  final DateTime at;
}

/// Someone answered a chat request you sent.
class RequestUpdate {
  const RequestUpdate({required this.userId, required this.accepted});

  final String userId;
  final bool accepted;
}

/// Someone answered a question you asked on Ask HERE.
class AskAnswerNotice {
  const AskAnswerNotice({required this.questionId, required this.question});

  final String questionId;
  final String question;
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
    required this.pending,
    required this.requesterId,
  });

  final String id;
  final String fromId;
  final String fromName;
  final String targetId;
  final String targetName;
  final String body;
  final DateTime createdAt;

  /// True while it's a chat request the recipient hasn't accepted yet.
  final bool pending;
  final String requesterId;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        fromId: json['fromId'] as String,
        fromName: json['fromName'] as String,
        targetId: json['targetId'] as String,
        targetName: json['targetName'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        pending: json['status'] == 'pending',
        requesterId: json['requesterId'] as String? ?? json['fromId'] as String,
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

  /// Set while the user *wants* to be connected (between [connect] and
  /// [disconnect]) — a drop in that window is retried; after [disconnect]
  /// it isn't.
  String? _token;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// The server's close code for a missing/invalid token — retrying with the
  /// same token can't succeed, so it isn't retried.
  static const _authFailedCloseCode = 4001;

  final _peopleController = StreamController<List<ReachablePerson>>.broadcast();
  final _readController = StreamController<ReadReceipt>.broadcast();
  final _requestController = StreamController<RequestUpdate>.broadcast();
  final _askAnswerController = StreamController<AskAnswerNotice>.broadcast();
  final _chatController = StreamController<ChatMessage>.broadcast();

  List<ReachablePerson> _people = const [];
  ({double lat, double lng})? _location;

  Stream<List<ReachablePerson>> get peopleStream => _peopleController.stream;

  /// The latest people list, for widgets that mount after it was broadcast
  /// (the stream itself doesn't replay).
  List<ReachablePerson> get people => _people;
  Stream<ReadReceipt> get readStream => _readController.stream;
  Stream<RequestUpdate> get requestStream => _requestController.stream;
  Stream<AskAnswerNotice> get askAnswerStream => _askAnswerController.stream;
  Stream<ChatMessage> get chatStream => _chatController.stream;

  bool get isConnected => _channel != null;

  void connect(String accessToken) {
    _token = accessToken;
    _retryTimer?.cancel();
    if (_channel == null) _open(accessToken);
  }

  void disconnect() {
    _token = null;
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _subscription?.cancel();
    _channel?.sink.close();
    _reset();
  }

  void _open(String accessToken) {
    final channel = WebSocketChannel.connect(Uri.parse('ws://$_baseUrl?token=$accessToken'));
    _channel = channel;
    _subscription = channel.stream.listen(
      (raw) {
        _retryAttempt = 0; // the server answered, so this connection is good
        _handleMessage(raw);
      },
      onDone: () => _onDropped(channel),
      onError: (_) => _onDropped(channel),
      cancelOnError: true,
    );
    final location = _location;
    if (location != null) _sendLocation(location.lat, location.lng);
  }

  /// The socket closed without [disconnect] (server restart, network blip,
  /// app backgrounded) — reconnect with backoff: 1s, 2s, 4s… capped at 30s.
  void _onDropped(WebSocketChannel channel) {
    if (channel != _channel) return;
    _reset();
    final token = _token;
    if (token == null || channel.closeCode == _authFailedCloseCode) return;

    final delay = Duration(seconds: min(30, 1 << min(_retryAttempt, 5)));
    _retryAttempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (_token == token && _channel == null) _open(token);
    });
  }

  /// Shares this device's position with everyone Reachable. Remembered so a
  /// reconnect re-sends it without the caller having to.
  void sendLocation(double lat, double lng) {
    _location = (lat: lat, lng: lng);
    _sendLocation(lat, lng);
  }

  void _sendLocation(double lat, double lng) {
    _channel?.sink.add(jsonEncode({
      'event': 'location',
      'data': {'lat': lat, 'lng': lng},
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
        _people = people;
        _peopleController.add(people);
      case 'chat:message':
        _chatController.add(ChatMessage.fromJson(message['data'] as Map<String, dynamic>));
      case 'chat:read':
        final data = message['data'] as Map<String, dynamic>;
        _readController.add(ReadReceipt(byId: data['byId'] as String, at: DateTime.parse(data['at'] as String)));
      case 'chat:request_update':
        final data = message['data'] as Map<String, dynamic>;
        _requestController.add(RequestUpdate(userId: data['userId'] as String, accepted: data['status'] == 'accepted'));
      case 'ask:answer':
        final data = message['data'] as Map<String, dynamic>;
        _askAnswerController.add(
          AskAnswerNotice(questionId: data['questionId'] as String, question: data['question'] as String),
        );
    }
  }

  void _reset() {
    _channel = null;
    _subscription = null;
    _people = const [];
    _peopleController.add(const []);
  }

  void dispose() {
    disconnect();
    _peopleController.close();
    _readController.close();
    _requestController.close();
    _askAnswerController.close();
    _chatController.close();
  }
}
