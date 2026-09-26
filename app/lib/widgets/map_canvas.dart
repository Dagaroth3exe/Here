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

/// How close the camera gets when flying to a selected person — street level,
/// which is about as precise as the server's ~110 m coarsening allows.
const _focusZoom = 16.5;

/// The glyph set the OpenFreeMap styles ship; MapLibre's default font stack
/// isn't in it, so labels would silently fail to render without this.
const _labelFont = ['Noto Sans Regular'];

/// `#rrggbb` for MapLibre annotation colors, which take CSS strings.
String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// The live map shared by the mini map card and the full-screen map view:
/// real OpenStreetMap tiles, you, and everyone Reachable who has shared a
/// location, each drawn at their actual (server-coarsened) position.
/// Fills whatever box it's given.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.locationEnabled,
    this.interactive = false,
    this.onReachableInViewChanged,
    this.onPeopleInViewChanged,
    this.selectedPersonId,
    this.onPersonSelected,
  });

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

  /// Ids of the other Reachable people inside the visible region, reported
  /// alongside [onReachableInViewChanged].
  final ValueChanged<Set<String>>? onPeopleInViewChanged;

  /// The person to highlight (bigger marker plus a name label). Changing it
  /// flies the camera to them.
  final String? selectedPersonId;

  /// Tapping a marker selects that person; tapping empty map clears the
  /// selection (null). Markers only take taps on an [interactive] map.
  final ValueChanged<String?>? onPersonSelected;

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
    if (widget.selectedPersonId != oldWidget.selectedPersonId) {
      _focusSelected();
      _drawAnnotations();
    }
  }

  ReachablePerson? get _selected {
    final id = widget.selectedPersonId;
    if (id == null) return null;
    for (final p in _others) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _focusSelected() {
    final person = _selected;
    if (person == null) return;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(person.lat!, person.lng!), _focusZoom));
  }

  /// Positions are coarsened server-side, so several people can share one
  /// exact point and only the top marker catches the tap. Repeated taps on
  /// that point cycle through everyone standing there.
  void _onCircleTapped(Circle circle) {
    final id = circle.data?['id'] as String?;
    final callback = widget.onPersonSelected;
    if (id == null || callback == null) return;
    final tapped = _others.firstWhere(
      (p) => p.id == id,
      orElse: () => ReachablePerson(id: id, name: ''),
    );
    final stack = _others.where((p) => p.lat == tapped.lat && p.lng == tapped.lng).toList();
    final current = stack.indexWhere((p) => p.id == widget.selectedPersonId);
    callback(current == -1 ? id : stack[(current + 1) % stack.length].id);
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
    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    final fix = _fix;
    if (fix != null) _mapController?.moveCamera(CameraUpdate.newLatLng(fix));
    _drawAnnotations();
  }

  /// What the markers currently on the map were drawn from.
  String? _drawn;

  Future<void> _drawAnnotations() async {
    final controller = _mapController;
    if (!_styleLoaded || controller == null || !mounted) return;
    final colors = context.colors;

    // People broadcasts often repeat what's already drawn; clearing and
    // re-adding every marker over the platform channel isn't free.
    final drawn = [
      widget.selectedPersonId,
      widget.interactive ? _fix : null,
      colors.green,
      for (final p in _others) '${p.id}@${p.lat},${p.lng}:${p.name}',
    ].join('|');
    if (drawn == _drawn) return _reportInView();
    _drawn = drawn;

    await controller.clearCircles();
    await controller.clearSymbols();
    final selected = _selected;
    // The selected marker is added last so it draws (and takes taps) on top.
    final others = _others.where((p) => p.id != selected?.id).toList();
    if (others.isNotEmpty) {
      await controller.addCircles(
        [
          for (final p in others)
            CircleOptions(
              geometry: LatLng(p.lat!, p.lng!),
              circleRadius: 6,
              circleColor: _hex(colors.green),
              circleStrokeWidth: 3,
              circleStrokeColor: _hex(colors.mapHalo),
              circleStrokeOpacity: colors.mapHalo.a,
            ),
        ],
        [
          for (final p in others) {'id': p.id},
        ],
      );
    }
    if (selected != null) {
      final at = LatLng(selected.lat!, selected.lng!);
      await controller.addCircle(
        CircleOptions(
          geometry: at,
          circleRadius: 9,
          circleColor: _hex(colors.green),
          circleStrokeWidth: 4,
          circleStrokeColor: _hex(colors.paper),
        ),
        {'id': selected.id},
      );
      await controller.addSymbol(
        SymbolOptions(
          geometry: at,
          textField: selected.name,
          fontNames: _labelFont,
          textSize: 13,
          textAnchor: 'bottom',
          textOffset: const Offset(0, -1.1),
          textColor: _hex(colors.ink),
          textHaloColor: _hex(colors.paper),
          textHaloWidth: 2,
        ),
      );
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
    final countCallback = widget.onReachableInViewChanged;
    final peopleCallback = widget.onPeopleInViewChanged;
    if (controller == null || (countCallback == null && peopleCallback == null)) return;
    final bounds = await controller.getVisibleRegion();
    final sw = bounds.southwest;
    final ne = bounds.northeast;
    final inView = {
      for (final p in _others)
        if (p.lat! >= sw.latitude && p.lat! <= ne.latitude && p.lng! >= sw.longitude && p.lng! <= ne.longitude) p.id,
    };
    if (!mounted) return;
    countCallback?.call(inView.length);
    peopleCallback?.call(inView);
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
    _mapController?.onCircleTapped.remove(_onCircleTapped);
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
      onMapClick: widget.onPersonSelected == null ? null : (_, _) => widget.onPersonSelected!(null),
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
                    // Its own repaint boundary, and fading via the fill's
                    // alpha rather than an Opacity layer: the pulse ticks
                    // every frame, and neither should drag the map with it.
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            final t = Curves.easeOut.transform(_controller.value);
                            final scale = 0.5 + t * (2.4 - 0.5);
                            final opacity = (0.55 * (1 - t)).clamp(0.0, 1.0);
                            return Transform.scale(
                              scale: scale,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.green.withValues(alpha: colors.green.a * opacity),
                                ),
                              ),
                            );
                          },
                        ),
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
