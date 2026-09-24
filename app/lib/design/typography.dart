import 'package:flutter/material.dart';

/// Text styles for the app. Outfit (clean, warm, highly readable) for
/// body/UI chrome, Baloo 2 (soft, rounded, friendly) for headings and big
/// numerals — matching HERE's human-connection tone. The one exception is
/// [wordmark]: the "HERE" brand mark itself, which uses a pixel-art font to
/// tie directly to the mascot, since it's a logotype rather than UI text.
///
/// None of these carry a color — color is theme-dependent (light/dark), so
/// it's always applied at the call site via `context.colors` (see colors.dart).
class AppText {
  AppText._();

  static const _outfit = 'Outfit';
  static const _baloo = 'Baloo 2';
  static const _pixel = 'Pixelify Sans';

  /// The "HERE" brand wordmark — pixel-art font, variable weight, so the
  /// visual weight (not just the fallback [FontWeight]) is actually
  /// interpolated via [FontVariation] on the flesh-and-blood glyphs.
  static final wordmark = TextStyle(
    fontFamily: _pixel,
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation('wght', 700)],
    fontSize: 23,
    letterSpacing: 0.055 * 23,
    height: 1.0,
  );

  static const screenTitle = TextStyle(
    fontFamily: _baloo,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    height: 1.15,
  );

  static const statusTitle = TextStyle(
    fontFamily: _baloo,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 1.1,
  );

  static const bigNumeral = TextStyle(
    fontFamily: _baloo,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.1,
  );

  static const sectionHeader = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 1.35,
  );

  static const statusEyebrow = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 0.12 * 11,
  );

  static const personName = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  static const personAge = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w400,
    fontSize: 13.5,
  );

  static const statusSubtext = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
  );

  static const chipLabel = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w500,
    fontSize: 12.5,
  );

  static const personTag = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w500,
    fontSize: 12,
  );

  static const reputationLine = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
  );

  static const meta = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w400,
    fontSize: 12,
  );

  static const reputationBadge = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w600,
    fontSize: 11.5,
    letterSpacing: 0.03 * 11.5,
  );

  static const pingButton = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w600,
    fontSize: 13.5,
    letterSpacing: 0.06 * 13.5,
  );

  static const tabLabelInactive = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w500,
    fontSize: 11,
  );

  static const tabLabelActive = TextStyle(
    fontFamily: _outfit,
    fontWeight: FontWeight.w600,
    fontSize: 11,
  );
}
