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

/// One set of official NCRB figures, with the year before when there is one.
class CrimeFigures {
  const CrimeFigures({
    required this.year,
    required this.total,
    required this.previousYear,
    required this.changePercent,
    required this.sourceTitle,
    required this.sourceUrl,
  });

  final int year;
  final int total;
  final int? previousYear;
  final double? changePercent;
  final String sourceTitle;
  final String sourceUrl;

  static CrimeFigures _fromJson(Map<String, dynamic> json) {
    final previous = json['previous'] as Map<String, dynamic>?;
    final source = json['source'] as Map<String, dynamic>;
    return CrimeFigures(
      year: json['year'] as int,
      total: json['total'] as int,
      previousYear: previous?['year'] as int?,
      changePercent: (json['changePercent'] as num?)?.toDouble(),
      sourceTitle: source['title'] as String,
      sourceUrl: source['url'] as String,
    );
  }
}

/// Official reported-crime figures (NCRB, Crime in India) around a place:
/// its district's (district tables stop at 2022) and, if the district is part
/// of one of NCRB's metropolitan cities, that city's (newest edition).
class AreaCrime {
  const AreaCrime({
    required this.district,
    required this.state,
    required this.districtFigures,
    required this.top,
    required this.city,
    required this.cityFigures,
    required this.ratePerLakh,
    required this.boundaries,
  });

  final String district;
  final String state;
  final CrimeFigures? districtFigures;

  /// The district's most reported crime heads (theft, kidnapping, …), largest first.
  final List<(String, int)> top;
  final String? city;
  final CrimeFigures? cityFigures;

  /// The city's crimes per lakh people, as NCRB published it.
  final double? ratePerLakh;

  /// Attribution for the district boundaries.
  final String boundaries;

  /// The newest of the two — what the Home chip shows.
  CrimeFigures? get newest {
    final c = cityFigures, d = districtFigures;
    if (c == null) return d;
    if (d == null) return c;
    return c.year >= d.year ? c : d;
  }

  factory AreaCrime.fromJson(Map<String, dynamic> json) {
    final district = json['districtFigures'] as Map<String, dynamic>?;
    final city = json['cityFigures'] as Map<String, dynamic>?;
    return AreaCrime(
      district: json['district'] as String,
      state: json['state'] as String,
      districtFigures: district == null ? null : CrimeFigures._fromJson(district),
      top: [
        for (final t in ((district?['top'] as List?) ?? const []).cast<Map<String, dynamic>>())
          (t['head'] as String, t['count'] as int),
      ],
      city: city?['city'] as String?,
      cityFigures: city == null ? null : CrimeFigures._fromJson(city),
      ratePerLakh: (city?['ratePerLakh'] as num?)?.toDouble(),
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

  /// Null when there are no official figures for where this place is.
  static Future<AreaCrime?> areaCrime(String token, double lat, double lng) async {
    final json = await _request('GET', '/crime/district?lat=$lat&lng=$lng', token);
    return json == null ? null : AreaCrime.fromJson(json as Map<String, dynamic>);
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
