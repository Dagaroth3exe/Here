import 'dart:async';

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/ask_api.dart';
import '../services/auth_session.dart';
import '../services/location_service.dart';
import '../widgets/ask_widgets.dart';
import 'ask_question_screen.dart';

/// The "Ask HERE" tab: ask anything and see what real people who were in the
/// same situation said on community forums — their replies as they wrote
/// them, a summary of only what they said, and nearby places when relevant.
///
/// Every question is also kept (anonymously) for the HERE community: people
/// who ask something similar later see it and its answers first, and anyone
/// can answer it.
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
  /// "What people say" (forum summary) and "From the web", as they stream in.
  final _answer = StringBuffer();
  final _webAnswer = StringBuffer();
  List<WebSource> _webSources = const [];
  List<CommunityReply> _replies = const [];
  AskPlaces? _places;
  List<PastQuestion> _similar = const [];
  String? _savedId;
  String? _error;
  bool _running = false;

  /// Questions recently asked around here, shown before you ask anything.
  List<PastQuestion> _recent = const [];

  static final _suggestions = [
    'Good places to eat nearby',
    'Where can I catch up with friends around here?',
    'Nearest pharmacy',
    'Which areas nearby are good for renting a flat?',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await LocationService.resolve();
    final fix = LocationService.cached;
    try {
      final recent = await AskApi.recent(token, lat: fix?.latitude, lng: fix?.longitude);
      if (mounted) setState(() => _recent = recent);
    } catch (_) {
      // The feed is a nice-to-have; asking still works without it.
    }
  }

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
      _webAnswer.clear();
      _webSources = const [];
      _replies = const [];
      _places = null;
      _similar = const [];
      _savedId = null;
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
          case AskContext():
            // The area only shapes the server's search; nothing to show.
            break;
          case AskSimilar(:final questions):
            _similar = questions;
          case AskReplies(:final replies):
            _replies = replies;
          case AskPlaces():
            _places = event;
          case AskToken(:final text):
            _answer.write(text);
          case AskWebSources(:final sources):
            _webSources = sources;
          case AskWebToken(:final text):
            _webAnswer.write(text);
          case AskSaved(:final id):
            _savedId = id;
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
      onDone: () {
        setState(() => _running = false);
        _loadRecent();
      },
    );
  }

  Future<void> _openQuestion(String id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AskQuestionScreen(questionId: id)));
    // Answer counts (or the question itself, if deleted) may have changed.
    _loadRecent();
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
              children: _question == null ? _landing(colors) : _answerView(colors),
            ),
          ),
          AskComposer(
            controller: _controller,
            enabled: !_running,
            onSend: () => _ask(_controller.text),
            hint: t('Ask a question...'),
            sendTooltip: t('Ask'),
          ),
        ],
      ),
    );
  }

  String? _communityProgress(AskStage? stage) => switch (stage) {
        null => null,
        AskStage.searching => t('Finding people who asked the same thing…'),
        AskStage.reading => t('Reading their replies…'),
        AskStage.answering => t('Summarising what they said…'),
      };

  String? _webProgress(AskStage? stage) => switch (stage) {
        null => null,
        AskStage.searching => t('Searching the web…'),
        AskStage.reading => t('Reading pages…'),
        AskStage.answering => t('Writing an answer…'),
      };

  List<Widget> _landing(AppColors colors) => [
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
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(t('Recently asked near you'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 10),
          for (final question in _recent) PastQuestionTile(question: question, onTap: () => _openQuestion(question.id)),
        ],
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
        if (_similar.isNotEmpty) ...[
          Text(t('Asked on HERE before'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 10),
          for (final question in _similar) PastQuestionTile(question: question, onTap: () => _openQuestion(question.id)),
          const SizedBox(height: 16),
        ],
        AskSummaryCard(
          title: t('What people say'),
          icon: Icons.forum_outlined,
          progress: _running && _answer.isEmpty ? _communityProgress(_stage) : null,
          answer: _answer.toString(),
          error: _error,
          citations: {for (final r in _replies) r.n: r.url},
          onOpenCitation: openLink,
        ),
        const SizedBox(height: 12),
        AskSummaryCard(
          title: t('From the web'),
          icon: Icons.auto_awesome,
          progress: _running && _webAnswer.isEmpty ? _webProgress(_stage) : null,
          answer: _webAnswer.toString(),
          error: _error,
          citations: {for (final s in _webSources) s.n: s.url},
          onOpenCitation: openLink,
        ),
        if (_replies.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(t('What people said'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 10),
          for (final reply in _replies) CommunityReplyCard(reply: reply, onOpen: () => openLink(reply.url)),
        ],
        if (_places case final places? when places.places.isNotEmpty) ...[
          const SizedBox(height: 20),
          ClosestPlacesSection(places: places),
        ],
        if (_webSources.isNotEmpty && _webAnswer.isNotEmpty) ...[
          const SizedBox(height: 20),
          WebSourcesSection(sources: _webSources),
        ],
        if (_savedId case final id?) ...[
          const SizedBox(height: 20),
          _SharedNote(onView: () => _openQuestion(id)),
        ],
        if (!_running && _replies.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            t('Replies are from Reddit and Stack Exchange users. Both answers are AI-written, so check the sources.'),
            style: AppText.meta.copyWith(color: colors.ink42),
          ),
        ],
      ];
}

/// Tells the asker their question is now on HERE (anonymously) for people
/// nearby to answer, with a way to open it.
class _SharedNote extends StatelessWidget {
  const _SharedNote({required this.onView});

  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.greenTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.reachableStatBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, size: 20, color: colors.greenInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('Shared anonymously on HERE, so people nearby can answer it too.'),
              style: AppText.meta.copyWith(color: colors.ink70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onView,
            child: Text(t('View'), style: AppText.chipLabel.copyWith(color: colors.greenInk)),
          ),
        ],
      ),
    );
  }
}
