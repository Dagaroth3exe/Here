import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../widgets/map_canvas.dart';

const _kMargin = 16.0;
const _kRadius = 24.0;

class FullMapScreen extends StatelessWidget {
  const FullMapScreen({super.key, required this.reachableInView, required this.locationEnabled});

  final int reachableInView;
  final bool locationEnabled;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.paper,
      body: Stack(
        children: [
          Positioned(
            left: _kMargin,
            right: _kMargin,
            top: safe.top + _kMargin,
            bottom: safe.bottom + _kMargin,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kRadius),
              child: Stack(
                children: [
                  Positioned.fill(child: MapCanvas(locationEnabled: locationEnabled)),
                  Positioned(
                    left: 14,
                    top: 12,
                    child: _OverlayPillButton(
                      label: 'Minimize',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 12,
                    child: _OverlayPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: colors.green),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '$reachableInView Reachable in view',
                            style: AppText.chipLabel.copyWith(color: colors.ink70, fontSize: 11.5),
                          ),
                        ],
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

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: context.colors.mapOverlay, borderRadius: BorderRadius.circular(999)),
      child: child,
    );
  }
}

class _OverlayPillButton extends StatelessWidget {
  const _OverlayPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _OverlayPill(
        child: Text(label, style: AppText.chipLabel.copyWith(color: context.colors.ink70, fontSize: 11.5)),
      ),
    );
  }
}
