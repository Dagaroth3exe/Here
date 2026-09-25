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
  const AskPlace({
    required this.name,
    required this.kind,
    required this.distanceM,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String kind;
  final int distanceM;
  final double lat;
  final double lng;

  factory AskPlace.fromJson(Map<String, dynamic> json) => AskPlace(
        name: json['name'] as String,
        kind: json['kind'] as String,
        distanceM: json['distanceM'] as int,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

/// A question someone asked on HERE before, as everyone sees it: anonymous,
/// with only the area it was asked from.
class PastQuestion {
  const PastQuestion({
    required this.id,
    required this.question,
    required this.area,
    required this.createdAt,
    required this.answerCount,
  });

  final String id;
  final String question;
  final String? area;
  final DateTime createdAt;
  final int answerCount;

  factory PastQuestion.fromJson(Map<String, dynamic> json) => PastQuestion(
        id: json['id'] as String,
        question: json['question'] as String,
        area: json['area'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        answerCount: json['answerCount'] as int,
      );
}

/// A HERE member's answer to a saved question.
class HereAnswer {
  const HereAnswer({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  final String id;
  final String author;
  final String body;
  final DateTime createdAt;
  final bool mine;

  factory HereAnswer.fromJson(Map<String, dynamic> json) => HereAnswer(
        id: json['id'] as String,
        author: json['author'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        mine: json['mine'] as bool,
      );
}

/// A saved question with everything Ask HERE showed for it, plus the
/// community's answers since.
class QuestionDetail {
  const QuestionDetail({
    required this.id,
    required this.question,
    required this.area,
    required this.createdAt,
    required this.mine,
    required this.summary,
    required this.replies,
    required this.places,
    required this.answers,
  });

  final String id;
  final String question;
  final String? area;
  final DateTime createdAt;

  /// Whether the viewer asked it (so they can delete it).
  final bool mine;
  final String summary;
  final List<CommunityReply> replies;
  final AskPlaces? places;
  final List<HereAnswer> answers;

  factory QuestionDetail.fromJson(Map<String, dynamic> json) => QuestionDetail(
        id: json['id'] as String,
        question: json['question'] as String,
        area: json['area'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        mine: json['mine'] as bool,
        summary: json['summary'] as String,
        replies: (json['replies'] as List).cast<Map<String, dynamic>>().map(CommunityReply.fromJson).toList(),
        places: json['places'] == null ? null : AskPlaces.fromJson(json['places'] as Map<String, dynamic>),
        answers: (json['answers'] as List).cast<Map<String, dynamic>>().map(HereAnswer.fromJson).toList(),
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

/// The closest places, all inside [radiusM] — of the person, or of [near]
/// when the question named a place ("in Vaishali").
class AskPlaces extends AskEvent {
  const AskPlaces(this.places, this.radiusM, this.near);
  final List<AskPlace> places;
  final int radiusM;
  final String? near;

  factory AskPlaces.fromJson(Map<String, dynamic> json) => AskPlaces(
        (json['places'] as List).cast<Map<String, dynamic>>().map(AskPlace.fromJson).toList(),
        json['radiusM'] as int,
        json['near'] as String?,
      );
}

/// Questions already asked on HERE nearby that mean nearly the same thing.
class AskSimilar extends AskEvent {
  const AskSimilar(this.questions);
  final List<PastQuestion> questions;
}

/// This question is now saved to the community.
class AskSaved extends AskEvent {
  const AskSaved(this.id);
  final String id;
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

  /// Questions recently asked around here — the community feed.
  static Future<List<PastQuestion>> recent(String accessToken, {double? lat, double? lng}) async {
    final query = lat != null && lng != null ? '?lat=$lat&lng=$lng' : '';
    final json = await _request('GET', '/ask/recent$query', accessToken) as List;
    return json.cast<Map<String, dynamic>>().map(PastQuestion.fromJson).toList();
  }

  static Future<QuestionDetail> question(String accessToken, String id) async =>
      QuestionDetail.fromJson(await _request('GET', '/ask/questions/$id', accessToken) as Map<String, dynamic>);

  static Future<HereAnswer> answer(String accessToken, String questionId, String body) async => HereAnswer.fromJson(
        await _request('POST', '/ask/questions/$questionId/answers', accessToken, {'body': body}) as Map<String, dynamic>,
      );

  static Future<void> deleteQuestion(String accessToken, String id) =>
      _request('DELETE', '/ask/questions/$id', accessToken);

  static Future<Object?> _request(String method, String path, String accessToken, [Object? body]) async {
    late final http.Response response;
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'});
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 10)));
    } catch (_) {
      throw AuthApiException("Couldn't reach the server. Check your connection and try again.");
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthApiException('Something went wrong (${response.statusCode})');
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  static AskEvent? _parse(Map<String, dynamic> json) => switch (json['type']) {
        'status' => AskStatus(AskStage.values.byName(json['stage'] as String)),
        'context' => AskContext(json['area'] as String?),
        'replies' => AskReplies(
            (json['replies'] as List).cast<Map<String, dynamic>>().map(CommunityReply.fromJson).toList(),
          ),
        'places' => AskPlaces.fromJson(json),
        'similar' => AskSimilar(
            (json['questions'] as List).cast<Map<String, dynamic>>().map(PastQuestion.fromJson).toList(),
          ),
        'saved' => AskSaved(json['id'] as String),
        'token' => AskToken(json['text'] as String),
        'done' => const AskDone(),
        'error' => AskFailed(json['message'] as String),
        _ => null,
      };
}
