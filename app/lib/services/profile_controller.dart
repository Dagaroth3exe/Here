import 'package:flutter/foundation.dart';
import 'auth_session.dart';
import 'profile_api.dart';

/// Holds the current user's reachability categories + interests for the
/// whole app session — same `ValueNotifier` singleton pattern as
/// [ThemeController]/[AppLocale], so Home and the edit screen always agree.
class ProfileController {
  ProfileController._();

  static final ValueNotifier<UserProfile?> current = ValueNotifier(null);

  static Future<void> load() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      current.value = await ProfileApi.getMe(token);
    } catch (_) {
      // Keep whatever was there before (or null) — Home falls back to an
      // empty state rather than surfacing a load error for this.
    }
  }

  static Future<void> update({List<String>? categories, List<String>? interests}) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    current.value = await ProfileApi.updateMe(token, categories: categories, interests: interests);
  }
}
