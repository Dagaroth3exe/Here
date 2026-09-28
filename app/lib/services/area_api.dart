import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum AreaLevel { quiet, some, several }

/// Recent emergency alerts around a place, from HERE's own (genuine, not
/// false-alarm) alerts. [people] is null when there are too few to say
/// anything — a single alert must never be identifiable.
class AreaSummary {
  const AreaSummary({required this.level, required this.people, required this.windowDays});

  final AreaLevel level;
  final int? people;
  final int windowDays;

  factory AreaSummary.fromJson(Map<String, dynamic> json) => AreaSummary(
    level: AreaLevel.values.asNameMap()[json['level']] ?? AreaLevel.quiet,
    people: json['people'] as int?,
    windowDays: json['windowDays'] as int? ?? 30,
  );
}

/// Official reported-crime figures (NCRB, Crime in India) for the district a
/// place is in. Only for districts the server could match to NCRB's police
/// units with confidence.
class DistrictCrime {
  const DistrictCrime({
    required this.district,
    required this.state,
    required this.year,
    required this.total,
    required this.previousYear,
    required this.previousTotal,
    required this.changePercent,
    required this.top,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.boundaries,
  });

  final String district;
  final String state;
  final int year;
  final int total;
  final int? previousYear;
  final int? previousTotal;
  final double? changePercent;

  /// Crime head key (theft, kidnapping, …) and count, largest first.
  final List<(String, int)> top;
  final String sourceTitle;
  final String sourceUrl;

  /// Attribution for the district boundaries.
  final String boundaries;

  factory DistrictCrime.fromJson(Map<String, dynamic> json) {
    final previous = json['previous'] as Map<String, dynamic>?;
    final source = json['source'] as Map<String, dynamic>;
    return DistrictCrime(
      district: json['district'] as String,
      state: json['state'] as String,
      year: json['year'] as int,
      total: json['total'] as int,
      previousYear: previous?['year'] as int?,
      previousTotal: previous?['total'] as int?,
      changePercent: (json['changePercent'] as num?)?.toDouble(),
      top: [
        for (final t in (json['top'] as List).cast<Map<String, dynamic>>()) (t['head'] as String, t['count'] as int),
      ],
      sourceTitle: source['title'] as String,
      sourceUrl: source['url'] as String,
      boundaries: json['boundaries'] as String,
    );
  }
}

/// Talks to the backend's `/area` endpoints (and `/crime` for official figures).
class AreaApi {
  AreaApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Future<AreaSummary> summary(String token, double lat, double lng) async =>
      AreaSummary.fromJson(await _request('GET', '/area/summary?lat=$lat&lng=$lng', token) as Map<String, dynamic>);

  /// Null when the place isn't in a district with official figures.
  static Future<DistrictCrime?> districtCrime(String token, double lat, double lng) async {
    final json = await _request('GET', '/crime/district?lat=$lat&lng=$lng', token);
    return json == null ? null : DistrictCrime.fromJson(json as Map<String, dynamic>);
  }

  static Future<bool> notices(String token) async =>
      ((await _request('GET', '/area/preferences', token)) as Map<String, dynamic>)['notices'] as bool;

  static Future<void> setNotices(String token, bool on) => _request('PUT', '/area/preferences', token, {'notices': on});

  static Future<Object?> _request(String method, String path, String token, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 10)));
    if (response.statusCode >= 300) throw HttpException('HTTP ${response.statusCode}');
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }
}
