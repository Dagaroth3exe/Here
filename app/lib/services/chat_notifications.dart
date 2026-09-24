import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_session.dart';
import 'realtime_service.dart';

/// Drives the unread badge on the Chats tab. A message counts as unread if
/// it's incoming (not sent by me) and I'm not already looking at that exact
/// thread — [openThreadUserId] is kept in sync by [ChatThreadScreen] so its
/// own messages never bump the badge while you're staring right at them.
class ChatNotifications {
  ChatNotifications._();

  static final instance = ChatNotifications._();

  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  String? openThreadUserId;

  StreamSubscription<ChatMessage>? _sub;

  void start() {
    _sub ??= RealtimeService.instance.chatStream.listen((message) {
      final myId = AuthSession.userId;
      if (message.fromId == myId) return;
      if (message.fromId == openThreadUserId) return;
      unreadCount.value++;
    });
  }

  void markAllRead() => unreadCount.value = 0;
}
