import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/ask_api.dart';

/// Building blocks shared by the Ask HERE screen and a saved question's page.

/// Opens a link (forum thread, source) in the browser.
Future<void> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// "Mar 2014" in the app's language.
String monthYear(DateTime date) => DateFormat.yMMM(AppLocale.current.value.languageCode).format(date.toLocal());

/// "Closest places — All within 1.5 km of Vaishali", then the places.
class ClosestPlacesSection extends StatelessWidget {
  const ClosestPlacesSection({super.key, required this.places});

  final AskPlaces places;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final distance = formatDistance(places.radiusM);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Closest places'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
        const SizedBox(height: 2),
        Text(
          places.near == null
              ? t('All within {distance} of you', {'distance': distance})
              : t('All within {distance} of {place}', {'distance': distance, 'place': places.near}),
          style: AppText.meta.copyWith(color: colors.ink50),
        ),
        const SizedBox(height: 6),
        for (final place in places.places) AskPlaceRow(place: place),
      ],
    );
  }
}

/// A question someone asked on HERE before: the question, where and when,
/// and how many HERE members answered.
class PastQuestionTile extends StatelessWidget {
  const PastQuestionTile({super.key, required this.question, required this.onTap});

  final PastQuestion question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final meta = AppText.meta.copyWith(color: colors.ink50);
    final answers = question.answerCount == 0
        ? t('No answers yet')
        : question.answerCount == 1
            ? t('1 answer')
            : t('{count} answers', {'count': question.answerCount});
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.reputationLine.copyWith(color: colors.ink, fontSize: 14.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (question.area != null) t('Near {area}', {'area': question.area}),
                          monthYear(question.createdAt),
                          answers,
                        ].join(' · '),
                        style: meta,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.ink38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "What people say": the AI summary of forum replies, with each [n] turned
/// into a tappable badge — or progress/error while there's no text yet.
class AskSummaryCard extends StatelessWidget {
  const AskSummaryCard({
    super.key,
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

/// "548 m", "1.5 km", "2 km".
String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = (meters / 1000).toStringAsFixed(1);
  return '${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} km';
}

class AskPlaceRow extends StatelessWidget {
  const AskPlaceRow({super.key, required this.place});

  final AskPlace place;

  /// Opens the phone's maps app at the place (a `geo:` link, which open-source
  /// apps like Organic Maps and OsmAnd handle too), or OpenStreetMap on the
  /// web when no maps app is installed.
  Future<void> _openInMaps() async {
    final label = Uri.encodeComponent(place.name);
    final geo = Uri.parse('geo:${place.lat},${place.lng}?q=${place.lat},${place.lng}($label)');
    try {
      if (await launchUrl(geo)) return;
    } catch (_) {
      // No app registered for geo: links — fall through to the web map.
    }
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/?mlat=${place.lat}&mlon=${place.lng}#map=18/${place.lat}/${place.lng}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: _openInMaps,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.place_outlined, size: 18, color: colors.ink45),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: AppText.personName.copyWith(color: colors.ink, fontSize: 14.5)),
                  if (place.kind.isNotEmpty) Text(place.kind, style: AppText.meta.copyWith(color: colors.ink50)),
                ],
              ),
            ),
            Text(formatDistance(place.distanceM), style: AppText.meta.copyWith(color: colors.ink55)),
            const SizedBox(width: 6),
            Icon(Icons.directions_outlined, size: 18, color: colors.greenInk),
          ],
        ),
      ),
    );
  }
}

/// One person's reply, as they wrote it: who, where, how the community
/// rated it, and when. Long replies fold to a few lines.
class CommunityReplyCard extends StatefulWidget {
  const CommunityReplyCard({super.key, required this.reply, required this.onOpen});

  final CommunityReply reply;
  final VoidCallback onOpen;

  @override
  State<CommunityReplyCard> createState() => _CommunityReplyCardState();
}

class _CommunityReplyCardState extends State<CommunityReplyCard> {
  static const _foldedLines = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reply = widget.reply;
    final when = monthYear(reply.createdAt);
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

/// The rounded text field + send button at the bottom of Ask screens.
class AskComposer extends StatelessWidget {
  const AskComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.hint,
    required this.sendTooltip,
    this.maxLength = 500,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final String hint;
  final String sendTooltip;
  final int maxLength;

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
                maxLength: maxLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
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
          Material(
            color: enabled ? colors.green : colors.hairline,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: sendTooltip,
              icon: const Icon(Icons.arrow_upward, color: Colors.white),
              onPressed: enabled ? onSend : null,
            ),
          ),
        ],
      ),
    );
  }
}
