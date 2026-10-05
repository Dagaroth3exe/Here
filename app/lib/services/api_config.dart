import 'package:flutter/foundation.dart';

/// Where the backend is, in one place.
///
/// * Release builds: pass the real server at build time, e.g.
///   `flutter build appbundle --dart-define=API_BASE_URL=https://api.example.com`.
///   The realtime socket uses the same address (`wss://` for `https://`).
/// * Android emulator: the host machine is reachable at `10.0.2.2`.
/// * iOS simulator / desktop: `localhost`.
/// * Web: the same site that served the page, under `/api` — the dev HTTPS
///   server (tool/web_serve.mjs) passes those requests on to the backend, so
///   a phone's browser needs only the one address, and the page and the API
///   share its HTTPS (browsers only give location to secure pages).
class ApiConfig {
  ApiConfig._();

  static const _configured = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configured.isNotEmpty) return _withoutTrailingSlash(_configured);
    if (kIsWeb) return '${Uri.base.origin}/api';
    return defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  }

  /// The realtime socket, with [query] (e.g. `token=...`).
  static Uri socket(String query) {
    if (_configured.isNotEmpty) {
      final api = Uri.parse(_withoutTrailingSlash(_configured));
      return api.replace(scheme: api.scheme == 'https' ? 'wss' : 'ws', path: '${api.path}/', query: query);
    }
    if (kIsWeb) {
      final scheme = Uri.base.scheme == 'https' ? 'wss' : 'ws';
      return Uri.parse('$scheme://${Uri.base.authority}/api/?$query');
    }
    final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2:3000' : 'localhost:3000';
    return Uri.parse('ws://$host?$query');
  }

  static String _withoutTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
