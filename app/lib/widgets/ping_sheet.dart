import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_api.dart';
import '../services/auth_session.dart';
import '../services/chat_api.dart';
import '../services/realtime_service.dart';

/// Why you're pinging — each picks a ready-made opener addressed to them by
/// name, which you can then edit before sending. English source text, run
/// through `t()` like every other UI string.
const _reasons = [
  (label: 'Say hi', message: "Hi {name}! I saw you're nearby and Reachable — just wanted to say hello."),
  (label: 'Local question', message: "Hi {name}! I'm close by and have a quick local question — got a minute?"),
  (label: 'Recommendation', message: 'Hi {name}! Could you recommend a good spot around here?'),
  (
    label: 'Need a hand',
    message: 'Hi {name}! I could use a hand with something nearby — would you be open to helping?',
  ),
  (label: 'Meet up', message: 'Hi {name}! Fancy grabbing a coffee nearby sometime?'),
];

/// Matches the server's MAX_MESSAGE_LENGTH for chat messages.
const _maxLength = 2000;

/// Composes and sends a ping to [person] without leaving the current screen.
/// Returns whether one was sent.
Future<bool> showPingSheet(BuildContext context, ReachablePerson person) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _PingSheet(person: person),
  );
  return sent ?? false;
}

class _PingSheet extends StatefulWidget {
  const _PingSheet({required this.person});

  final ReachablePerson person;

  @override
  State<_PingSheet> createState() => _PingSheetState();
}

class _PingSheetState extends State<_PingSheet> {
  late final _message = TextEditingController(text: _messageFor(0));
  int? _reason = 0;
  bool _sending = false;
  String? _error;

  String get _firstName => widget.person.name.trim().split(RegExp(r'\s+')).first;

  String _messageFor(int reason) => t(_reasons[reason].message, {'name': _firstName});

  void _pickReason(int reason) {
    setState(() {
      _reason = reason;
      _error = null;
    });
    _message.text = _messageFor(reason);
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    final token = AuthSession.accessToken;
    if (body.isEmpty || token == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (isDemoPerson(widget.person.id)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      } else {
        await ChatApi.sendMessage(token, widget.person.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error is AuthApiException ? t(error.message) : t("Couldn't send your message. Try again.");
      });
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    // Clear the keyboard when it's up, the gesture bar when it isn't.
    final bottomInset = media.viewInsets.bottom > 0 ? media.viewInsets.bottom : media.viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Ping {name}', {'name': _firstName}), style: AppText.sectionHeader.copyWith(color: colors.ink)),
            const SizedBox(height: 4),
            Text(t('Pick a reason, then make it your own.'), style: AppText.meta.copyWith(color: colors.ink50)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _reasons.length; i++)
                  ChoiceChip(
                    label: Text(t(_reasons[i].label)),
                    selected: _reason == i,
                    onSelected: _sending ? null : (_) => _pickReason(i),
                    showCheckmark: false,
                    labelStyle: AppText.chipLabel.copyWith(color: _reason == i ? Colors.white : colors.ink70),
                    selectedColor: colors.green,
                    backgroundColor: colors.surface,
                    side: BorderSide(color: _reason == i ? colors.green : colors.hairlineChip),
                    shape: const StadiumBorder(),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _message,
              enabled: !_sending,
              maxLength: _maxLength,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              // Typing your own words means it's no longer a preset.
              onChanged: (_) {
                if (_reason != null || _error != null) {
                  setState(() {
                    _reason = null;
                    _error = null;
                  });
                }
              },
              style: AppText.reputationLine.copyWith(color: colors.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.surface,
                counterText: '',
                hintText: t('Write a message...'),
                hintStyle: AppText.meta.copyWith(color: colors.ink38),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.green),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppText.meta.copyWith(color: colors.error)),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ListenableBuilder(
                listenable: _message,
                builder: (context, _) => FilledButton(
                  onPressed: _message.text.trim().isEmpty || _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(t('Send ping'), style: AppText.pingButton.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
