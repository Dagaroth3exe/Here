import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/ask_api.dart';
import '../services/auth_session.dart';
import '../services/location_service.dart';

/// The "Ask HERE" tab: ask anything and see what real people who were in the
/// same situation said on community forums — their replies as they wrote
/// them, a summary of only what they said, and nearby places when relevant.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription<AskEvent>? _sub;

  String? _question;
  AskStage? _stage;
  final _answer = StringBuffer();
  List<CommunityReply> _replies = const [];
  List<AskPlace> _places = const [];
  String? _area;
  String? _error;
  bool _running = false;

  static final _suggestions = [
    'Good places to eat nearby',
    'Where can I catch up with friends around here?',
    'Nearest pharmacy',
    'Which areas nearby are good for renting a flat?',
  ];

  Future<void> _ask(String raw) async {
    final question = raw.trim();
    final token = AuthSession.accessToken;
    if (question.isEmpty || token == null) return;

    FocusScope.of(context).unfocus();
    await _sub?.cancel();
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _question = question;
      _stage = AskStage.searching;
      _answer.clear();
      _replies = const [];
      _places = const [];
      _area = null;
      _error = null;
      _running = true;
    });

    // "Nearby" only works with a real fix — never search around the fallback.
    await LocationService.resolve();
    final fix = LocationService.cached;
    if (!mounted) return;

    _sub = AskApi.ask(token, question, lat: fix?.latitude, lng: fix?.longitude).listen(
      (event) => setState(() {
        switch (event) {
          case AskStatus(:final stage):
            _stage = stage;
          case AskContext(:final area):
            _area = area;
          case AskReplies(:final replies):
            _replies = replies;
          case AskPlaces(:final places):
            _places = places;
          case AskToken(:final text):
            _answer.write(text);
          case AskDone():
            _running = false;
          case AskFailed():
            _error = t("Couldn't get an answer right now. Try again in a moment.");
            _running = false;
        }
      }),
      onError: (Object error) => setState(() {
        _error = t("Couldn't get an answer right now. Try again in a moment.");
        _running = false;
      }),
      onDone: () => setState(() => _running = false),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.paper,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Ask HERE'), style: AppText.screenTitle.copyWith(color: colors.ink)),
                const SizedBox(height: 4),
                Text(
                  t('Ask anything. See what people who were in the same situation said.'),
                  style: AppText.reputationLine.copyWith(color: colors.ink50),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: _question == null ? _suggestionList(colors) : _answerView(colors),
            ),
          ),
          _AskComposer(controller: _controller, enabled: !_running, onSend: () => _ask(_controller.text)),
        ],
      ),
    );
  }

  List<Widget> _suggestionList(AppColors colors) => [
        Text(t('Try asking'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                label: Text(t(suggestion)),
                labelStyle: AppText.chipLabel.copyWith(color: colors.ink70),
                backgroundColor: colors.surface,
                side: BorderSide(color: colors.hairlineChip),
                shape: const StadiumBorder(),
                onPressed: () => _ask(t(suggestion)),
              ),
          ],
        ),
      ];

  List<Widget> _answerView(AppColors colors) => [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(color: colors.green, borderRadius: BorderRadius.circular(18)),
            child: Text(_question!, style: AppText.reputationLine.copyWith(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 16),
        _AnswerCard(
          stage: _running && _answer.isEmpty ? _stage : null,
          area: _area,
          answer: _answer.toString(),
          error: _error,
          replies: _replies,
          onOpenReply: _open,
        ),
        if (_replies.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(t('What people said'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 10),
          for (final reply in _replies) _ReplyCard(reply: reply, onOpen: () => _open(reply.url)),
        ],
        if (_places.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(t('Nearby'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 8),
          for (final place in _places.take(6)) _PlaceRow(place: place),
        ],
        if (!_running && _replies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            t('Replies are from Reddit and Stack Exchange users. The summary is AI-written, so check the replies.'),
            style: AppText.meta.copyWith(color: colors.ink42),
          ),
        ],
      ];
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.stage,
    required this.area,
    required this.answer,
    required this.error,
    required this.replies,
    required this.onOpenReply,
  });

  /// Shown as progress until the first words arrive.
  final AskStage? stage;
  final String? area;
  final String answer;
  final String? error;
  final List<CommunityReply> replies;
  final ValueChanged<String> onOpenReply;

  static final _citation = RegExp(r'\[(\d+(?:\s*,\s*\d+)*)\]');

  String _stageLabel(AskStage stage) => switch (stage) {
        AskStage.searching => t('Finding people who asked the same thing…'),
        AskStage.reading => t('Reading their replies…'),
        AskStage.answering => t('Summarising what they said…'),
      };

  /// Plain text with each "[2]" turned into a small tappable source badge.
  List<InlineSpan> _spans(AppColors colors) {
    // Small models sometimes end with a bare row of citations ("[1][2][3]…").
    final text = answer.replaceAll('**', '').replaceFirst(RegExp(r'\n[\s\[\]\d,]*\]\s*$'), '');
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _citation.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
      for (final n in match.group(1)!.split(',').map((s) => int.tryParse(s.trim()))) {
        final reply = replies.where((r) => r.n == n).firstOrNull;
        if (reply == null) continue;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => onOpenReply(reply.url),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: colors.greenTint, borderRadius: BorderRadius.circular(6)),
              child: Text('$n', style: AppText.meta.copyWith(color: colors.greenInk, fontSize: 11)),
            ),
          ),
        ));
      }
      last = match.end;
    }
    spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Widget body;
    if (error != null) {
      body = Text(error!, style: AppText.reputationLine.copyWith(color: colors.error));
    } else if (stage != null) {
      body = Row(
        children: [
          SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.green)),
          const SizedBox(width: 12),
          Expanded(child: Text(_stageLabel(stage!), style: AppText.reputationLine.copyWith(color: colors.ink55))),
        ],
      );
    } else {
      body = Text.rich(
        TextSpan(children: _spans(colors)),
        style: AppText.reputationLine.copyWith(color: colors.ink, height: 1.5),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 15, color: colors.greenInk),
              const SizedBox(width: 6),
              Text(t('What people say'), style: AppText.statusEyebrow.copyWith(color: colors.greenInk)),
            ],
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place});

  final AskPlace place;

  String get _distance =>
      place.distanceM < 1000 ? '${place.distanceM} m' : '${(place.distanceM / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.place_outlined, size: 18, color: colors.ink45),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: AppText.personName.copyWith(color: colors.ink, fontSize: 14.5)),
                if (place.kind.isNotEmpty)
                  Text(place.kind, style: AppText.meta.copyWith(color: colors.ink50)),
              ],
            ),
          ),
          Text(_distance, style: AppText.meta.copyWith(color: colors.ink55)),
        ],
      ),
    );
  }
}

