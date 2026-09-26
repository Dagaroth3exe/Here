import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'accent_controller.dart';
import 'avatar_controller.dart';
import 'theme_controller.dart';

/// Remembers each account's look — theme mode and avatar (and with it the
/// accent color) — on this device, keyed by user id, so signing back into
/// an account brings its choices back and a different account on the same
/// phone doesn't inherit them.
///
/// Lives next to the session in the same secure storage. Device-local only:
/// the server has no notion of either setting.
class AccountPrefs {
  AccountPrefs._();

  static const _storage = FlutterSecureStorage();

  static String? _userId;

  /// Set while applying stored values, so they aren't written straight back.
  static bool _applying = false;
  static bool _listening = false;

  static String _key(String userId) => 'here_prefs_$userId';

  /// Loads [userId]'s saved look (or the defaults, for an account that never
  /// changed anything) and starts saving further changes under that account.
  static Future<void> load(String userId) async {
    if (!_listening) {
      _listening = true;
      ThemeController.mode.addListener(_save);
      AvatarController.selected.addListener(_save);
    }
    _userId = userId;

    Map<String, dynamic> saved = const {};
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw != null) saved = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Unreadable or corrupt — fall through to the defaults.
    }
    if (_userId != userId) return; // signed into someone else meanwhile

    final avatar = saved['avatar'] as String?;
    // A saved photo can have been removed along with app data.
    final avatarExists = avatar == null || avatar.startsWith('assets/') || await File(avatar).exists();

    _applying = true;
    ThemeController.mode.value = ThemeMode.values.asNameMap()[saved['theme']] ?? ThemeMode.system;
    if (avatar != null && avatarExists) {
      AvatarController.select(avatar);
    } else {
      _resetAvatar();
    }
    _applying = false;
  }

  /// Signed out: stop saving and go back to the default look, so the sign-in
  /// screen (and whoever signs in next) starts clean.
  static void reset() {
    _userId = null;
    _applying = true;
    ThemeController.mode.value = ThemeMode.system;
    _resetAvatar();
    _applying = false;
  }

  static void _resetAvatar() {
    AvatarController.selected.value = null;
    AccentController.hue.value = null;
  }

  static Future<void> _save() async {
    final userId = _userId;
    if (_applying || userId == null) return;
    var avatar = AvatarController.selected.value;
    if (avatar != null && !avatar.startsWith('assets/')) avatar = await _keepPhoto(userId, avatar);
    if (_userId != userId) return;
    await _storage.write(
      key: _key(userId),
      value: jsonEncode({'theme': ThemeController.mode.value.name, 'avatar': avatar}),
    );
  }

  /// Photos from the picker arrive in a cache directory the OS may clear, so
  /// keep a copy in app support storage, one per account.
  static Future<String?> _keepPhoto(String userId, String path) async {
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/avatars');
      if (path.startsWith(dir.path)) return path;
      await dir.create(recursive: true);
      final extension = path.contains('.') ? path.substring(path.lastIndexOf('.')) : '';
      // A fresh name each time, so an old image can't be served from cache.
      final kept = await File(path).copy('${dir.path}/${userId}_${DateTime.now().millisecondsSinceEpoch}$extension');
      await for (final old in dir.list()) {
        if (old.path != kept.path && old.path.split('/').last.startsWith('${userId}_')) await old.delete();
      }
      return kept.path;
    } catch (_) {
      return null; // couldn't keep it; don't save a path that will vanish
    }
  }
}
