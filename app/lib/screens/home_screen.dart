import 'dart:async';

import 'package:flutter/material.dart';

import '../data/reachability_categories.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/avatar_controller.dart';
import '../services/profile_api.dart';
import '../services/profile_controller.dart';
import '../services/location_service.dart';
import '../services/realtime_service.dart';
import '../utils/initials.dart';
import '../widgets/avatar_thumb.dart';
import '../widgets/mini_map.dart';
import 'edit_reachability_screen.dart';
import 'profile_screen.dart';

/// Rebuilds [accent] at a fixed saturation/lightness, keeping its hue — lets
/// the Reachable status card's gradient stay just as vivid for any avatar
/// accent color, not only the default purple.
Color _accentShade(Color accent, {required double saturation, required double lightness}) {
  final hue = HSLColor.fromColor(accent).hue;
  return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _reachable = true;
  int _reachableCount = 0;
  StreamSubscription<List<ReachablePerson>>? _peopleSub;
  StreamSubscription<ChatMessage>? _requestSub;
  StreamSubscription<AskAnswerNotice>? _answerSub;

  @override
  void initState() {
    super.initState();
    _peopleSub = RealtimeService.instance.peopleStream.listen((people) {
      setState(() => _reachableCount = people.length);
    });
    // A new chat request (someone's first message) or an answer to your
    // Ask HERE question — worth interrupting for while the app is open.
    _requestSub = RealtimeService.instance.chatStream
        .where((m) => m.pending && m.fromId != AuthSession.userId)
        .listen((request) => _notify(t('{name} sent you a chat request', {'name': request.fromName})));
    _answerSub = RealtimeService.instance.askAnswerStream
        .listen((_) => _notify(t('Someone answered your question on Ask HERE')));
    if (_reachable) _goReachable();
  }

  void _notify(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _goReachable() {
    final token = AuthSession.accessToken;
    if (token == null) return;
    RealtimeService.instance.connect(token);
    // Put yourself on everyone else's map — only with a real fix, never the
    // fallback location.
    LocationService.resolve().then((_) {
      final fix = LocationService.cached;
      if (fix != null && _reachable) RealtimeService.instance.sendLocation(fix.latitude, fix.longitude);
    });
  }

  void _toggle() {
    setState(() => _reachable = !_reachable);
    if (_reachable) {
      _goReachable();
    } else {
      RealtimeService.instance.disconnect();
    }
  }

  @override
  void dispose() {
    _peopleSub?.cancel();
    _requestSub?.cancel();
    _answerSub?.cancel();
    RealtimeService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Header(
            onAvatarTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: _StatusCard(reachable: _reachable, onTap: _toggle),
          ),
          // Everything below the status card goes grey and dull while you're
          // not Reachable, like a dashboard with the power off. Switching
          // back on lights the cards up one at a time, top to bottom.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Row(
              children: [
                Expanded(
                  child: _PoweredDown(
                    off: !_reachable,
                    order: 0,
                    child: _StatCard.plain(value: '64', caption: t('people nearby')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PoweredDown(
                    off: !_reachable,
                    order: 1,
                    child: _StatCard.reachable(value: '$_reachableCount', caption: t('Reachable right now')),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: _PoweredDown(
              off: !_reachable,
              order: 2,
              child: MiniMap(locationEnabled: _reachable),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
            child: _PoweredDown(
              off: !_reachable,
              order: 3,
              child: ValueListenableBuilder<UserProfile?>(
                valueListenable: ProfileController.current,
                builder: (context, profile, _) {
                  return _OpenToSection(
                    categories: profile?.categories ?? const [],
                    onEdit: () => Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const EditReachabilityScreen())),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
            child: _PoweredDown(off: !_reachable, order: 4, child: const _ReputationCard()),
          ),
        ],
      ),
    );
  }
}

/// Fades [child] to a washed-out grey while [off] — the "power's off" look
/// for the dashboard when you're not Reachable. It stays usable; it only
/// looks dormant. The paper-colored scrim on top is what dims the mini map,
/// since the native map view underneath ignores Flutter's color filters.
///
/// Powering down happens all at once. Powering up is staggered by [order]:
/// each card waits its turn, then flickers on like the bulb does.
class _PoweredDown extends StatefulWidget {
  const _PoweredDown({required this.off, required this.order, required this.child});

  final bool off;

  /// Position in the light-up sequence — 0 lights first.
  final int order;
  final Widget child;

  @override
  State<_PoweredDown> createState() => _PoweredDownState();
}

class _PoweredDownState extends State<_PoweredDown> with TickerProviderStateMixin {
  static const _stagger = Duration(milliseconds: 260);
  static const _lightUp = Duration(milliseconds: 650);
  static const _powerDown = Duration(milliseconds: 750);

  /// Lighting up, as a multiple of the dim level it started from: a quick
  /// catch, a stutter back down, then a steady swell to full brightness.
  static final _flicker = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 12),
    TweenSequenceItem(tween: Tween(begin: 0.35, end: 0.8), weight: 10),
    TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 78),
  ]);

  /// Drives powering down; its value is the dim level directly.
  late final AnimationController _dim = AnimationController(vsync: this, value: widget.off ? 1 : 0);

  /// Drives lighting up, 0 → 1 through [_flicker].
  late final AnimationController _light = AnimationController(vsync: this, duration: _lightUp);

  /// Dim level when the current light-up began (it can interrupt a fade).
  double _lightFrom = 1;
  bool _lighting = false;
  Timer? _wait;

  /// Keeps [widget.child]'s state (the mini map's native view included)
  /// when it moves in and out of the filter below, instead of rebuilding it.
  final _childKey = GlobalKey();

  double get _level => _lighting ? _lightFrom * _flicker.transform(_light.value) : _dim.value;

  @override
  void didUpdateWidget(covariant _PoweredDown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.off == oldWidget.off) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final from = _level;
    _wait?.cancel();
    _light.stop();
    setState(() => _lighting = false);
    _dim.value = from;

    if (widget.off) {
      _dim.animateTo(1, duration: reduceMotion ? Duration.zero : _powerDown, curve: Curves.easeInCubic);
    } else if (reduceMotion) {
      _dim.value = 0;
    } else {
      _wait = Timer(_stagger * widget.order, () {
        if (!mounted) return;
        setState(() {
          _lighting = true;
          _lightFrom = from;
        });
        _light.forward(from: 0).whenComplete(() {
          if (!mounted || !_lighting || _light.value < 1) return;
          _dim.value = 0;
          setState(() => _lighting = false);
        });
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _dim.dispose();
    _light.dispose();
    super.dispose();
  }

  /// A saturation matrix: 1 keeps full color, 0 is pure greyscale.
  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final i = 1 - s;
    // dart format off
    return [
      r * i + s, g * i,     b * i,     0, 0,
      r * i,     g * i + s, b * i,     0, 0,
      r * i,     g * i,     b * i + s, 0, 0,
      0,         0,         0,         1, 0,
    ];
    // dart format on
  }

  @override
  Widget build(BuildContext context) {
    final paper = context.colors.paper;
    return AnimatedBuilder(
      animation: Listenable.merge([_dim, _light]),
      child: KeyedSubtree(key: _childKey, child: widget.child),
      builder: (context, child) {
        final dim = _level.clamp(0.0, 1.0);
        // Fully lit (the usual state): no filter or scrim at all. Even an
        // identity ColorFiltered costs an offscreen layer every frame, and
        // over the mini map it'd re-composite the native view each tick.
        if (dim == 0) return child!;
        return Stack(
          // Pass the parent's constraints straight through, so a card in an
          // Expanded still fills its slot instead of shrinking to content.
          fit: StackFit.passthrough,
          children: [
            ColorFiltered(colorFilter: ColorFilter.matrix(_saturation(1 - 0.9 * dim)), child: child),
            Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: paper.withValues(alpha: 0.45 * dim))),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HERE',
                  style: AppText.wordmark.copyWith(
                    color: colors.ink,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: colors.greenInk,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Sector 62, Noida · 800 m radius',
                        maxLines: 2,
                        style: AppText.meta.copyWith(color: colors.ink70),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            key: const Key('profileAvatar'),
            onTap: onAvatarTap,
            child: ValueListenableBuilder<String?>(
              valueListenable: AvatarController.selected,
              builder: (context, avatar, _) {
                return Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.hairlineChip),
                  ),
                  child: avatar != null
                      ? AvatarThumb(source: avatar, size: 46)
                      : Text(
                          initialsFor(AuthSession.name ?? 'You'),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colors.inkMutedAvatar,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The status card and its bulb share one brightness value, driven from
/// here — the card's background only brightens once the bulb has actually
/// finished flickering and swelled up to fully lit, instead of snapping
/// bright the instant you tap while the bulb is still stuttering.
class _StatusCard extends StatefulWidget {
  const _StatusCard({required this.reachable, required this.onTap});

  final bool reachable;
  final VoidCallback onTap;

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> with TickerProviderStateMixin {
  late final AnimationController _brightnessCtrl =
      AnimationController(vsync: this, value: widget.reachable ? 1 : 0);

  int _runId = 0;
  bool _disposed = false;

  // Quick, snapped-value beats — a real tube stuttering before it catches —
  // followed by a slow, eased "dimmer" swell up to fully lit. The card's
  // background follows this exact same curve, so it only reads as "on"
  // once the bulb has actually settled.
  static const _flickerSteps = <(double, Duration)>[
    (0.08, Duration(milliseconds: 40)),
    (0.75, Duration(milliseconds: 55)),
    (0.05, Duration(milliseconds: 60)),
    (0.6, Duration(milliseconds: 45)),
    (0.1, Duration(milliseconds: 100)),
    (0.9, Duration(milliseconds: 60)),
    (0.22, Duration(milliseconds: 90)),
  ];

  Future<void> _playFlickerOn() async {
    final runId = ++_runId;
    _brightnessCtrl.value = 0;
    for (final (value, duration) in _flickerSteps) {
      if (_disposed || runId != _runId) return;
      await _brightnessCtrl.animateTo(value, duration: duration, curve: Curves.linear);
    }
    if (_disposed || runId != _runId) return;
    await _brightnessCtrl.animateTo(1, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant _StatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reachable && !oldWidget.reachable) {
      _playFlickerOn();
    } else if (!widget.reachable && oldWidget.reachable) {
      _runId++;
      _brightnessCtrl.animateTo(0, duration: const Duration(milliseconds: 750), curve: Curves.easeInCubic);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _brightnessCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reachable = widget.reachable;
    return AnimatedBuilder(
      animation: _brightnessCtrl,
      builder: (context, _) {
        final lit = _brightnessCtrl.value.clamp(0.0, 1.0);
        final onColorA = _accentShade(colors.green, saturation: 0.657, lightness: 0.588);
        final onColorB = _accentShade(colors.green, saturation: 0.525, lightness: 0.396);

        return Semantics(
          button: true,
          toggled: reachable,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(colors.surface, onColorA, lit)!,
                    Color.lerp(colors.surface, onColorB, lit)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Color.lerp(colors.hairlineDashed, colors.reachableCardBorder, lit)!,
                ),
                boxShadow: lit > 0.02
                    ? [
                        BoxShadow(
                          color: colors.green.withValues(alpha: 0.20 * lit),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : const [],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The bulb's cord starts right at the card's actual top
                  // border — offset by the negative of the card's own top
                  // padding (26) so it touches the edge instead of starting
                  // 26px inside it — then hangs down behind the status row
                  // to the bulb. A Positioned overlay rather than a normal
                  // flow child, since the wire needs to run that full
                  // height, not just the gap before it.
                  Positioned(
                    top: -26,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: const Alignment(0.45, -1),
                      child: _TubeLight(intensity: lit, glowColor: colors.green),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: reachable
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : colors.sand,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radar_rounded,
                                  size: 15,
                                  color: reachable ? Colors.white : colors.ink70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t('YOUR STATUS'),
                                  style: AppText.statusEyebrow.copyWith(
                                    color: reachable ? Colors.white : colors.ink70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _VerticalSwitch(on: reachable),
                        ],
                      ),
                      const SizedBox(height: 70),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(reachable ? "You're Reachable" : 'Not Reachable'),
                            style: AppText.statusTitle.copyWith(
                              color: reachable ? Colors.white : colors.ink,
                            ),
                          ),
                          const SizedBox(height: 7),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 290),
                            child: Text(
                              t(
                                reachable
                                    ? 'Nearby people can ping you about the topics you chose.'
                                    : 'Tap to let nearby people reach you.',
                              ),
                              style: AppText.statusSubtext.copyWith(
                                color: reachable
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : colors.ink70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A bulb hanging from the very top of the card. Purely a renderer — the
/// `intensity` it's given is the exact same value driving the card's own
/// background (owned by `_StatusCardState`), so the bulb and the card
/// brighten in lockstep rather than as two independently-timed animations
/// that could drift out of sync.
class _TubeLight extends StatelessWidget {
  const _TubeLight({required this.intensity, required this.glowColor});

  final double intensity;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    // Deliberately not wrapped in its own Align — this widget's job is just
    // to report its natural 140x145 size; whoever places it (the Align in
    // _StatusCard) decides where within the card that box actually sits.
    // An Align here would expand to fill all available width and re-center
    // its child, silently overriding that outer positioning.
    return SizedBox(
      height: 145,
      width: 140,
      child: CustomPaint(
        size: const Size(140, 145),
        painter: _BulbPainter(intensity: intensity, glowColor: glowColor),
      ),
    );
  }
}

/// A neon-style filament bulb hanging from a cord that starts at the very
/// top of the card — dark glass and a cold, dormant filament while not
/// Reachable; the glass and halo glow in the app's current accent color
/// once lit, like a colored bulb matching the room, while the filament
/// itself glows a proper warm yellow, like a real incandescent coil.
class _BulbPainter extends CustomPainter {
  _BulbPainter({required this.intensity, required this.glowColor});

  final double intensity;
  final Color glowColor;

  static const _cordTop = 0.0;
  static const _cordBottom = 52.0;
  static const _capHeight = 10.0;
  static const _bulbRadius = 20.0;
  static const _bulbCenterY = _cordBottom + _capHeight + _bulbRadius - 3;

  static const _filamentYellow = Color(0xFFFFD54F);
  static const _coreWarm = Color(0xFFFFF3D6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final glassCenter = Offset(cx, _bulbCenterY);

    // The cord it hangs from — starts at y=0, the card's own top edge.
    final cordPaint = Paint()
      ..color = const Color(0xFF4A4458)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, _cordTop), Offset(cx, _cordBottom), cordPaint);

    // The ambient bloom behind the glass — the room's own accent color,
    // drawn before the glass so it reads as light spilling out. Bigger and
    // brighter than a subtle halo so the bulb reads clearly against the
    // card instead of blending into it.
    if (intensity > 0.02) {
      final outerBloom = Paint()
        ..color = glowColor.withValues(alpha: 0.3 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 28 + 8 * intensity);
      canvas.drawCircle(glassCenter, _bulbRadius + 24, outerBloom);
      final innerBloom = Paint()
        ..color = glowColor.withValues(alpha: 0.5 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 + 4 * intensity);
      canvas.drawCircle(glassCenter, _bulbRadius + 10, innerBloom);
    }

    // The screw base/cap, with a couple of ridge lines like a real socket.
    final capRect = Rect.fromLTWH(cx - 7, _cordBottom, 14, _capHeight);
    final capPaint = Paint()..color = Color.lerp(const Color(0xFF352E40), const Color(0xFF5C5470), intensity)!;
    canvas.drawRRect(
      RRect.fromRectAndCorners(capRect, topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
      capPaint,
    );
    final ridgePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (final t in [0.38, 0.68]) {
      final y = _cordBottom + _capHeight * t;
      canvas.drawLine(Offset(cx - 7, y), Offset(cx + 7, y), ridgePaint);
    }

    // The glass envelope — smoky and dim when off, tinted with the accent
    // color once lit, like colored neon glass catching its own light. A
    // brighter, whiter-edged rim than before so the outline pops against a
    // similarly-colored card rather than melting into it.
    final glassFill = Paint()..color = Color.lerp(const Color(0x38403A4E), glowColor.withValues(alpha: 0.62), intensity)!;
    canvas.drawCircle(glassCenter, _bulbRadius, glassFill);
    final glassBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Color.lerp(const Color(0xFF554A5E), Color.lerp(glowColor, Colors.white, 0.35), intensity)!;
    canvas.drawCircle(glassCenter, _bulbRadius, glassBorder);

    // The zigzag filament — cold gray-brown wire when off, glowing warm
    // yellow with a soft blur once lit, like a real incandescent coil.
    final top = glassCenter.dy - _bulbRadius * 0.5;
    final bottom = glassCenter.dy + _bulbRadius * 0.5;
    const zigzags = 4;
    final stepY = (bottom - top) / zigzags;
    final leftX = cx - _bulbRadius * 0.34;
    final rightX = cx + _bulbRadius * 0.34;
    final filamentPath = Path()..moveTo(cx, top - 2);
    for (var i = 0; i <= zigzags; i++) {
      filamentPath.lineTo(i.isEven ? leftX : rightX, top + stepY * i);
    }
    filamentPath.lineTo(cx, bottom + 2);

    // A soft, wide halo directly along the coil itself, under the sharp
    // wire — makes the filament read as genuinely incandescent rather than
    // just a colored line, especially once fully lit.
    if (intensity > 0.05) {
      final filamentGlow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _filamentYellow.withValues(alpha: 0.55 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 4 * intensity);
      canvas.drawPath(filamentPath, filamentGlow);
    }

    final filamentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(const Color(0xFF6B5F4E), Color.lerp(_filamentYellow, Colors.white, 0.4 * intensity), intensity)!;
    if (intensity > 0.05) {
      filamentPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + 2.5 * intensity);
    }
    canvas.drawPath(filamentPath, filamentPaint);

    if (intensity > 0.05) {
      final core = Paint()
        ..color = _coreWarm.withValues(alpha: 0.85 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(glassCenter, 7 * intensity, core);
    }
  }

  @override
  bool shouldRepaint(covariant _BulbPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.glowColor != glowColor;
}

class _VerticalSwitch extends StatelessWidget {
  const _VerticalSwitch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 52,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: on
            ? Colors.white.withValues(alpha: 0.25)
            : colors.switchTrackOff,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard.plain({required this.value, required this.caption})
    : reachable = false;
  const _StatCard.reachable({required this.value, required this.caption})
    : reachable = true;

  final String value;
  final String caption;
  final bool reachable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: reachable ? colors.reachableStatBorder : colors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reachable
                ? Icons.waving_hand_outlined
                : Icons.people_outline_rounded,
            size: 20,
            color: reachable ? colors.greenInk : colors.ink50,
          ),
          const SizedBox(height: 12),
          if (reachable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.green,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  value,
                  style: AppText.bigNumeral.copyWith(color: colors.ink),
                ),
              ],
            )
          else
            Text(value, style: AppText.bigNumeral.copyWith(color: colors.ink)),
          const SizedBox(height: 3),
          Text(caption, style: AppText.meta.copyWith(color: colors.ink70)),
        ],
      ),
    );
  }
}

class _OpenToSection extends StatelessWidget {
  const _OpenToSection({required this.categories, required this.onEdit});

  final List<String> categories;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t("You're open to"),
              style: AppText.sectionHeader.copyWith(color: colors.ink),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Text(
                t('Edit'),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  color: colors.greenInk,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        if (categories.isEmpty)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.hairlineDashed),
              ),
              child: Text(
                t('Choose what you want to be pinged about'),
                style: AppText.chipLabel.copyWith(
                  color: colors.ink40,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final category in categories)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: category == 'dating' ? colors.datingTint : colors.sand,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: category == 'dating' ? colors.dating.withValues(alpha: 0.4) : colors.hairline,
                    ),
                  ),
                  child: Text(
                    t(labelForCategory(category)),
                    style: AppText.chipLabel.copyWith(
                      color: category == 'dating' ? colors.dating : colors.ink70,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ReputationCard extends StatelessWidget {
  const _ReputationCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Helped 32 people · replies in ~4 min'),
            style: AppText.reputationLine.copyWith(color: colors.ink50),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _Badge(
                text: t('TRUSTED HELPER'),
                color: colors.trust,
                background: colors.trustTint,
              ),
              const SizedBox(width: 8),
              _Badge(
                text: t('LOCAL · 3 YRS'),
                color: colors.inkMutedAvatar,
                background: colors.sand,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: AppText.reputationBadge.copyWith(color: color)),
    );
  }
}
