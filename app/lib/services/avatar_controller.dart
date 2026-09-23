import 'package:flutter/material.dart';

/// The available pixel-art avatar options and the current session's pick.
///
/// [selected] holds either one of [options] (an `assets/...` path) or an
/// absolute file path to a photo the user picked from their own library —
/// see [AvatarThumb] for how each is rendered. In-memory only, same as
/// [AuthSession] and [ThemeController] — nothing here persists across an
/// app restart yet.
class AvatarController {
  AvatarController._();

  static final List<String> options = List.generate(10, (i) => 'assets/avatars/avatar_${i + 1}.png');

  static final ValueNotifier<String?> selected = ValueNotifier(null);
}
