import 'dart:math';
import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../services/auth_session.dart';
import '../shell.dart';
import 'auth/auth_screen.dart';

/// App-open intro: the HERE mascot pops in and waves through a short sprite
/// sequence, then a "Here!" speech bubble appears. On handoff, that bubble
/// text is a [Hero] that flies and grows into the actual "HERE" title on
/// [AuthScreen] as the page transition plays.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // NOTE: `_controller`'s Duration must equal `_totalMs` — `_ms` below derives
  // real elapsed milliseconds as `controller.value * _totalMs`, which only
  // equals true elapsed time when these two agree.
  static const _totalMs = 3200;

  static const _waveFrames = [
    'assets/mascot/mascot_idle.png',
    'assets/mascot/mascot_wave_a.png',
    'assets/mascot/mascot_wave_b.png',
    'assets/mascot/mascot_wave_c.png',
    'assets/mascot/mascot_wave_b.png',
    'assets/mascot/mascot_wave_a.png',
  ];
  static const _waveStartMs = 500.0;
  static const _waveEndMs = 2000.0;

  late final AnimationController _controller;
  bool _navigated = false;
  bool _precached = false;

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
    if (!_precached) {
      _precached = true;
      for (final frame in _waveFrames.toSet()) {
        precacheImage(AssetImage(frame), context);
      }
    }
    if (MediaQuery.of(context).disableAnimations) {
      _onIntroFinished();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  void _onIntroFinished() {
    if (_navigated) return;
    _navigated = true;

    if (AuthSession.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HereShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
      return;
    }

    // A real (non-zero) transition, so the "here-wordmark" Hero actually
    // flies and grows from the bubble here into the title on AuthScreen.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  double get _ms => _controller.value * _totalMs;
  double _phase(double startMs, double endMs) => ((_ms - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

  /// Which sprite frame to show for the current point in the wave cycle.
  String get _currentFrame {
    if (_ms < _waveStartMs || _ms >= _waveEndMs) return _waveFrames.first;
    final segment = (_waveEndMs - _waveStartMs) / _waveFrames.length;
    final index = ((_ms - _waveStartMs) / segment).floor().clamp(0, _waveFrames.length - 1);
    return _waveFrames[index];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Semantics(
          label: 'HERE welcome animation',
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final mascotScale = Curves.easeOutBack.transform(_phase(150, 550)).clamp(0.0, 1.2);
              final bubbleOpacity = _phase(750, 1000);
              final bubbleScale = Curves.easeOutBack.transform(_phase(750, 1150)).clamp(0.0, 1.15);
              final bubbleLift = (1 - _phase(750, 1150)) * 10;

              return Center(
                child: SizedBox(
                  width: 220,
                  height: 260,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 35,
                        child: Opacity(
                          opacity: bubbleOpacity,
                          child: Transform.translate(
                            offset: Offset(0, bubbleLift),
                            child: Transform.scale(
                              scale: bubbleScale,
                              alignment: Alignment.bottomLeft,
                              child: const _PixelBubble(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 90,
                        child: Transform.scale(
                          scale: mascotScale,
                          child: Image.asset(
                            _currentFrame,
                            width: 130,
                            height: 150,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                      ),
                    ],
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

/// A small comic-style speech bubble with squared-off, pixel-ish edges to
/// match the mascot's sprite aesthetic. The text inside is a [Hero] that
/// flies into the real "HERE" title on the next screen.
class _PixelBubble extends StatelessWidget {
  const _PixelBubble();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.ink, width: 2),
          ),
          child: Hero(
            tag: 'here-wordmark',
            child: Material(
              type: MaterialType.transparency,
              child: Text('Here!', style: AppText.wordmark.copyWith(fontSize: 18, color: colors.ink)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Transform.translate(
            offset: const Offset(0, -7),
            child: Transform.rotate(
              angle: pi / 4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: colors.surface, border: Border.all(color: colors.ink, width: 2)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
