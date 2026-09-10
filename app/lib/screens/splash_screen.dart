import 'dart:math';
import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import 'auth/auth_screen.dart';

/// App-open intro: a bear stands far off near the lower-middle of the
/// screen, waves hello, a "HERE!" speech bubble pops up beside it, then
/// [onIntroFinished] (here: navigation to [AuthScreen]) fires after ~3s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _totalMs = 3000;

  /// Waving-arm rotation keyframes in degrees, sampled from the app's
  /// still/anticipation/wave/settle/hold timeline and interpolated with
  /// ease-in-out between each pair so the motion accelerates and decelerates
  /// like a real wave instead of moving at a constant rate.
  static const _armTimesMs = <double>[0, 500, 650, 912, 1175, 1437, 1700, 2600, 3000];
  static const _armDegrees = <double>[5, 5, 25, -25, 30, -20, 20, 5, 5];

  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: _totalMs))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onIntroFinished();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _onIntroFinished();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  void _onIntroFinished() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  double get _elapsedMs => _controller.value * _totalMs;

  /// Local progress (0..1) of the window [startMs, endMs] within the timeline.
  double _phase(double startMs, double endMs) => ((_elapsedMs - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  double _armAngleRadians() {
    final t = _elapsedMs;
    for (var i = 0; i < _armTimesMs.length - 1; i++) {
      final start = _armTimesMs[i];
      final end = _armTimesMs[i + 1];
      if (t <= end || i == _armTimesMs.length - 2) {
        final eased = Curves.easeInOut.transform(_phase(start, end));
        final degrees = _armDegrees[i] + (_armDegrees[i + 1] - _armDegrees[i]) * eased;
        return degrees * pi / 180;
      }
    }
    return _armDegrees.last * pi / 180;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.paper,
      body: Semantics(
        label: 'HERE welcome animation',
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final sceneOpacity = _phase(0, 300);

              final bubbleGrow = Curves.easeOutBack.transform(_phase(1150, 1550));
              final bubbleScale = bubbleGrow.clamp(0.0, 1.15);
              final bubbleOpacity = _phase(1150, 1400);
              final bubbleLift = (1 - _phase(1150, 1550)) * 10;

              return Opacity(
                opacity: sceneOpacity,
                // Kept in the lower-middle of the available height via a
                // fractional alignment (not an absolute pixel offset), so
                // the scene sits in the same relative spot on any screen.
                child: Align(
                  alignment: const Alignment(0, 0.55),
                  child: SizedBox(
                    width: 200,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -30,
                          right: 6,
                          child: Opacity(
                            opacity: bubbleOpacity,
                            child: Transform.translate(
                              offset: Offset(0, bubbleLift),
                              child: Transform.scale(
                                scale: bubbleScale,
                                alignment: Alignment.bottomLeft,
                                child: const ExcludeSemantics(child: SpeechBubble(text: 'HERE!')),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 60,
                          child: ExcludeSemantics(
                            child: BearCharacter(armAngleRadians: _armAngleRadians()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A soft cloud-style speech bubble with a small tail pointing down toward
/// the character below it.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.hairline),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Text(text, style: AppText.wordmark.copyWith(fontSize: 20, color: colors.ink)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: -8),
              decoration: BoxDecoration(color: colors.surface, border: Border.all(color: colors.hairline)),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small, cute, minimal bear: round head, two ears, a small face, a
/// rounded body, two legs, one relaxed arm, and one independently animated
/// waving arm that pivots from the shoulder.
class BearCharacter extends StatelessWidget {
  const BearCharacter({super.key, required this.armAngleRadians});

  final double armAngleRadians;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fur = colors.inkMutedAvatar;
    final furLight = colors.sandDeep;

    return SizedBox(
      width: 130,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // legs
          const Positioned(bottom: 6, left: 32, child: _RoundBar(width: 16, height: 26)),
          const Positioned(bottom: 6, right: 32, child: _RoundBar(width: 16, height: 26)),
          // static (non-waving) arm, relaxed at the side
          Positioned(
            top: 60,
            left: 6,
            child: Transform.rotate(
              angle: -8 * pi / 180,
              alignment: Alignment.topCenter,
              child: _RoundBar(width: 16, height: 44, color: fur),
            ),
          ),
          // body
          Positioned(
            top: 54,
            child: Container(
              width: 86,
              height: 66,
              decoration: BoxDecoration(color: fur, borderRadius: const BorderRadius.all(Radius.circular(34))),
              child: Center(
                child: Container(
                  width: 40,
                  height: 34,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(color: furLight, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
          // waving arm, pivoting at the shoulder (top of the limb) rather
          // than its own center, so it swings like a raised hand.
          Positioned(
            top: 60,
            right: 6,
            child: Transform.rotate(
              angle: armAngleRadians,
              alignment: Alignment.topCenter,
              child: _RoundBar(width: 16, height: 44, color: fur),
            ),
          ),
          // ears
          Positioned(top: 0, left: 16, child: _Circle(size: 22, color: fur)),
          Positioned(top: 0, right: 16, child: _Circle(size: 22, color: fur)),
          // head
          Positioned(
            top: 6,
            child: Container(
              width: 70,
              height: 64,
              decoration: BoxDecoration(color: fur, shape: BoxShape.circle),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: 22, left: 15, child: _Circle(size: 6, color: colors.ink)),
                  Positioned(top: 22, right: 15, child: _Circle(size: 6, color: colors.ink)),
                  Positioned(
                    top: 30,
                    child: Container(
                      width: 28,
                      height: 22,
                      decoration: BoxDecoration(color: furLight, shape: BoxShape.circle),
                      child: Align(
                        alignment: const Alignment(0, 0.35),
                        child: _Circle(size: 6, color: colors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBar extends StatelessWidget {
  const _RoundBar({required this.width, required this.height, this.color});

  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? context.colors.inkMutedAvatar,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
