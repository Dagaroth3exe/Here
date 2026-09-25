import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/chat_api.dart';
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
  StreamSubscription<ChatMessage>? _chatSub;

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
      setState(() {
        _conversations = [
          ConversationSummary(
            userId: otherId,
            name: otherName,
            lastBody: message.body,
            lastAt: message.createdAt,
          ),
          ..._conversations.where((c) => c.userId != otherId),
        ];
      });
    });
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
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
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
                  : _conversations.isEmpty
                  ? _EmptyState(colors: colors)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        return _ConversationRow(
                          conversation: conversation,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatThreadScreen(
                                otherUserId: conversation.userId,
                                otherName: conversation.name,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                    conversation.lastBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.reputationLine.copyWith(color: colors.ink50),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(time, style: AppText.meta.copyWith(color: colors.ink38)),
          ],
        ),
      ),
    );
  }
}
