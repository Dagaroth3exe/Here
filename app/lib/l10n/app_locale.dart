import 'package:flutter/material.dart';

/// App-wide language override, settable from the Settings screen.
class AppLocale {
  AppLocale._();

  static final ValueNotifier<Locale> current = ValueNotifier(const Locale('en'));

  static const supported = [Locale('en'), Locale('hi'), Locale('es')];

  /// Each language's own name for itself ("endonym"), as language pickers
  /// conventionally show — not translated into whatever locale is active.
  static final nativeNames = {
    Locale('en'): 'English',
    Locale('hi'): 'हिन्दी',
    Locale('es'): 'Español',
  };
}
