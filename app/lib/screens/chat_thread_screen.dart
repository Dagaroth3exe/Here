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
import '../services/safety_api.dart';
import '../utils/initials.dart';
import '../widgets/report_sheet.dart';

enum _Delivery { sending, sent, failed }

class _ThreadMessage {
  const _ThreadMessage({
    required this.id,
    required this.fromId,
    required this.body,
    required this.createdAt,
    this.delivery = _Delivery.sent,
  });

  /// Server id, or a local placeholder ("local-…") while sending.
  final String id;
  final String fromId;
  final String body;
  final DateTime createdAt;
  final _Delivery delivery;

  _ThreadMessage withDelivery(_Delivery delivery) =>
      _ThreadMessage(id: id, fromId: fromId, body: body, createdAt: createdAt, delivery: delivery);
}

/// A 1:1 conversation. Also where chat requests happen: a first message is a
/// request the other person accepts or declines, and until then the sender
/// waits. Pops with `true` if a message was sent (Discover marks "Ping sent").
class ChatThreadScreen extends StatefulWidget {
  const ChatThreadScreen({super.key, required this.otherUserId, required this.otherName});

  final String otherUserId;
  final String otherName;

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  /// Messages that failed to send, per conversation, kept for the app
  /// session so leaving and reopening a chat doesn't lose them.
  static final Map<String, List<_ThreadMessage>> _outbox = {};

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ThreadMessage> _messages = [];
  final List<StreamSubscription<Object>> _subs = [];

  bool _loading = true;
  bool _hasMore = false;
  bool _loadingOlder = false;

  /// Null until the conversation has loaded — no banner is shown for an unknown state.
  ChatStatus? _status;
  bool _loadFailed = false;
  DateTime? _otherLastReadAt;
  bool _blocked = false;
  bool _iBlocked = false;
  bool _sentAny = false;

  String get _myId => AuthSession.userId ?? '';

  @override
  void initState() {
    super.initState();
    ChatNotifications.instance.openThreadUserId = widget.otherUserId;
    final realtime = RealtimeService.instance;
    _subs
      ..add(realtime.chatStream.listen(_onLiveMessage))
      ..add(
        realtime.readStream.listen((receipt) {
          if (receipt.byId == widget.otherUserId) setState(() => _otherLastReadAt = receipt.at);
        }),
      )
      ..add(
        realtime.requestStream.listen((update) {
          if (update.userId != widget.otherUserId) return;
          setState(() => _status = update.accepted ? ChatStatus.accepted : ChatStatus.declined);
        }),
      );
    _scrollController.addListener(_maybeLoadOlder);
    final unsent = _outbox[widget.otherUserId];
    if (unsent != null) _messages.addAll(unsent.map((m) => m.withDelivery(_Delivery.failed)));
    _load();
  }

