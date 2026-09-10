import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../design/colors.dart';
import '../services/location_service.dart';

/// OpenFreeMap's "liberty" style — open-source, no API key, no rate limits,
/// full street-level detail (MapLibre's own demo style only draws country
/// outlines, useless at neighborhood zoom). Good enough to run on for now;
/// swap for a self-hosted tile server (TileServer GL + an OpenMapTiles
/// extract) once this needs to be fully self-contained.
const _devStyleUrl = MapLibreStyles.openfreemapLiberty;

class _Dot {
  const _Dot(this.left, this.top);
  final double left;
  final double top;
}

const _nonReachableDots = [
  _Dot(0.20, 0.22),
  _Dot(0.78, 0.30),
  _Dot(0.40, 0.82),
  _Dot(0.63, 0.14),
];

const _reachableDots = [
  _Dot(0.14, 0.64),
  _Dot(0.36, 0.32),
  _Dot(0.57, 0.58),
  _Dot(0.82, 0.70),
  _Dot(0.70, 0.44),
];

/// The abstract street/dot/pulse drawing shared by the mini map card and the
/// full-screen map view. Fills whatever box it's given.
class MapCanvas extends StatefulWidget {
  const MapCanvas({super.key, required this.locationEnabled});

  /// Whether this canvas is allowed to actively query the device's location
  /// right now. Tied to the Reachable toggle — turning Reachable off stops
  /// new location requests; it still shows the map at the last known fix
  /// (if one was already obtained) rather than forgetting it.
  final bool locationEnabled;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  MapLibreMapController? _mapController;
  LatLng? _resolvedCenter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _resolvedCenter = LocationService.cached;
    if (widget.locationEnabled) _resolveLocation();
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locationEnabled && !oldWidget.locationEnabled) _resolveLocation();
  }

  void _resolveLocation() {
    LocationService.resolve().then((center) {
      if (!mounted) return;
      _resolvedCenter = center;
      if (center != LocationService.fallback) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(center));
      }
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    final center = _resolvedCenter;
    if (center != null && center != LocationService.fallback) {
      controller.animateCamera(CameraUpdate.newLatLng(center));
    }
  }

  void _applyMotionPreference() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 0;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotionPreference();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.sand,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pulseSize = (w < h ? w : h) * 0.8;
          return Stack(
            children: [
              // Real map tiles. Static for now (gestures disabled) since the
              // dots below are positioned by fixed percentage, not lat/lng —
              // letting the user pan would visibly detach them from the map.
              Positioned.fill(
                child: IgnorePointer(
                  child: MapLibreMap(
                    styleString: _devStyleUrl,
                    initialCameraPosition: CameraPosition(target: _resolvedCenter ?? LocationService.fallback, zoom: 14),
                    onMapCreated: _onMapCreated,
                    rotateGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    doubleClickZoomEnabled: false,
                    compassEnabled: false,
                    myLocationEnabled: false,
                    attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                  ),
                ),
              ),
              // non-reachable people
              for (final d in _nonReachableDots)
                Positioned(
                  left: w * d.left,
                  top: h * d.top,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.nonReachableDot),
                  ),
                ),
              // reachable people
              for (final d in _reachableDots)
                Positioned(
                  left: w * d.left,
                  top: h * d.top,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.green,
                      boxShadow: [BoxShadow(color: colors.mapHalo, blurRadius: 0, spreadRadius: 3)],
                    ),
                  ),
                ),
              // pulse ring, centered
              Positioned(
                left: w / 2 - pulseSize / 2,
                top: h / 2 - pulseSize / 2,
                width: pulseSize,
                height: pulseSize,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(_controller.value);
                    final scale = 0.5 + t * (2.4 - 0.5);
                    final opacity = 0.55 * (1 - t);
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.green),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // you
              Positioned(
                left: w / 2 - 10,
                top: h / 2 - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.paper),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.ink),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
