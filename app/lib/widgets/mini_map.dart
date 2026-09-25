import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../screens/full_map_screen.dart';
import 'map_canvas.dart';

class MiniMap extends StatefulWidget {
  const MiniMap({super.key, required this.locationEnabled});

  final bool locationEnabled;

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> {
  int _reachableInView = 0;

  void _openFullMap(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FullMapScreen(
          locationEnabled: widget.locationEnabled,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          border: Border.all(color: colors.hairline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: MapCanvas(
                locationEnabled: widget.locationEnabled,
                onReachableInViewChanged: (count) => setState(() => _reachableInView = count),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 12,
              child: _OverlayPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.green,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      t('{count} Reachable in view', {
                        'count': _reachableInView,
                      }),
                      style: AppText.chipLabel.copyWith(
                        color: colors.ink70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 12,
              child: GestureDetector(
                onTap: () => _openFullMap(context),
                child: _OverlayPill(
                  child: Text(
                    t('Open map'),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      color: colors.ink70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.mapOverlay,
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}