  void _onLiveMessage(ChatMessage message) {
    final other = widget.otherUserId;
    final isThisThread =
        (message.fromId == other && message.targetId == _myId) ||
        (message.fromId == _myId && message.targetId == other);
    if (!isThisThread) return;
    setState(() {
      if (!message.pending) {
        _status = ChatStatus.accepted;
      } else if (_status == null || _status == ChatStatus.none) {
        _status = message.requesterId == _myId ? ChatStatus.outgoing : ChatStatus.incoming;
      }
    });
    _addMessages([_fromLive(message)]);
    if (message.fromId == other) _markRead();
  }

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loadFailed = false);
    try {
      final (history, blocked) = await (
        ChatApi.getMessages(token, widget.otherUserId),
        SafetyApi.blocked(token).catchError((_) => const <BlockedPerson>[]),
      ).wait;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = history.hasMore;
        _status = history.status;
        _otherLastReadAt = history.otherLastReadAt;
        _blocked = history.blocked;
        _iBlocked = blocked.any((b) => b.userId == widget.otherUserId);
      });
      _addMessages(history.messages.map(_fromHistory), scroll: true);
      if (history.messages.any((m) => m.senderId == widget.otherUserId)) _markRead();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// Loads the previous page when scrolled near the top, keeping the view
  /// where it was (the new messages appear above).
  Future<void> _maybeLoadOlder() async {
    if (!_hasMore || _loadingOlder || _messages.isEmpty) return;
    if (_scrollController.position.pixels > 120) return;
    final token = AuthSession.accessToken;
    if (token == null) return;
    setState(() => _loadingOlder = true);
    try {
      final oldest = _messages.firstWhere((m) => m.delivery == _Delivery.sent, orElse: () => _messages.first);
      final page = await ChatApi.getMessages(token, widget.otherUserId, before: oldest.createdAt);
      if (!mounted) return;
      final extentBefore = _scrollController.position.maxScrollExtent;
      setState(() => _hasMore = page.hasMore);
      _addMessages(page.messages.map(_fromHistory));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final grown = _scrollController.position.maxScrollExtent - extentBefore;
        _scrollController.jumpTo(_scrollController.position.pixels + grown);
      });
    } catch (_) {
      // Scrolling up again retries.
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _markRead() {
    final token = AuthSession.accessToken;
    if (token == null) return;
    ChatApi.markRead(token, widget.otherUserId).then((_) => ChatNotifications.instance.refresh()).ignore();
  }

  static _ThreadMessage _fromLive(ChatMessage message) =>
      _ThreadMessage(id: message.id, fromId: message.fromId, body: message.body, createdAt: message.createdAt);

  static _ThreadMessage _fromHistory(HistoryMessage message) =>
      _ThreadMessage(id: message.id, fromId: message.senderId, body: message.body, createdAt: message.createdAt);

  /// The same message can arrive up to three ways (history, the live socket,
  /// and the send response) in any order — skip ones already shown and keep
  /// the thread in time order, with anything still sending at the end.
  void _addMessages(Iterable<_ThreadMessage> incoming, {bool scroll = false}) {
    final known = {for (final m in _messages) m.id};
    final fresh = incoming.where((m) => known.add(m.id)).toList();
    if (fresh.isEmpty) return;
    setState(() {
      _messages
        ..addAll(fresh)
        ..sort((a, b) {
          final pendingA = a.delivery != _Delivery.sent;
          final pendingB = b.delivery != _Delivery.sent;
          if (pendingA != pendingB) return pendingA ? 1 : -1;
          return a.createdAt.compareTo(b.createdAt);
        });
    });
    final nearBottom =
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent - _scrollController.position.pixels < 200;
    if (scroll || nearBottom) _scrollToBottom();
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final local = _ThreadMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      fromId: _myId,
      body: text,
      createdAt: DateTime.now(),
      delivery: _Delivery.sending,
    );
    _addMessages([local], scroll: true);
    await _deliver(local);
  }

  /// Sends (or re-sends) a local message and swaps it for the server's copy.
  Future<void> _deliver(_ThreadMessage local) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    _replace(local.id, local.withDelivery(_Delivery.sending));
    try {
      final sent = await ChatApi.sendMessage(token, widget.otherUserId, local.body);
      if (!mounted) return;
      _sentAny = true;
      _outbox[widget.otherUserId]?.removeWhere((m) => m.id == local.id);
      setState(() {
        _messages.removeWhere((m) => m.id == local.id);
        if (sent.pending && (_status == null || _status == ChatStatus.none)) _status = ChatStatus.outgoing;
        if (!sent.pending) _status = ChatStatus.accepted;
      });
      _addMessages([_fromLive(sent)]);
    } catch (error) {
      if (!mounted) return;
      _replace(local.id, local.withDelivery(_Delivery.failed));
      final unsent = _outbox.putIfAbsent(widget.otherUserId, () => []);
      if (!unsent.any((m) => m.id == local.id)) unsent.add(local);
      final message = error is ChatApiException ? error.message : t("Couldn't send your message. Try again.");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      // Refusals (request pending/declined, blocked) change what the screen should show.
      if (error is ChatApiException && (error.statusCode == 403 || error.statusCode == 409)) _load();
    }
  }

  void _replace(String id, _ThreadMessage message) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) setState(() => _messages[index] = message);
  }

  Future<void> _respond(bool accept) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      if (accept) {
        await ChatApi.acceptRequest(token, widget.otherUserId);
      } else {
        await ChatApi.declineRequest(token, widget.otherUserId);
      }
      ChatNotifications.instance.refresh();
      if (!mounted) return;
      if (accept) {
        setState(() => _status = ChatStatus.accepted);
      } else {
        Navigator.of(context).pop(_sentAny);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Something went wrong. Try again.'))));
    }
  }

  Future<void> _toggleBlock() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    if (!_iBlocked) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('Block {name}?', {'name': widget.otherName})),
          content: Text(t("You won't see each other on HERE, and neither of you can send messages.")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel'))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Block'))),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      if (_iBlocked) {
        await SafetyApi.unblock(token, widget.otherUserId);
      } else {
        await SafetyApi.block(token, widget.otherUserId);
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Something went wrong. Try again.'))));
    }
  }

  Future<void> _report() async {
    final blocked = await showReportSheet(
      context,
      target: ReportTarget.user,
      targetId: widget.otherUserId,
      blockUserId: widget.otherUserId,
      blockName: widget.otherName,
    );
    if (blocked) await _load();
  }

  @override
  void dispose() {
    if (ChatNotifications.instance.openThreadUserId == widget.otherUserId) {
      ChatNotifications.instance.openThreadUserId = null;
    }
    for (final sub in _subs) {
      sub.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// My most recent sent message — the one that shows "Sent"/"Seen".
  String? get _lastMineSentId {
    for (final message in _messages.reversed) {
      if (message.fromId == _myId && message.delivery == _Delivery.sent) return message.id;
    }
    return null;
  }

  bool get _canSend => !_loadFailed && !_blocked && _status != ChatStatus.outgoing && _status != ChatStatus.declined;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lastMineSent = _lastMineSentId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_sentAny);
      },
      child: Scaffold(
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
                decoration: BoxDecoration(color: colors.sandDeep, shape: BoxShape.circle),
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
              Flexible(
                child: Text(
                  widget.otherName,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.personName.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) => value == 'block' ? _toggleBlock() : _report(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'block', child: Text(_iBlocked ? t('Unblock') : t('Block'))),
                PopupMenuItem(value: 'report', child: Text(t('Report'))),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.green))
                    : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            t('Say hi to start the conversation.'),
                            textAlign: TextAlign.center,
                            style: AppText.reputationLine.copyWith(color: colors.ink50),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_hasMore && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink38),
                                ),
                              ),
                            );
                          }
                          final message = _messages[index - (_hasMore ? 1 : 0)];
                          final isMine = message.fromId == _myId;
                          final seen = _otherLastReadAt != null && !message.createdAt.isAfter(_otherLastReadAt!);
                          return _MessageBubble(
                            message: message,
                            isMine: isMine,
                            receipt: isMine && message.id == lastMineSent ? (seen ? t('Seen') : t('Sent')) : null,
                            onRetry: message.delivery == _Delivery.failed ? () => _deliver(message) : null,
                          );
                        },
                      ),
              ),
              if (_loadFailed)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    child: Text(t("Couldn't load messages. Tap to retry.")),
                  ),
                )
              else if (_status case final status?)
                _StatusBanner(
                  status: status,
                  blocked: _blocked,
                  iBlocked: _iBlocked,
                  name: widget.otherName,
                  onAccept: () => _respond(true),
                  onDecline: () => _respond(false),
                  onUnblock: _toggleBlock,
                ),
              if (_canSend)
                _Composer(
                  controller: _controller,
                  onSend: _send,
                  hint: _status == ChatStatus.incoming ? t('Reply to accept...') : t('Type a message...'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What's going on with this chat, above the composer: a request to answer,
/// one you're waiting on, a declined one, a block, or — before first
/// contact — how chat requests work.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.blocked,
    required this.iBlocked,
    required this.name,
    required this.onAccept,
    required this.onDecline,
    required this.onUnblock,
  });

  final ChatStatus status;
  final bool blocked;
  final bool iBlocked;
  final String name;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String text;
    List<Widget> actions = const [];
    if (blocked) {
      text = iBlocked
          ? t("You blocked {name}. Unblock to chat again.", {'name': name})
          : t("You can't message {name}.", {'name': name});
      if (iBlocked) actions = [TextButton(onPressed: onUnblock, child: Text(t('Unblock')))];
    } else {
      switch (status) {
        case ChatStatus.incoming:
          text = t('{name} wants to chat. Accept to reply, or decline.', {'name': name});
          actions = [
            TextButton(
              onPressed: onDecline,
              child: Text(t('Decline'), style: TextStyle(color: colors.ink55)),
            ),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(backgroundColor: colors.green, foregroundColor: Colors.white),
              child: Text(t('Accept')),
            ),
          ];
        case ChatStatus.outgoing:
          text = t('Chat request sent. You can send more once {name} accepts.', {'name': name});
        case ChatStatus.declined:
          text = t('{name} declined your chat request.', {'name': name});
        case ChatStatus.none:
          text = t('Your first message is a chat request — say what you need, so {name} knows if they can help.', {
            'name': name,
          });
        case ChatStatus.accepted:
          return const SizedBox.shrink();
      }
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        color: colors.greenTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.reachableStatBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppText.meta.copyWith(color: colors.ink70, fontSize: 13)),
          if (actions.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [for (final a in actions) a])
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine, this.receipt, this.onRetry});

  final _ThreadMessage message;
  final bool isMine;

  /// "Sent" / "Seen" under your latest delivered message.
  final String? receipt;

  /// Set when sending failed — tapping the bubble tries again.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final time = DateFormat.Hm(AppLocale.current.value.languageCode).format(message.createdAt.toLocal());
    final String? status = switch (message.delivery) {
      _Delivery.sending => t('Sending…'),
      _Delivery.failed => t('Not sent · Tap to retry'),
      _Delivery.sent => receipt,
    };

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onRetry,
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: message.delivery == _Delivery.sent ? 1 : 0.6,
              child: Container(
                margin: EdgeInsets.only(bottom: status == null ? 10 : 3),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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
                      style: AppText.reputationLine.copyWith(color: isMine ? Colors.white : colors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      time,
                      style: AppText.meta.copyWith(
                        fontSize: 10,
                        color: isMine ? Colors.white.withValues(alpha: 0.75) : colors.ink38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 4),
                child: Text(
                  status,
                  style: AppText.meta.copyWith(
                    fontSize: 11,
                    color: message.delivery == _Delivery.failed ? colors.error : colors.ink45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.hint});

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hint;

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
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 14.5, color: colors.ink),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppText.meta.copyWith(color: colors.ink38),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              decoration: BoxDecoration(color: colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
