import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/ask_api.dart';
import '../services/auth_session.dart';
import '../widgets/ask_widgets.dart';

/// A question saved on HERE: the question (anonymous, area only), what HERE
/// members answered, a box to add your own answer, and what Ask HERE found
/// on forums and maps when it was first asked.
class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key, required this.questionId});

  final String questionId;

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _controller = TextEditingController();
  QuestionDetail? _detail;
  List<HereAnswer> _answers = const [];
  bool _loadFailed = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    setState(() => _loadFailed = false);
    try {
      final detail = await AskApi.question(token, widget.questionId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _answers = detail.answers;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _postAnswer() async {
    final body = _controller.text.trim();
    final token = AuthSession.accessToken;
    if (body.isEmpty || token == null || _posting) return;
    setState(() => _posting = true);
    try {
      final answer = await AskApi.answer(token, widget.questionId, body);
      if (!mounted) return;
      _controller.clear();
      FocusScope.of(context).unfocus();
      setState(() => _answers = [..._answers, answer]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t("Couldn't post your answer. Try again."))),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _delete() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('Delete this question?')),
        content: Text(t('It and all its answers will be removed from HERE.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Delete'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AskApi.deleteQuestion(token, widget.questionId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t("Couldn't delete it. Try again."))),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = _detail;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        title: Text(t('Asked on HERE'), style: AppText.personName.copyWith(color: colors.ink)),
        actions: [
          if (detail?.mine ?? false)
            IconButton(tooltip: t('Delete'), icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        top: false,
        child: detail == null
            ? Center(
                child: _loadFailed
                    ? TextButton(onPressed: _load, child: Text(t("Couldn't load this question. Tap to retry.")))
                    : CircularProgressIndicator(strokeWidth: 2, color: colors.green),
              )
            : Column(
                children: [
                  Expanded(child: _content(colors, detail)),
                  AskComposer(
                    controller: _controller,
                    enabled: !_posting,
                    onSend: _postAnswer,
                    hint: t('Share what you know...'),
                    sendTooltip: t('Answer'),
                    maxLength: 2000,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _content(AppColors colors, QuestionDetail detail) {
    final meta = AppText.meta.copyWith(color: colors.ink50);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Text(detail.question, style: AppText.sectionHeader.copyWith(color: colors.ink, fontSize: 19, height: 1.35)),
        const SizedBox(height: 6),
        Text(
          [
            detail.area == null ? t('Someone asked') : t('Someone near {area} asked', {'area': detail.area}),
            monthYear(detail.createdAt),
          ].join(' · '),
          style: meta,
        ),
        const SizedBox(height: 22),
        Text(t('Answers from HERE'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
        const SizedBox(height: 10),
        if (_answers.isEmpty)
          Text(
            t('No one on HERE has answered yet. Know something? Share it below.'),
            style: AppText.reputationLine.copyWith(color: colors.ink50),
          )
        else
          for (final answer in _answers) _HereAnswerCard(answer: answer),
        if (detail.replies.isNotEmpty || detail.summary.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text(t('Found when it was asked'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 10),
          AskSummaryCard(
            stage: null,
            area: detail.area,
            answer: detail.summary,
            error: null,
            replies: detail.replies,
            onOpenReply: openLink,
          ),
          if (detail.replies.isNotEmpty) const SizedBox(height: 12),
          for (final reply in detail.replies) CommunityReplyCard(reply: reply, onOpen: () => openLink(reply.url)),
        ],
        if (detail.places case final places? when places.places.isNotEmpty) ...[
          const SizedBox(height: 20),
          ClosestPlacesSection(places: places),
        ],
      ],
    );
  }
}

class _HereAnswerCard extends StatelessWidget {
  const _HereAnswerCard({required this.answer});

  final HereAnswer answer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: answer.mine ? colors.greenTint : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: answer.mine ? colors.reachableStatBorder : colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: answer.mine ? t('You') : answer.author,
                style: AppText.chipLabel.copyWith(color: colors.ink),
              ),
              TextSpan(text: ' · ${monthYear(answer.createdAt)}', style: AppText.meta.copyWith(color: colors.ink50)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(answer.body, style: AppText.reputationLine.copyWith(color: colors.ink, height: 1.45)),
        ],
      ),
    );
  }
}
