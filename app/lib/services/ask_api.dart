import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_api.dart';

/// A real reply from someone on a community forum, quoted as they wrote it.
class CommunityReply {
  const CommunityReply({
    required this.n,
    required this.platform,
    required this.author,
    required this.community,
    required this.text,
    required this.score,
    required this.createdAt,
    required this.url,
    required this.threadTitle,
  });

  final int n;

  /// "reddit" or "stackexchange".
  final String platform;
  final String author;

  /// "r/noida", "Travel Stack Exchange".
  final String community;
  final String text;
  final int score;
  final DateTime createdAt;
  final String url;
  final String threadTitle;

  factory CommunityReply.fromJson(Map<String, dynamic> json) => CommunityReply(
        n: json['n'] as int,
        platform: json['platform'] as String,
        author: json['author'] as String,
        community: json['community'] as String,
        text: json['text'] as String,
        score: json['score'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        url: json['url'] as String,
        threadTitle: json['threadTitle'] as String,
      );
}

class AskPlace {
  const AskPlace({required this.name, required this.kind, required this.distanceM});

  final String name;
  final String kind;
  final int distanceM;

  factory AskPlace.fromJson(Map<String, dynamic> json) => AskPlace(
        name: json['name'] as String,
        kind: json['kind'] as String,
        distanceM: json['distanceM'] as int,
      );
}

enum AskStage { searching, reading, answering }

/// One line of the server's streamed answer, in arrival order.
sealed class AskEvent {
  const AskEvent();
}

class AskStatus extends AskEvent {
  const AskStatus(this.stage);
  final AskStage stage;
}

class AskContext extends AskEvent {
  const AskContext(this.area);
  final String? area;
}

class AskReplies extends AskEvent {
  const AskReplies(this.replies);
  final List<CommunityReply> replies;
}

class AskPlaces extends AskEvent {
  const AskPlaces(this.places);
  final List<AskPlace> places;
}

class AskToken extends AskEvent {
  const AskToken(this.text);
  final String text;
}

class AskDone extends AskEvent {
  const AskDone();
}

class AskFailed extends AskEvent {
  const AskFailed(this.message);
  final String message;
}

/// Talks to the backend's `/ask` endpoint: real replies from community forums
/// (Reddit, Stack Exchange) from people in the same situation, an AI summary
/// of only what they said (streamed as it's written), and nearby places
/// (OpenStreetMap) when the question is about places.
class AskApi {
  AskApi._();

  static String get _baseUrl => Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';

  static Stream<AskEvent> ask(
    String accessToken,
    String question, {
    double? lat,
    double? lng,
    http.Client? client,
  }) async* {
    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/ask'))
        ..headers.addAll({'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'})
        ..body = jsonEncode({'question': question, 'lat': ?lat, 'lng': ?lng});

      late final http.StreamedResponse response;
      try {
        response = await httpClient.send(request).timeout(const Duration(seconds: 15));
      } catch (_) {
        throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
      }
      if (response.statusCode == 429) {
        throw AuthApiException('Still working on your last question.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthApiException('Something went wrong (${response.statusCode})');
      }

      final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final event = _parse(jsonDecode(line) as Map<String, dynamic>);
        if (event != null) yield event;
      }
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static AskEvent? _parse(Map<String, dynamic> json) => switch (json['type']) {
        'status' => AskStatus(AskStage.values.byName(json['stage'] as String)),
        'context' => AskContext(json['area'] as String?),
        'replies' => AskReplies(
            (json['replies'] as List).cast<Map<String, dynamic>>().map(CommunityReply.fromJson).toList(),
          ),
        'places' => AskPlaces((json['places'] as List).cast<Map<String, dynamic>>().map(AskPlace.fromJson).toList()),
        'token' => AskToken(json['text'] as String),
        'done' => const AskDone(),
        'error' => AskFailed(json['message'] as String),
        _ => null,
      };
}
