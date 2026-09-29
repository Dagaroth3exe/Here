import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/area_api.dart';
import '../services/auth_session.dart';
import '../services/location_service.dart';

/// Fixed colors — like the SOS red, the heat map must read the same in any
/// theme, accent, or while you're not Reachable.
const heatSome = Color(0xFFF5A623);
const heatSeveral = Color(0xFFE4572E);

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A small live map shading the ~550 m squares where several different
/// people raised genuine emergency alerts in the last 30 days — the same
/// privacy rules as the Home line (never a single alert, nothing from the
/// last hour). Reloads for whatever area you pan or zoom to.
class AlertHeatMap extends StatefulWidget {
  const AlertHeatMap({super.key, this.height = 240});

  final double height;

  @override
  State<AlertHeatMap> createState() => _AlertHeatMapState();
}

class _AlertHeatMapState extends State<AlertHeatMap> {
  MapLibreMapController? _map;
  bool _styleLoaded = false;
  bool _tooWide = false;
  bool _loading = false;
  int _cells = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _map?.onFillTapped.remove(_onFillTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _map = controller;
    controller.onFillTapped.add(_onFillTapped);
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    final fix = LocationService.cached;
    if (fix != null) {
      await _map?.addCircle(
        CircleOptions(
          geometry: fix,
          circleRadius: 6,
          circleColor: '#1E1E1E',
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
      );
    }
    _reload();
  }

  /// Camera settled: fetch the squares for the new view (debounced, since
  /// idle fires in bursts while flinging).
  void _reload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    final map = _map;
    final token = AuthSession.accessToken;
    if (map == null || !_styleLoaded || token == null) return;
    setState(() => _loading = true);
    try {
      final box = await map.getVisibleRegion();
      final result = await AreaApi.heatmap(
        token,
        south: box.southwest.latitude,
        west: box.southwest.longitude,
        north: box.northeast.latitude,
        east: box.northeast.longitude,
      );
      if (!mounted) return;
      await map.clearFills();
      if (result.cells.isNotEmpty) {
        await map.addFills(
          [
            for (final c in result.cells)
              FillOptions(
                geometry: [
                  [
                    LatLng(c.south, c.west),
                    LatLng(c.south, c.east),
                    LatLng(c.north, c.east),
                    LatLng(c.north, c.west),
                    LatLng(c.south, c.west),
                  ],
                ],
                fillColor: _hex(c.level == AreaLevel.several ? heatSeveral : heatSome),
                fillOpacity: c.level == AreaLevel.several ? 0.5 : 0.35,
                fillOutlineColor: _hex(c.level == AreaLevel.several ? heatSeveral : heatSome),
              ),
          ],
          [
            for (final c in result.cells) {'people': c.people},
          ],
        );
      }
      if (mounted) {
        setState(() {
          _tooWide = result.tooWide;
          _cells = result.cells.length;
        });
      }
    } catch (_) {
      // Keep what's drawn; the next pan retries.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onFillTapped(Fill fill) {
    final people = fill.data?['people'] as int?;
    if (people == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(t('{count} people raised alerts in this area in the last 30 days', {'count': people}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapLibreMap(
                    styleString: MapLibreStyles.openfreemapLiberty,
                    initialCameraPosition: CameraPosition(
                      target: LocationService.cached ?? LocationService.fallback,
                      zoom: 13.5,
                    ),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    onCameraIdle: _reload,
                    // Drags on the map pan the map, not the page it sits in.
                    gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    myLocationEnabled: false,
                    attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                  ),
                ),
                if (_tooWide || (!_loading && _cells == 0 && _styleLoaded))
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: colors.mapOverlay, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          _tooWide ? t('Zoom in to see recent alerts') : t('No recent alerts in this area'),
                          style: AppText.meta.copyWith(color: colors.ink70, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _Legend(color: heatSome, label: t('Some alerts (2–3 people)')),
            _Legend(color: heatSeveral, label: t('Several alerts (4+ people)')),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.meta.copyWith(color: context.colors.ink50, fontSize: 11.5)),
      ],
    );
  }
}
