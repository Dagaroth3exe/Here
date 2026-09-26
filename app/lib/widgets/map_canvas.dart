import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../design/colors.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/location_service.dart';
import '../services/realtime_service.dart';

/// OpenFreeMap's "liberty" style — open-source, no API key, no rate limits,
/// full street-level detail (MapLibre's own demo style only draws country
/// outlines, useless at neighborhood zoom). Good enough to run on for now;
/// swap for a self-hosted tile server (TileServer GL + an OpenMapTiles
/// extract) once this needs to be fully self-contained.
const _devStyleUrl = MapLibreStyles.openfreemapLiberty;

const _defaultZoom = 15.0;

/// `#rrggbb` for MapLibre annotation colors, which take CSS strings.
String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The live map shared by the mini map card and the full-screen map view:
/// real OpenStreetMap tiles, you, and everyone Reachable who has shared a
/// location, each drawn at their actual (server-coarsened) position.
/// Fills whatever box it's given.
class MapCanvas extends StatefulWidget {
  const MapCanvas({super.key, required this.locationEnabled, this.interactive = false, this.onReachableInViewChanged});

  /// Whether this canvas is allowed to actively query the device's location
  /// right now. Tied to the Reachable toggle — turning Reachable off stops
  /// new location requests; it still shows the map at the last known fix
  /// (if one was already obtained) rather than forgetting it.
  final bool locationEnabled;

  /// Pan/zoom/rotate plus a recenter button (full-screen map). When false the
  /// map is a static preview centered on you, with the pulse overlay.
  final bool interactive;

  /// How many other Reachable people are inside the visible region —
  /// re-reported whenever the camera settles or the people list changes.
  final ValueChanged<int>? onReachableInViewChanged;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;
  bool _locating = false;
  LatLng? _fix;
  List<ReachablePerson> _people = const [];
  StreamSubscription<List<ReachablePerson>>? _peopleSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
    _fix = LocationService.cached;
    _people = RealtimeService.instance.people;
    _peopleSub = RealtimeService.instance.peopleStream.listen((people) {
      _people = people;
      _drawAnnotations();
    });
    if (widget.locationEnabled) _resolveLocation();
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locationEnabled && !oldWidget.locationEnabled) _resolveLocation();
    if (widget.locationEnabled != oldWidget.locationEnabled) _applyMotionPreference();
  }

  /// Everyone Reachable with a known position, minus yourself (you get your
  /// own marker, drawn from the device fix rather than the coarsened echo).
  Iterable<ReachablePerson> get _others {
    final me = AuthSession.userId;
    return _people.where((p) => p.hasLocation && p.id != me);
  }

  void _resolveLocation() {
    LocationService.resolve().then((_) {
      final fix = LocationService.cached;
      if (!mounted || fix == null) return;
      setState(() => _fix = fix);
      _mapController?.animateCamera(CameraUpdate.newLatLng(fix));
      _drawAnnotations();
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    final fix = _fix;
    if (fix != null) _mapController?.moveCamera(CameraUpdate.newLatLng(fix));
    _drawAnnotations();
  }

  Future<void> _drawAnnotations() async {
    final controller = _mapController;
    if (!_styleLoaded || controller == null || !mounted) return;
    final colors = context.colors;

    await controller.clearCircles();
    final others = _others.toList();
    if (others.isNotEmpty) {
      await controller.addCircles([
        for (final p in others)
          CircleOptions(
            geometry: LatLng(p.lat!, p.lng!),
            circleRadius: 6,
            circleColor: _hex(colors.green),
            circleStrokeWidth: 3,
            circleStrokeColor: _hex(colors.mapHalo),
            circleStrokeOpacity: colors.mapHalo.a,
          ),
      ]);
    }
    // In the static preview the "you" marker is the centered overlay below
    // (so it can pulse); the interactive map needs it pinned to the ground.
    final fix = _fix;
    if (widget.interactive && fix != null) {
      await controller.addCircle(
        CircleOptions(
          geometry: fix,
          circleRadius: 7,
          circleColor: _hex(colors.ink),
          circleStrokeWidth: 3,
          circleStrokeColor: _hex(colors.paper),
        ),
      );
    }
    await _reportInView();
  }

  Future<void> _reportInView() async {
    final controller = _mapController;
    final callback = widget.onReachableInViewChanged;
    if (controller == null || callback == null) return;
    final bounds = await controller.getVisibleRegion();
    final sw = bounds.southwest;
    final ne = bounds.northeast;
    final count = _others
        .where(
          (p) => p.lat! >= sw.latitude && p.lat! <= ne.latitude && p.lng! >= sw.longitude && p.lng! <= ne.longitude,
        )
        .length;
    if (mounted) callback(count);
  }

  /// The locate button: asks for a fresh fix (not the one cached when the
  /// app opened), moves you there, and re-shares it if you're Reachable.
  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final fix = await LocationService.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix != null) _fix = fix;
    });
    if (fix == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(t("Couldn't find your location. Make sure location is on and HERE is allowed to use it.")),
        ),
      );
      return;
    }
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(fix, _defaultZoom));
    _drawAnnotations();
    final realtime = RealtimeService.instance;
    if (realtime.isConnected) realtime.sendLocation(fix.latitude, fix.longitude);
  }

  /// The pulse means "you're broadcasting" — so it's still while you're not
  /// Reachable, and for anyone who asked the system for less motion.
  void _applyMotionPreference() {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || !widget.locationEnabled) {
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
    _peopleSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interactive = widget.interactive;
    final map = MapLibreMap(
      styleString: _devStyleUrl,
      initialCameraPosition: CameraPosition(target: _fix ?? LocationService.fallback, zoom: _defaultZoom),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraIdle: _reportInView,
      rotateGesturesEnabled: interactive,
      scrollGesturesEnabled: interactive,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: interactive,
      doubleClickZoomEnabled: interactive,
      compassEnabled: interactive,
      myLocationEnabled: false,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
    );

    return ColoredBox(
      color: colors.sand,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final pulseSize = (w < h ? w : h) * 0.8;
          return Stack(
            children: [
              Positioned.fill(child: interactive ? map : IgnorePointer(child: map)),
              // The static preview is always centered on you, so the pulse
              // and "you" dot can sit at the widget's center. Only shown
              // once there's a real fix — never at the fallback location.
              if (!interactive && _fix != null) ...[
                if (widget.locationEnabled)
                  Positioned(
                    left: w / 2 - pulseSize / 2,
                    top: h / 2 - pulseSize / 2,
                    width: pulseSize,
                    height: pulseSize,
                    child: IgnorePointer(
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
                  ),
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
              if (interactive)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Material(
                    color: colors.paper,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: IconButton(
                      tooltip: t('Show my location'),
                      icon: _locating
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink),
                            )
                          : Icon(_fix != null ? Icons.my_location : Icons.location_searching, color: colors.ink),
                      onPressed: _locate,
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