/// One person's reply, as they wrote it: who, where, how the community
/// rated it, and when. Long replies fold to a few lines.
class _ReplyCard extends StatefulWidget {
  const _ReplyCard({required this.reply, required this.onOpen});

  final CommunityReply reply;
  final VoidCallback onOpen;

  @override
  State<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<_ReplyCard> {
  static const _foldedLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reply = widget.reply;
    final when = DateFormat.yMMM(AppLocale.current.value.languageCode).format(reply.createdAt.toLocal());
    final meta = AppText.meta.copyWith(color: colors.ink50);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(color: colors.greenTint, borderRadius: BorderRadius.circular(6)),
                child: Text('${reply.n}', style: AppText.meta.copyWith(color: colors.greenInk, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: reply.author, style: AppText.chipLabel.copyWith(color: colors.ink)),
                    TextSpan(text: ' · ${reply.community}', style: meta),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_upward, size: 13, color: colors.ink45),
              Text('${reply.score}', style: meta),
              Text('  ·  $when', style: meta),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final style = AppText.reputationLine.copyWith(color: colors.ink, height: 1.45);
              final painter = TextPainter(
                text: TextSpan(text: reply.text, style: style),
                maxLines: _foldedLines,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: constraints.maxWidth);
              final foldable = painter.didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reply.text,
                    style: style,
                    maxLines: _expanded ? null : _foldedLines,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                  ),
                  if (foldable)
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _expanded ? t('Show less') : t('Show more'),
                          style: AppText.chipLabel.copyWith(color: colors.greenInk),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, size: 14, color: colors.ink45),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reply.threadTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: meta,
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 13, color: colors.ink45),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskComposer extends StatelessWidget {
  const _AskComposer({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
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
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 14.5, color: colors.ink),
                decoration: InputDecoration(
                  hintText: t('Ask a question...'),
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
          Material(
            color: enabled ? colors.green : colors.hairline,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: t('Ask'),
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: enabled ? onSend : null,
            ),
          ),
        ],
      ),
    );
  }
}
