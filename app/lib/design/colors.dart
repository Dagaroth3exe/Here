import 'package:flutter/material.dart';

/// Design tokens ported from the HERE design handoff (Home / Discover),
/// with a dark variant added alongside the original light palette.
///
/// Every screen reads colors via `context.colors.xxx` rather than a static
/// constant, so the same token name resolves to the light or dark value
/// depending on the current [Brightness].
///
/// The accent family (`green*`/`reachable*`/`status*OnState) is a light
/// purple palette — the field names are historical (this was originally a
/// green accent) but every value here is purple.
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

  /// Form validation / error messaging — a warm terracotta-red, kept
  /// distinct from the purple accent so errors still stand out.
  final Color error;
  final Color errorTint;

  static const light = AppColors(
    paper: Color(0xFFF7F4FC),
    surface: Color(0xFFFFFFFF),
    sand: Color(0xFFEDE7F6),
    sandDeep: Color(0xFFDDD0F0),
    sandBlock: Color(0xFFE3DAF3),
    ink: Color(0xFF221733),
    ink70: Color(0xFF4A3E63),
    ink55: Color.fromRGBO(34, 23, 51, 0.55),
    ink50: Color.fromRGBO(34, 23, 51, 0.5),
    ink45: Color.fromRGBO(34, 23, 51, 0.45),
    ink42: Color.fromRGBO(34, 23, 51, 0.42),
    ink40: Color.fromRGBO(34, 23, 51, 0.4),
    ink38: Color.fromRGBO(34, 23, 51, 0.38),
    ink35: Color.fromRGBO(34, 23, 51, 0.35),
    inkMutedAvatar: Color(0xFF7A6B94),
    green: Color(0xFF8457E8),
    greenInk: Color(0xFF5A3FA0),
    greenInkDeep: Color(0xFF3E2B73),
    greenTint: Color(0xFFF1EBFB),
    greenTintBadge: Color.fromRGBO(132, 87, 232, 0.1),
    greenTrack: Color.fromRGBO(132, 87, 232, 0.2),
    hairline: Color.fromRGBO(34, 23, 51, 0.07),
    hairlineChip: Color.fromRGBO(34, 23, 51, 0.14),
    hairlineDashed: Color.fromRGBO(34, 23, 51, 0.18),
    reachableCardBorder: Color.fromRGBO(132, 87, 232, 0.28),
    reachableStatBorder: Color.fromRGBO(132, 87, 232, 0.18),
    mapHalo: Color.fromRGBO(247, 244, 252, 0.9),
    mapOverlay: Color.fromRGBO(247, 244, 252, 0.92),
    nonReachableDot: Color.fromRGBO(34, 23, 51, 0.22),
    statusEyebrowOn: Color.fromRGBO(90, 63, 160, 0.7),
    statusSubtextOn: Color.fromRGBO(62, 43, 115, 0.68),
    switchTrackOff: Color.fromRGBO(34, 23, 51, 0.1),
    error: Color(0xFFB54A3C),
    errorTint: Color(0xFFFBEAE7),
  );

  static const dark = AppColors(
    paper: Color(0xFF231B30),
    surface: Color(0xFF2E2340),
    sand: Color(0xFF352844),
    sandDeep: Color(0xFF43324F),
    sandBlock: Color(0xFF3B2C4A),
    ink: Color(0xFFEDEAF5),
    ink70: Color(0xFFC9C2DC),
    ink55: Color.fromRGBO(237, 234, 245, 0.55),
    ink50: Color.fromRGBO(237, 234, 245, 0.5),
    ink45: Color.fromRGBO(237, 234, 245, 0.45),
    ink42: Color.fromRGBO(237, 234, 245, 0.42),
    ink40: Color.fromRGBO(237, 234, 245, 0.4),
    ink38: Color.fromRGBO(237, 234, 245, 0.38),
    ink35: Color.fromRGBO(237, 234, 245, 0.35),
    inkMutedAvatar: Color(0xFFAE9DC7),
    green: Color(0xFF8457E8),
    greenInk: Color(0xFFB8A0FF),
    greenInkDeep: Color(0xFFD8C9FF),
    greenTint: Color(0xFF2E2145),
    greenTintBadge: Color.fromRGBO(184, 160, 255, 0.16),
    greenTrack: Color.fromRGBO(184, 160, 255, 0.30),
    hairline: Color.fromRGBO(237, 234, 245, 0.10),
    hairlineChip: Color.fromRGBO(237, 234, 245, 0.16),
    hairlineDashed: Color.fromRGBO(237, 234, 245, 0.22),
    reachableCardBorder: Color.fromRGBO(184, 160, 255, 0.35),
    reachableStatBorder: Color.fromRGBO(184, 160, 255, 0.24),
    mapHalo: Color.fromRGBO(46, 35, 64, 0.9),
    mapOverlay: Color.fromRGBO(46, 35, 64, 0.92),
    nonReachableDot: Color.fromRGBO(237, 234, 245, 0.28),
    statusEyebrowOn: Color.fromRGBO(184, 160, 255, 0.75),
    statusSubtextOn: Color.fromRGBO(216, 201, 255, 0.62),
    switchTrackOff: Color.fromRGBO(237, 234, 245, 0.12),
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
