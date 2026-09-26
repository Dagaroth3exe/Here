import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/chat_api.dart';
import '../services/chat_notifications.dart';
import '../services/realtime_service.dart';
import '../utils/initials.dart';
import '../widgets/empty_state.dart';
import 'chat_thread_screen.dart';
import 'new_chat_screen.dart';

/// The "Chats" tab: a real, persisted list of 1:1 conversations, updated
/// live over the same WebSocket connection used for presence/pings.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen> {
  List<ConversationSummary> _conversations = [];
  bool _loading = true;
  bool _loadFailed = false;
  StreamSubscription<ChatMessage>? _chatSub;
  StreamSubscription<RequestUpdate>? _requestSub;

  @override
  void initState() {
    super.initState();
    _load();
    _chatSub = RealtimeService.instance.chatStream.listen((message) {
      final myId = AuthSession.userId;
      final isMine = message.fromId == myId;
      final otherId = isMine ? message.targetId : message.fromId;
      // The payload always carries both parties' names now — no need to
      // guess or fall back to an existing conversation entry.
      final otherName = isMine ? message.targetName : message.fromName;
      final existing = _conversations.where((c) => c.userId == otherId).firstOrNull;
      final status = !message.pending
          ? ChatStatus.accepted
          : message.requesterId == myId
              ? ChatStatus.outgoing
              : ChatStatus.incoming;
      // Messages in the open conversation are read as they arrive.
      final counts = !isMine && ChatNotifications.instance.openThreadUserId != otherId;
      setState(() {
        _conversations = [
          (existing ??
                  ConversationSummary(userId: otherId, name: otherName, lastBody: '', lastAt: message.createdAt))
              .copyWith(
            lastBody: message.body,
            lastAt: message.createdAt,
            lastFromMe: isMine,
            status: status,
            unreadCount: (existing?.unreadCount ?? 0) + (counts ? 1 : 0),
          ),
          ..._conversations.where((c) => c.userId != otherId),
        ];
      });
    });
    _requestSub = RealtimeService.instance.requestStream.listen((update) {
      setState(() {
        _conversations = [
          for (final c in _conversations)
            c.userId == update.userId
                ? c.copyWith(status: update.accepted ? ChatStatus.accepted : ChatStatus.declined)
                : c,
        ];
      });
    });
  }

  Future<void> _open(ConversationSummary conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(otherUserId: conversation.userId, otherName: conversation.name),
      ),
    );
    // Reading, accepting, declining, or blocking there all change this list.
    _load();
  }

  /// Re-fetches from the server — called on first mount and again every time
  /// this tab is revisited, since [HereShell] keeps this screen alive in an
  /// `IndexedStack` rather than rebuilding it (so `initState` alone would
  /// only ever see conversation state as of the very first time you opened
  /// the tab).
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final conversations = await ChatApi.getConversations(token);
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      // Keep whatever was already shown; only say so if there's nothing.
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _requestSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      color: colors.paper,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('Chats'),
                    style: AppText.screenTitle.copyWith(color: colors.ink),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NewChatScreen()),
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.hairline),
                      ),
                      child: Icon(
                        Icons.edit_square,
                        size: 18,
                        color: colors.ink70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.green,
                      ),
                    )
                  : _conversations.isEmpty && _loadFailed
                  ? Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        child: Text(t("Couldn't load. Tap to retry.")),
                      ),
                    )
                  : _conversations.isEmpty
                  ? _EmptyState(colors: colors)
                  : _ConversationList(conversations: _conversations, onOpen: _open),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return HereEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: t('No conversations yet'),
      description: t('Ping someone in Discover to start chatting.'),
    );
  }
}

/// Chat requests waiting for you first, then your conversations.
class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.conversations, required this.onOpen});

  final List<ConversationSummary> conversations;
  final ValueChanged<ConversationSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final requests = conversations.where((c) => c.status == ChatStatus.incoming).toList();
    final chats = conversations.where((c) => c.status != ChatStatus.incoming).toList();
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 0, 10),
          child: Text(text, style: AppText.sectionHeader.copyWith(color: colors.ink)),
        );
    Widget row(ConversationSummary c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ConversationRow(conversation: c, onTap: () => onOpen(c)),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
      children: [
        if (requests.isNotEmpty) ...[
          header(t('Requests ({count})', {'count': requests.length})),
          for (final c in requests) row(c),
          if (chats.isNotEmpty) header(t('Messages')),
        ],
        for (final c in chats) row(c),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.onTap});

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = DateFormat.Hm(AppLocale.current.value.languageCode)
        .format(conversation.lastAt.toLocal());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.sandDeep,
                shape: BoxShape.circle,
              ),
              child: Text(
                initialsFor(conversation.name),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colors.inkMutedAvatar,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.personName.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    switch (conversation.status) {
                      ChatStatus.outgoing => t('Request sent · waiting for them to accept'),
                      ChatStatus.declined => t('Request declined'),
                      _ => conversation.lastFromMe
                          ? t('You: {message}', {'message': conversation.lastBody})
                          : conversation.lastBody,
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.reputationLine.copyWith(
                      color: conversation.unreadCount > 0 ? colors.ink : colors.ink50,
                      fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(time, style: AppText.meta.copyWith(color: colors.ink38)),
                if (conversation.unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: colors.green, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                      textAlign: TextAlign.center,
                      style: AppText.meta.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
