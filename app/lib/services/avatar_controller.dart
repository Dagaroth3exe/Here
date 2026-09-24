import 'package:flutter/material.dart';
import 'accent_controller.dart';

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

  /// Each preset's own background hue, sampled from the artwork — the basis
  /// for the "app theme matches your avatar" accent recolor. A preset with
  /// no entry here (the grayscale avatar) has no real hue to derive from,
  /// so it's left out and falls back to the default purple.
  static const _accentHues = <String, double>{
    'assets/avatars/avatar_1.png': 143, // green
    'assets/avatars/avatar_2.png': 213, // blue
    'assets/avatars/avatar_3.png': 46, // yellow
    'assets/avatars/avatar_4.png': 0, // maroon
    'assets/avatars/avatar_5.png': 266, // purple
    'assets/avatars/avatar_6.png': 177, // teal
    'assets/avatars/avatar_7.png': 40, // peach
    'assets/avatars/avatar_8.png': 350, // pink
    'assets/avatars/avatar_10.png': 127, // mint
  };

  static final ValueNotifier<String?> selected = ValueNotifier(null);

  /// Sets the avatar and, if it's one of the preset options with a distinct
  /// color, updates [AccentController] to match. A custom uploaded photo
  /// (or a preset with no meaningful hue) resets the app back to its
  /// default purple accent.
  static void select(String source) {
    selected.value = source;
    AccentController.hue.value = _accentHues[source];
  }
}
