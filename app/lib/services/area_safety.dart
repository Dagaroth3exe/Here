import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'area_api.dart';
import 'auth_session.dart';
import 'location_service.dart';
import 'push_notifications.dart';
import 'realtime_service.dart';

/// What the app knows about recent alerts around you: the line on Home, the
/// in-app heads-up when you walk into an area with recent alerts (the
/// server decides when — at most once per area per day), and the Settings
/// switch for those heads-ups.
class AreaSafety {
  AreaSafety._();

  static final instance = AreaSafety._();

  /// Around your current location; null until known.
  final ValueNotifier<AreaSummary?> current = ValueNotifier(null);

  /// Official NCRB figures for where you are — district and/or city (null if none).
  final ValueNotifier<AreaCrime?> district = ValueNotifier(null);

  /// Whether heads-ups are on (null until loaded).
  final ValueNotifier<bool?> notices = ValueNotifier(null);

  StreamSubscription<AreaSummary>? _sub;

  void start() {
    _sub ??= RealtimeService.instance.areaNoticeStream.listen(_onNotice);
    refresh();
    _loadNotices();
  }

  Future<void> refresh() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    await LocationService.resolve();
    final fix = LocationService.cached;
    if (fix == null) return; // never summarise the fallback location
    try {
      current.value = await AreaApi.summary(token, fix.latitude, fix.longitude);
    } catch (_) {
      // Keep what's shown; it's informational.
    }
    try {
      district.value = await AreaApi.areaCrime(token, fix.latitude, fix.longitude);
    } catch (_) {}
  }

  void _onNotice(AreaSummary summary) {
    current.value = summary;
    final context = PushNotifications.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(duration: const Duration(seconds: 6), content: Text(areaSummaryText(summary))));
  }

  Future<void> _loadNotices() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      notices.value = await AreaApi.notices(token);
    } catch (_) {}
  }

  Future<void> setNotices(bool on) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    final before = notices.value;
    notices.value = on;
    try {
      await AreaApi.setNotices(token, on);
    } catch (_) {
      notices.value = before;
      rethrow;
    }
  }

  void reset() {
    current.value = null;
    district.value = null;
    notices.value = null;
  }
}

/// The one-line description, used on Home and in the heads-up.
String areaSummaryText(AreaSummary summary) => summary.people == null
    ? t('No recent alerts reported nearby')
    : t('{count} people raised alerts within ~1 km in the last {days} days', {
        'count': summary.people,
        'days': summary.windowDays,
      });

/// Crime heads as the app names them (keys from the server).
String crimeHeadLabel(String head) => switch (head) {
  'theft' => t('Theft'),
  'kidnapping' => t('Kidnapping'),
  'fraud' => t('Fraud & cheating'),
  'hurt' => t('Assault (hurt)'),
  'murder' => t('Murder'),
  'womenAssault' => t('Assault on women'),
  'rape' => t('Rape'),
  'burglary' => t('Burglary'),
  'robbery' => t('Robbery'),
  _ => head,
};
