import 'package:flutter/material.dart';

/// App-wide light/dark/system override, settable from the Settings screen.
/// Defaults to following the system setting, same as before this existed.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);
}
