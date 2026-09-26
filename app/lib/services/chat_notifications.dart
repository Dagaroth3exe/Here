import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_session.dart';
import 'chat_api.dart';
import 'realtime_service.dart';

/// Drives the badge on the Chats tab: unread messages plus chat requests
/// waiting for a reply. The count lives on the server (so it survives
/// restarts and other devices); live events just trigger a re-fetch.
/// [openThreadUserId] is kept in sync by the open conversation, whose own
/// messages are marked read instead of counted.
class ChatNotifications {
  ChatNotifications._();

  static final instance = ChatNotifications._();

  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  String? openThreadUserId;

  final List<StreamSubscription<Object>> _subs = [];
  Timer? _debounce;

  void start() {
    if (_subs.isNotEmpty) return;
    final realtime = RealtimeService.instance;
    _subs
      ..add(realtime.chatStream.listen((message) {
        if (message.fromId == AuthSession.userId || message.fromId == openThreadUserId) return;
        refresh();
      }))
      ..add(realtime.requestStream.listen((_) => refresh()));
    refresh();
  }

  /// Re-reads the count from the server (coalescing bursts of events).
  void refresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final token = AuthSession.accessToken;
      if (token == null) return;
      try {
        unreadCount.value = (await ChatApi.getUnread(token)).total;
      } catch (_) {
        // Keep the last known count; the next event or refresh retries.
      }
    });
  }
}
