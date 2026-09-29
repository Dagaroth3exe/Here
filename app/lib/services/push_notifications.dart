import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:unifiedpush_platform_interface/data/push_endpoint.dart';
import 'package:unifiedpush_platform_interface/data/push_message.dart';
import 'package:unifiedpush_platform_interface/unifiedpush_platform_interface.dart';

import '../screens/ask_question_screen.dart';
import '../screens/chat_thread_screen.dart';
import '../screens/emergency_screen.dart';
import 'auth_session.dart';
import 'emergency_center.dart';
import 'api_config.dart';

/// The UnifiedPush instance name — one registration per app install.
const _instance = 'default';

/// Phone notifications for chat messages, chat requests, and answers to your
/// Ask HERE questions — over UnifiedPush (open source; the backend relays
/// through a self-hosted ntfy server, encrypted end to end), so there's no
/// Google/Firebase dependency. Needs a UnifiedPush distributor app (e.g.
/// ntfy) on the phone; without one, only in-app alerts work.
class PushNotifications {
  PushNotifications._();

  /// Lets a tapped notification open a screen from outside the widget tree.
  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Whether HERE is on screen — then the live UI already shows new
  /// messages, so no system notification is posted.
  static bool foreground = false;

  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationDetails(
    'here_messages',
    'Messages',
    channelDescription: 'Chat messages, chat requests, and answers to your questions',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Someone nearby is in danger: loudest, most intrusive the phone allows —
  /// the siren as its sound, on the alarm stream (heard in "vibrate only" /
  /// Do Not Disturb setups where media and notifications are muted).
  static final _emergencyChannel = AndroidNotificationDetails(
    'here_emergency',
    'Emergencies nearby',
    channelDescription: 'Someone near you raised the alarm and needs immediate help',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    sound: const RawResourceAndroidNotificationSound('siren'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800, 400, 800]),
    color: const Color(0xFFD32F2F),
    ticker: 'Emergency nearby',
  );
  static PushEndpoint? _endpoint;
  static int _nextId = 0;

  static String get _baseUrl => ApiConfig.baseUrl;

  /// Call first thing in `main`. [background] is true when Android started
  /// the app only to deliver a push (no UI will be shown).
  static Future<void> init({required bool background}) async {
    // Browsers: no system notifications or UnifiedPush — in-app alerts only.
    if (kIsWeb) return;
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (response) => _open(response.payload),
    );
    // The Android implementation directly (not the `unifiedpush` umbrella
    // package, whose Linux support pulls in a native crypto library that
    // breaks the Android build). Android decrypts messages natively.
    await UnifiedPushPlatform.instance.initializeCallback(
      onNewEndpoint: (endpoint, _) {
        _endpoint = endpoint;
        _sendEndpoint();
      },
      onUnregistered: (_) => _endpoint = null,
      onMessage: (message, _) => _show(message),
    );
  }

  /// After sign-in (and at each start while signed in): ask for notification
  /// permission and register with the phone's distributor, if it has one.
  static Future<void> enable() async {
    if (kIsWeb) return;
    try {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final push = UnifiedPushPlatform.instance;
      if (await push.getDistributor() == null) {
        final distributors = await push.getDistributors(const []);
        if (distributors.isEmpty) return;
        await push.saveDistributor(distributors.first);
      }
      await push.register(_instance, const [], null, null);
      if (_endpoint != null) await _sendEndpoint();
    } catch (_) {
      // Push is a bonus; the app works without it.
    }
  }

  /// Before signing out, so this phone stops getting the account's notifications.
  static Future<void> disable() async {
    if (kIsWeb) return;
    final endpoint = _endpoint;
    final token = AuthSession.accessToken;
    if (endpoint != null && token != null) {
      await _post('DELETE', token, {'endpoint': endpoint.url});
    }
    await UnifiedPushPlatform.instance.unregister(_instance).catchError((_) {});
  }

  /// A notification tapped while the app was closed — opened once the UI is up.
  static Future<void> openLaunchNotification() async {
    if (kIsWeb) return;
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _open(launch!.notificationResponse?.payload);
  }

  static Future<void> _sendEndpoint() async {
    final endpoint = _endpoint;
    final token = AuthSession.accessToken;
    if (endpoint == null || token == null) return;
    await _post('POST', token, {
      'endpoint': endpoint.url,
      if (endpoint.pubKeySet != null) 'p256dh': endpoint.pubKeySet!.pubKey,
      if (endpoint.pubKeySet != null) 'auth': endpoint.pubKeySet!.auth,
    });
  }

  /// Best effort: registration is retried at every start, so failures are dropped.
  static Future<void> _post(String method, String token, Map<String, Object> body) async {
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl/push/endpoints'))
        ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
        ..body = jsonEncode(body);
      await request.send().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline or server down — the next start registers again.
    }
  }

  static Future<void> _show(PushMessage message) async {
    if (foreground) return;
    final Map<String, dynamic> notice;
    try {
      notice = jsonDecode(utf8.decode(message.content)) as Map<String, dynamic>;
    } catch (_) {
      return; // Not one of ours (or undecryptable) — nothing sensible to show.
    }
    await _local.show(
      id: _nextId++,
      title: notice['title'] as String?,
      body: notice['body'] as String?,
      notificationDetails: NotificationDetails(
        android: (notice['data'] as Map?)?['kind'] == 'emergency' ? _emergencyChannel : _channel,
      ),
      payload: jsonEncode(notice['data'] ?? const {}),
    );
  }

  /// Opens what a notification is about: the conversation, or your question.
  static void _open(String? payload) {
    final navigator = navigatorKey.currentState;
    if (payload == null || navigator == null || !AuthSession.isLoggedIn) return;
    final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
    switch (data['kind']) {
      case 'message' || 'request':
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ChatThreadScreen(otherUserId: data['userId'] as String, otherName: data['name'] as String? ?? ''),
          ),
        );
      case 'emergency':
        EmergencyCenter.instance.open(data['emergencyId'] as String);
      case 'sos':
        EmergencyCenter.instance.refreshStanding();
        navigator.push(MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()));
      case 'answer':
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => AskQuestionScreen(questionId: data['questionId'] as String)),
        );
    }
  }
}
