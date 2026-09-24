import 'package:flutter/foundation.dart';

/// The current brand-accent hue (0-360), driven by whichever preset avatar
/// is selected — e.g. the green avatar shifts every purple-brand surface
/// (buttons, the Reachable card, chat bubbles) to green instead. `null`
/// means "use the default purple", which is what a custom uploaded photo,
/// a low-saturation preset (nothing distinct to derive a hue from), or no
/// avatar at all falls back to.
class AccentController {
  AccentController._();

  static final ValueNotifier<double?> hue = ValueNotifier(null);
}
