import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/auth_api.dart';
import '../services/emergency_api.dart';
import '../services/emergency_center.dart';
import 'emergency_alert_screen.dart';

String emergencyReasonLabel(EmergencyReason reason) => switch (reason) {
  EmergencyReason.harassment => t('Harassment'),
  EmergencyReason.assault => t('Assault'),
  EmergencyReason.followed => t('Being followed'),
  EmergencyReason.medical => t('Medical'),
  EmergencyReason.other => t('Other danger'),
};

/// Raising the alarm: everyone Reachable nearby gets a siren, a red screen,
/// and your live location. Sending takes a deliberate press-and-hold, so a
/// pocket tap can't set off a whole neighbourhood; once it's out, this shows
/// who was alerted and how to end it.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with SingleTickerProviderStateMixin {
  static const _holdFor = Duration(seconds: 2);

  late final AnimationController _hold = AnimationController(vsync: this, duration: _holdFor)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _send();
    });
  final _message = TextEditingController();
  EmergencyReason? _reason;
  bool _sending = false;
  bool _ending = false;

  /// Showing the "count this as a false alarm?" confirmation.
  bool _confirmFalse = false;
  String? _error;

  final center = EmergencyCenter.instance;

  @override
  void initState() {
    super.initState();
    center.refreshStanding();
  }

  @override
  void dispose() {
    _hold.dispose();
    _message.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_sending) return;
    HapticFeedback.mediumImpact();
    _hold.forward(from: 0);
  }

  void _cancelHold() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  Future<void> _send() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await center.raise(reason: _reason, message: _message.text);
    } on LocationUnavailable {
      _error = t("Couldn't get your location. Turn on location, or call {number} now.", {'number': emergencyNumber});
    } on AuthApiException catch (e) {
      _error = t(e.message);
    } catch (_) {
      _error = t("Couldn't send the alert. Call {number} now.", {'number': emergencyNumber});
    }
    if (!mounted) return;
    setState(() => _sending = false);
    _hold.reset();
  }

  Future<void> _end({bool falseAlarm = false}) async {
    setState(() => _ending = true);
    try {
      await center.resolve(falseAlarm: falseAlarm);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _ending = false;
          _error = t("Couldn't reach the server. Check your connection and try again.");
        });
      }
    }
  }

  void _call() => launchUrl(Uri(scheme: 'tel', path: emergencyNumber));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([center.mine, center.standing]),
      builder: (context, _) => _scaffold(center.mine.value),
    );
  }

  Widget _scaffold(EmergencyAlert? active) {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: active != null ? emergencyRed : const Color(0xFF1B1113),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            t('Emergency'),
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: active != null ? _activeView(active) : _composeView(),
          ),
        ),
      ),
    );
  }

  List<Widget> _composeView() {
    const white = Colors.white;
    return [
      Text(
        t('Alert everyone nearby'),
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.w700, color: white),
      ),
      const SizedBox(height: 6),
      Text(
        t('Everyone Reachable within 2 km hears a siren and sees your live location until you say you’re safe.'),
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14.5, height: 1.4, color: Colors.white70),
      ),
      const SizedBox(height: 16),
      _CallButton(onTap: _call),
      const SizedBox(height: 22),
      Text(
        t('What’s happening? (optional)'),
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reason in EmergencyReason.values)
            _ReasonPill(
              label: emergencyReasonLabel(reason),
              selected: _reason == reason,
              onTap: () => setState(() => _reason = _reason == reason ? null : reason),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _message,
        maxLength: 280,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(fontFamily: 'Outfit', color: white),
        cursorColor: white,
        decoration: InputDecoration(
          hintText: t('Where are you, what do you need? (optional)'),
          hintStyle: const TextStyle(fontFamily: 'Outfit', color: Colors.white38),
          counterStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: const TextStyle(fontFamily: 'Outfit', color: Color(0xFFFF8A80), fontSize: 14),
          ),
        ),
      ],
      const SizedBox(height: 22),
      if (center.standing.value?.paused ?? false)
        _PausedNotice(until: center.standing.value!.pausedUntil!)
      else ...[
        Center(
          child: _HoldButton(
            progress: _hold,
            sending: _sending,
            onHoldStart: _startHold,
            onHoldEnd: _cancelHold,
            onActivate: _send,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _sending ? t('Sending alert…') : t('Press and hold for 2 seconds to send'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 18),
        Text(
          t('Only for real danger — a false alarm sends people running for nothing.'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white38),
        ),
        ?_strikeWarning(),
      ],
    ];
  }

  /// One false alarm away from a pause: say so before they send.
  Widget? _strikeWarning() {
    final standing = center.standing.value;
    if (standing == null || standing.falseAlarms == 0) return null;
    final left = standing.limit - standing.falseAlarms;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        left <= 1
            ? t('You’ve had {count} false alarm recently. One more pauses SOS for 30 days.', {
                'count': standing.falseAlarms,
              })
            : t('You’ve had {count} false alarms recently.', {'count': standing.falseAlarms}),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFB74D),
        ),
      ),
    );
  }

  List<Widget> _activeView(EmergencyAlert alert) {
    const white = Colors.white;
    return [
      const Icon(Icons.campaign_rounded, color: white, size: 44),
      const SizedBox(height: 10),
      Semantics(
        liveRegion: true,
        child: Text(
          t('Alert sent'),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 30, fontWeight: FontWeight.w800, color: white),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        alert.alerted == 0
            ? t('No one Reachable is nearby right now. Call {number} for help.', {'number': emergencyNumber})
            : alert.alerted == 1
            ? t('1 person nearby was alerted and can see your location.')
            : t('{count} people nearby were alerted and can see your location.', {'count': alert.alerted}),
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, height: 1.35, color: white),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(Icons.my_location_rounded, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t('Sharing your live location while this is on.'),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 13.5, color: Colors.white70),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      _CallButton(onTap: _call, onRed: true),
      const SizedBox(height: 12),
      SizedBox(
        height: 54,
        child: OutlinedButton.icon(
          onPressed: _ending ? null : _end,
          icon: const Icon(Icons.verified_user_rounded),
          label: Text(
            _ending ? t('Ending alert…') : t('I’m safe now'),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: white,
            side: const BorderSide(color: white, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      const SizedBox(height: 6),
      if (!_confirmFalse)
        TextButton(
          onPressed: _ending ? null : () => setState(() => _confirmFalse = true),
          style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size.fromHeight(48)),
          child: Text(t('It was a false alarm')),
        )
      else
        _FalseAlarmConfirm(
          standing: center.standing.value,
          busy: _ending,
          onCancel: () => setState(() => _confirmFalse = false),
          onConfirm: () => _end(falseAlarm: true),
        ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          style: const TextStyle(fontFamily: 'Outfit', color: white),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        t('You can leave this screen — the alert stays on until you end it here.'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: Colors.white70),
      ),
    ];
  }
}

/// Shown instead of the send button while SOS is paused for false alarms.
/// "Call 112" stays right above it — the way to get help is never blocked.
class _PausedNotice extends StatelessWidget {
  const _PausedNotice({required this.until});

  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd(AppLocale.current.value.languageCode).format(until.toLocal());
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_rounded, color: Color(0xFFFFB74D), size: 28),
            const SizedBox(height: 10),
            Text(
              t('SOS is paused until {date}', {'date': date}),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'Your recent alerts were false alarms, so SOS is paused for 30 days. If you’re in danger, call {number} — that always works.',
                {'number': emergencyNumber},
              ),
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, height: 1.4, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Count this as a false alarm?" — says what it costs before it's final.
class _FalseAlarmConfirm extends StatelessWidget {
  const _FalseAlarmConfirm({
    required this.standing,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final SosStanding? standing;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final pauses = standing != null && standing!.falseAlarms + 1 >= standing!.limit;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pauses
                ? t('This will be your second false alarm, and SOS will be paused for 30 days.')
                : t('This ends the alert and counts as a false alarm. 2 false alarms pause SOS for 30 days.'),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, height: 1.35, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: busy ? null : onCancel,
                  style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
                  child: Text(t('Cancel')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: emergencyRedDeep,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(t('Yes, false alarm')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A reason to pick (or unpick). Hand-drawn rather than a ChoiceChip so the
/// app theme's chip colors can't bleed in on this always-dark screen.
class _ReasonPill extends StatelessWidget {
  const _ReasonPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.08),
        shape: StadiumBorder(side: BorderSide(color: selected ? Colors.white : Colors.white30)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  color: selected ? emergencyRedDeep : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.onTap, this.onRed = false});

  final VoidCallback onTap;
  final bool onRed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.call_rounded),
        label: Text(
          t('Call {number}', {'number': emergencyNumber}),
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: onRed ? emergencyRedDeep : const Color(0xFF1B1113),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// The big round send button: fills while held, fires when full. Screen
/// readers get a plain double-tap action instead, since holding is awkward
/// with TalkBack.
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.progress,
    required this.sending,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.onActivate,
  });

  final Animation<double> progress;
  final bool sending;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.of(context).accessibleNavigation;
    return Semantics(
      button: true,
      label: t('Send emergency alert'),
      onTap: sending ? null : onActivate,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => onHoldStart(),
        onTapUp: (_) => onHoldEnd(),
        onTapCancel: onHoldEnd,
        onTap: accessible && !sending ? onActivate : null,
        child: SizedBox.square(
          dimension: 176,
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: sending ? null : progress.value,
                    strokeWidth: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white12,
                  ),
                ),
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(emergencyRed, emergencyRedDeep, progress.value),
                    boxShadow: [BoxShadow(color: emergencyRed.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 2)],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'SOS',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
