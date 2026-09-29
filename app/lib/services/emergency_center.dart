import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/emergency_alert_screen.dart';
import 'auth_session.dart';
import 'emergency_api.dart';
import 'location_service.dart';
import 'push_notifications.dart';
import 'realtime_service.dart';

/// The local emergency number shown everywhere an alert is — HERE alerts
/// people nearby, but it's never a substitute for the real emergency
/// services. 112 is India's (and the EU's) single emergency number.
const emergencyNumber = '112';

/// Everything about emergencies on this phone, app-wide:
///
/// * someone nearby raised the alarm → siren, vibration, and the full-screen
///   red alert over whatever screen is open (see [EmergencyAlertScreen]);
/// * your own alarm → raising it, sharing your location while it's open, and
///   closing it ("I'm safe now").
class EmergencyCenter {
  EmergencyCenter._();

  static final instance = EmergencyCenter._();

  /// Alerts from people nearby, by id — each screen listens for its own.
  final ValueNotifier<Map<String, EmergencyAlert>> incoming = ValueNotifier(const {});

  /// Your own open alarm, if any.
  final ValueNotifier<EmergencyAlert?> mine = ValueNotifier(null);

  /// Whether the siren is sounding right now.
  final ValueNotifier<bool> sounding = ValueNotifier(false);

  /// Your false alarms and whether SOS is paused for them (null until loaded).
  final ValueNotifier<SosStanding?> standing = ValueNotifier(null);

  /// Alerts you've flagged as false alarms, so the button shows it.
  final ValueNotifier<Set<String>> flagged = ValueNotifier(const {});

  StreamSubscription<SosStanding>? _strikeSub;

  /// Keeps everyone alerted following you as you move.
  static const _locationEvery = Duration(seconds: 15);

  /// A siren that nobody silences stops on its own after this long.
  static const _sirenLimit = Duration(minutes: 2);

  StreamSubscription<EmergencyEvent>? _sub;
  AudioPlayer? _player;
  Timer? _buzz;
  Timer? _sirenCutoff;
  Timer? _locationTimer;
  final Set<String> _showing = {};

  /// At sign-in (each time — a different account may have an alarm open).
  void start() {
    _sub ??= RealtimeService.instance.emergencyStream.listen(_onEvent);
    _strikeSub ??= RealtimeService.instance.sosStrikeStream.listen((s) => standing.value = s);
    _restoreMine();
    refreshStanding();
  }

  // --- Someone nearby ------------------------------------------------------

  void _onEvent(EmergencyEvent event) {
    final alert = event.alert;
    incoming.value = {...incoming.value, alert.id: alert};
    switch (event.type) {
      case EmergencyEventType.alert:
        startSiren();
        show(alert.id);
      case EmergencyEventType.update:
        break;
      case EmergencyEventType.resolved:
        if (!incoming.value.values.any((a) => !a.resolved)) stopSiren();
    }
  }

  /// Brings up the red full-screen alert (once per alert), from wherever.
  void show(String id) {
    final navigator = PushNotifications.navigatorKey.currentState;
    if (navigator == null || !_showing.add(id)) return;
    navigator
        .push(
          PageRouteBuilder<void>(
            opaque: true,
            transitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (_, _, _) => EmergencyAlertScreen(alertId: id),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
          ),
        )
        .whenComplete(() => _showing.remove(id));
  }

