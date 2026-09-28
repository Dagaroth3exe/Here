import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_api.dart';

/// Why someone raised the alarm. Keys match the backend's EMERGENCY_REASONS.
enum EmergencyReason { harassment, assault, followed, medical, other }

/// An emergency alert — yours, or someone nearby's.
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.lat,
    required this.lng,
    required this.reason,
    required this.message,
    required this.createdAt,
    required this.resolvedAt,
    required this.alerted,
    this.falseAlarm = false,
  });

  final String id;
  final String fromId;
  final String fromName;

  /// Precise (not coarsened like presence) — finding them is the point.
  final double lat;
  final double lng;
  final EmergencyReason? reason;
  final String? message;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// How many people nearby were alerted.
  final int alerted;

  /// It wasn't real — the sender said so, or enough people alerted flagged it.
  final bool falseAlarm;

  bool get resolved => resolvedAt != null;

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) => EmergencyAlert(
    id: json['id'] as String,
    fromId: json['fromId'] as String,
    fromName: json['fromName'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    reason: EmergencyReason.values.asNameMap()[json['reason']],
    message: json['message'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String),
    alerted: json['alerted'] as int? ?? 0,
    falseAlarm: json['falseAlarm'] as bool? ?? false,
  );
}

/// Your false alarms (in the last 90 days) and whether SOS is paused for them.
class SosStanding {
  const SosStanding({required this.falseAlarms, required this.limit, required this.pausedUntil});

  final int falseAlarms;

  /// How many false alarms pause SOS.
  final int limit;
  final DateTime? pausedUntil;

  bool get paused => pausedUntil != null && pausedUntil!.isAfter(DateTime.now());

  factory SosStanding.fromJson(Map<String, dynamic> json) => SosStanding(
    falseAlarms: json['falseAlarms'] as int,
    limit: json['limit'] as int,
    pausedUntil: json['pausedUntil'] == null ? null : DateTime.parse(json['pausedUntil'] as String),
  );
}

/// Talks to the backend's `/emergency` endpoints. Plain HTTP, so raising the
/// alarm works whether or not you're Reachable.
class EmergencyApi {
  EmergencyApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<EmergencyAlert> raise(
    String token, {
    required double lat,
    required double lng,
    EmergencyReason? reason,
    String? message,
  }) async => EmergencyAlert.fromJson(
    await _request('POST', '/emergency', token, {
      'lat': lat,
      'lng': lng,
      if (reason != null) 'reason': reason.name,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    }) as Map<String, dynamic>,
  );

  static Future<void> updateLocation(String token, String id, double lat, double lng) =>
      _request('POST', '/emergency/$id/location', token, {'lat': lat, 'lng': lng});

  /// Ends your alarm; [falseAlarm] says it wasn't real (counts as a strike).
  static Future<void> resolve(String token, String id, {bool falseAlarm = false}) =>
      _request('POST', '/emergency/$id/resolve', token, {'falseAlarm': falseAlarm});

  /// Someone else's alarm you were alerted to wasn't real.
  static Future<void> flag(String token, String id) => _request('POST', '/emergency/$id/flag', token);

  static Future<SosStanding> standing(String token) async =>
      SosStanding.fromJson(await _request('GET', '/emergency/standing', token) as Map<String, dynamic>);

  static Future<EmergencyAlert> get(String token, String id) async =>
      EmergencyAlert.fromJson(await _request('GET', '/emergency/$id', token) as Map<String, dynamic>);

  /// Your own still-open alert, if the app was closed while it was running.
  static Future<EmergencyAlert?> mine(String token) async {
    final json = await _request('GET', '/emergency/mine', token);
    return json == null ? null : EmergencyAlert.fromJson(json as Map<String, dynamic>);
  }

  static Future<Object?> _request(String method, String path, String token, [Object? body]) async {
    late final http.Response response;
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 10)));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
    String? message;
    try {
      final raw = (jsonDecode(response.body) as Map<String, dynamic>)['message'];
      message = raw is List ? raw.join(', ') : raw as String?;
    } catch (_) {}
    throw AuthApiException(message ?? 'Something went wrong (${response.statusCode})');
  }
}
