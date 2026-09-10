import 'package:flutter/material.dart';

/// Design tokens ported from the HERE design handoff (Home / Discover),
/// with a dark variant added alongside the original light palette.
///
/// Every screen reads colors via `context.colors.xxx` rather than a static
/// constant, so the same token name resolves to the light or dark value
/// depending on the current [Brightness].
class AppColors {
  const AppColors({
    required this.paper,
    required this.surface,
    required this.sand,
    required this.sandDeep,
    required this.sandBlock,
    required this.ink,
    required this.ink70,
    required this.ink55,
    required this.ink50,
    required this.ink45,
    required this.ink42,
    required this.ink40,
    required this.ink38,
    required this.ink35,
    required this.inkMutedAvatar,
    required this.green,
    required this.greenInk,
    required this.greenInkDeep,
    required this.greenTint,
    required this.greenTintBadge,
    required this.greenTrack,
    required this.hairline,
    required this.hairlineChip,
    required this.hairlineDashed,
    required this.reachableCardBorder,
    required this.reachableStatBorder,
    required this.mapHalo,
    required this.mapOverlay,
    required this.nonReachableDot,
    required this.statusEyebrowOn,
    required this.statusSubtextOn,
    required this.switchTrackOff,
    required this.error,
    required this.errorTint,
  });

  final Color paper;
  final Color surface;
  final Color sand;
  final Color sandDeep;
  final Color sandBlock;

  final Color ink;
  final Color ink70;
  final Color ink55;
  final Color ink50;
  final Color ink45;
  final Color ink42;
  final Color ink40;
  final Color ink38;
  final Color ink35;
  final Color inkMutedAvatar;

  final Color green;
  final Color greenInk;
  final Color greenInkDeep;
  final Color greenTint;
  final Color greenTintBadge;
  final Color greenTrack;

  final Color hairline;
  final Color hairlineChip;
  final Color hairlineDashed;
  final Color reachableCardBorder;
  final Color reachableStatBorder;

  final Color mapHalo;
  final Color mapOverlay;
  final Color nonReachableDot;

  /// Eyebrow/subtext colors specifically for the Reachable-ON status card,
  /// where the surrounding tint (paper vs. dark) changes what reads well.
  final Color statusEyebrowOn;
  final Color statusSubtextOn;
  final Color switchTrackOff;

  /// Form validation / error messaging — a warm terracotta-red rather than
  /// a harsh pure red, to stay consistent with the app's warm palette.
  final Color error;
  final Color errorTint;

  static const light = AppColors(
    paper: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    sand: Color(0xFFF1EDE4),
    sandDeep: Color(0xFFE7E0D4),
    sandBlock: Color(0xFFEAE4D8),
    ink: Color(0xFF1C1A17),
    ink70: Color(0xFF3D372E),
    ink55: Color.fromRGBO(28, 26, 23, 0.55),
    ink50: Color.fromRGBO(28, 26, 23, 0.5),
    ink45: Color.fromRGBO(28, 26, 23, 0.45),
    ink42: Color.fromRGBO(28, 26, 23, 0.42),
    ink40: Color.fromRGBO(28, 26, 23, 0.4),
    ink38: Color.fromRGBO(28, 26, 23, 0.38),
    ink35: Color.fromRGBO(28, 26, 23, 0.35),
    inkMutedAvatar: Color(0xFF6B6151),
    green: Color(0xFF2E9E5B),
    greenInk: Color(0xFF2E7D4F),
    greenInkDeep: Color(0xFF1E5A38),
    greenTint: Color(0xFFEBF3EC),
    greenTintBadge: Color.fromRGBO(46, 158, 91, 0.1),
    greenTrack: Color.fromRGBO(46, 158, 91, 0.2),
    hairline: Color.fromRGBO(28, 26, 23, 0.07),
    hairlineChip: Color.fromRGBO(28, 26, 23, 0.14),
    hairlineDashed: Color.fromRGBO(28, 26, 23, 0.18),
    reachableCardBorder: Color.fromRGBO(46, 158, 91, 0.28),
    reachableStatBorder: Color.fromRGBO(46, 158, 91, 0.18),
    mapHalo: Color.fromRGBO(250, 247, 242, 0.9),
    mapOverlay: Color.fromRGBO(250, 247, 242, 0.92),
    nonReachableDot: Color.fromRGBO(28, 26, 23, 0.22),
    statusEyebrowOn: Color.fromRGBO(46, 125, 79, 0.7),
    statusSubtextOn: Color.fromRGBO(30, 90, 56, 0.68),
    switchTrackOff: Color.fromRGBO(28, 26, 23, 0.1),
    error: Color(0xFFB54A3C),
    errorTint: Color(0xFFFBEAE7),
  );

  static const dark = AppColors(
    paper: Color(0xFF23292A),
    surface: Color(0xFF2E3536),
    sand: Color(0xFF383F3E),
    sandDeep: Color(0xFF454D4A),
    sandBlock: Color(0xFF3D4543),
    ink: Color(0xFFECEFEC),
    ink70: Color(0xFFC7CDC9),
    ink55: Color.fromRGBO(236, 239, 236, 0.55),
    ink50: Color.fromRGBO(236, 239, 236, 0.5),
    ink45: Color.fromRGBO(236, 239, 236, 0.45),
    ink42: Color.fromRGBO(236, 239, 236, 0.42),
    ink40: Color.fromRGBO(236, 239, 236, 0.4),
    ink38: Color.fromRGBO(236, 239, 236, 0.38),
    ink35: Color.fromRGBO(236, 239, 236, 0.35),
    inkMutedAvatar: Color(0xFFA99C87),
    green: Color(0xFF2E9E5B),
    greenInk: Color(0xFF4ADB98),
    greenInkDeep: Color(0xFF8FF0C2),
    greenTint: Color(0xFF213931),
    greenTintBadge: Color.fromRGBO(60, 197, 133, 0.16),
    greenTrack: Color.fromRGBO(60, 197, 133, 0.30),
    hairline: Color.fromRGBO(236, 239, 236, 0.10),
    hairlineChip: Color.fromRGBO(236, 239, 236, 0.16),
    hairlineDashed: Color.fromRGBO(236, 239, 236, 0.22),
    reachableCardBorder: Color.fromRGBO(60, 197, 133, 0.35),
    reachableStatBorder: Color.fromRGBO(60, 197, 133, 0.24),
    mapHalo: Color.fromRGBO(46, 53, 54, 0.9),
    mapOverlay: Color.fromRGBO(46, 53, 54, 0.92),
    nonReachableDot: Color.fromRGBO(236, 239, 236, 0.28),
    statusEyebrowOn: Color.fromRGBO(90, 224, 166, 0.75),
    statusSubtextOn: Color.fromRGBO(200, 240, 222, 0.62),
    switchTrackOff: Color.fromRGBO(236, 239, 236, 0.12),
    error: Color(0xFFE8877A),
    errorTint: Color(0xFF3A2420),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Ergonomic access: `context.colors.ink` instead of `AppColors.of(context).ink`.
extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}
