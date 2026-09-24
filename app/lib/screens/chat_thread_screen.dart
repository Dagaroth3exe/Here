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

class _ThreadMessage {
  const _ThreadMessage({
    required this.fromId,
    required this.body,
    required this.createdAt,
  });

  final String fromId;
  final String body;
  final DateTime createdAt;
}

class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
  });

  final String otherUserId;
  final String otherName;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ThreadMessage> _messages = [];
  bool _loading = true;
  StreamSubscription<ChatMessage>? _chatSub;

  @override
  void initState() {
    super.initState();
    ChatNotifications.instance.openThreadUserId = widget.otherUserId;
    _chatSub = RealtimeService.instance.chatStream.listen((message) {
      final isThisThread =
          message.fromId == widget.otherUserId ||
          message.targetId == widget.otherUserId;
      if (!isThisThread) return;
      setState(() {
        _messages.add(
          _ThreadMessage(
            fromId: message.fromId,
            body: message.body,
            createdAt: message.createdAt,
          ),
        );
      });
      _scrollToBottom();
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final history = await ChatApi.getMessages(token, widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(
          history.map(
            (m) => _ThreadMessage(
              fromId: m.senderId,
              body: m.body,
              createdAt: m.createdAt,
            ),
          ),
        );
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    RealtimeService.instance.sendChat(widget.otherUserId, text);
    _controller.clear();
  }

  @override
  void dispose() {
    if (ChatNotifications.instance.openThreadUserId == widget.otherUserId) {
      ChatNotifications.instance.openThreadUserId = null;
    }
    _chatSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final myId = AuthSession.userId;

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.sandDeep,
                shape: BoxShape.circle,
              ),
              child: Text(
                initialsFor(widget.otherName),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: colors.inkMutedAvatar,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherName,
              style: AppText.personName.copyWith(color: colors.ink),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.green,
                      ),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Text(
                        t('Say hi to start the conversation.'),
                        style: AppText.reputationLine.copyWith(
                          color: colors.ink50,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMine = message.fromId == myId;
                        return _MessageBubble(message: message, isMine: isMine);
                      },
                    ),
            ),
            _Composer(controller: _controller, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final _ThreadMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = DateFormat.Hm(AppLocale.current.value.languageCode)
        .format(message.createdAt);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? colors.green : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: colors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: AppText.reputationLine.copyWith(
                color: isMine ? Colors.white : colors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: AppText.meta.copyWith(
                fontSize: 10,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.75)
                    : colors.ink38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.hairline),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14.5,
                  color: colors.ink,
                ),
                decoration: InputDecoration(
                  hintText: t('Type a message...'),
                  hintStyle: AppText.meta.copyWith(color: colors.ink38),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