  /// A tapped emergency notification: fetch it (the socket may have missed
  /// it while the app was closed) and show it.
  Future<void> open(String id) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      final alert = await EmergencyApi.get(token, id);
      incoming.value = {...incoming.value, alert.id: alert};
      show(alert.id);
    } catch (_) {
      // Gone or not ours to see — nothing to open.
    }
  }

  /// Loud, looping, on the alarm stream (so it isn't muted with media), with
  /// the phone buzzing alongside.
  Future<void> startSiren() async {
    if (sounding.value) return;
    sounding.value = true;
    final player = _player ??= AudioPlayer();
    try {
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1);
      await player.play(AssetSource('sounds/siren.wav'));
    } catch (_) {
      // No sound is bad, but the red screen and vibration still work.
    }
    _buzz?.cancel();
    _buzz = Timer.periodic(const Duration(milliseconds: 800), (_) => HapticFeedback.vibrate());
    _sirenCutoff?.cancel();
    _sirenCutoff = Timer(_sirenLimit, stopSiren);
  }

  void stopSiren() {
    sounding.value = false;
    _buzz?.cancel();
    _sirenCutoff?.cancel();
    _player?.stop().ignore();
  }

  // --- Your own alarm ------------------------------------------------------

  /// Raises the alarm at your current location. Throws with a message to
  /// show if it couldn't be sent.
  Future<EmergencyAlert> raise({EmergencyReason? reason, String? message}) async {
    final token = AuthSession.accessToken;
    if (token == null) throw StateError('Signed out');
    // Send at once with the last known position rather than waiting (up to
    // ~8 s) for a fresh GPS fix; the precise one follows straight after.
    final cached = LocationService.cached;
    final fix = cached ?? await LocationService.locate();
    if (fix == null) throw const LocationUnavailable();
    EmergencyAlert alert;
    try {
      alert = await EmergencyApi.raise(token, lat: fix.latitude, lng: fix.longitude, reason: reason, message: message);
    } on EmergencyUnreachable {
      // No answer isn't "not sent": on a slow connection the alarm can reach
      // the server and go out while the reply is lost. Telling someone in
      // danger it failed when people are already on their way (and leaving
      // them no way to end it) would be worse than a short wait — so ask.
      final sent = await _confirmSent(token);
      if (sent == null) rethrow;
      alert = sent;
    }
    _setMine(alert);
    if (cached != null) _sendPreciseLocation();
    return alert;
  }

  /// Whether an alarm we didn't hear back about did go out — a few tries,
  /// since the connection that lost the reply may still be struggling.
  Future<EmergencyAlert?> _confirmSent(String token) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await EmergencyApi.mine(token);
      } on EmergencyUnreachable {
        await Future<void>.delayed(const Duration(seconds: 2));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// "I'm safe now" (or, with [falseAlarm], "it wasn't real"): closes the
  /// alarm and silences everyone's siren.
  Future<void> resolve({bool falseAlarm = false}) async {
    final alert = mine.value;
    final token = AuthSession.accessToken;
    if (alert == null || token == null) return;
    await EmergencyApi.resolve(token, alert.id, falseAlarm: falseAlarm);
    _setMine(null);
    if (falseAlarm) refreshStanding();
  }

  Future<void> refreshStanding() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      standing.value = await EmergencyApi.standing(token);
    } catch (_) {
      // Keep what we had; the server enforces the pause regardless.
    }
  }

  /// You were alerted, and it wasn't real. It only counts once enough
  /// different people say so, so one person can't penalise a real victim.
  Future<void> flag(String id) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await EmergencyApi.flag(token, id);
    flagged.value = {...flagged.value, id};
  }

  Future<void> _sendPreciseLocation() async {
    final fix = await LocationService.locate();
    final token = AuthSession.accessToken;
    final current = mine.value;
    if (fix == null || token == null || current == null) return;
    await EmergencyApi.updateLocation(token, current.id, fix.latitude, fix.longitude).catchError((_) {});
  }

  Future<void> _restoreMine() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      _setMine(await EmergencyApi.mine(token));
    } catch (_) {}
  }

  void _setMine(EmergencyAlert? alert) {
    mine.value = alert;
    _locationTimer?.cancel();
    if (alert == null) return;
    _locationTimer = Timer.periodic(_locationEvery, (_) async {
      final token = AuthSession.accessToken;
      final current = mine.value;
      if (token == null || current == null) return;
      // The server stops treating an alarm as open after an hour.
      if (DateTime.now().difference(current.createdAt) > const Duration(hours: 1)) {
        _setMine(null);
        return;
      }
      final fix = await LocationService.locate();
      if (fix == null) return;
      // A failed update (offline for a moment) is simply retried next tick.
      await EmergencyApi.updateLocation(token, current.id, fix.latitude, fix.longitude).catchError((_) {});
    });
  }

  /// Signed out: nothing of the last account's should keep sounding or sharing.
  void reset() {
    stopSiren();
    _setMine(null);
    incoming.value = const {};
    standing.value = null;
    flagged.value = const {};
  }
}

/// Raising the alarm needs a location, and there wasn't one.
class LocationUnavailable implements Exception {
  const LocationUnavailable();
}
