import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Resolves the device's real location for centering the map, falling back
/// to Sector 62, Noida when permission is denied or a fix can't be had.
/// Cached after the first successful resolve so repeated map mounts (mini
/// card, full-screen view) don't each trigger their own permission prompt.
class LocationService {
  LocationService._();

  static const fallback = LatLng(28.6280, 77.3649);

  static LatLng? _cached;
  static Future<LatLng?>? _pending;

  /// The last successfully resolved fix, if any — read synchronously so a
  /// map that was told to stop actively locating can still show the last
  /// known position instead of jumping back to the fallback.
  static LatLng? get cached => _cached;

  /// The cached fix if there is one, otherwise a fresh one, otherwise
  /// [fallback] — for anything that just needs *somewhere* to center on.
  static Future<LatLng> resolve() async => _cached ?? await _fetch() ?? fallback;

  /// Always asks the device for a fresh fix (the map's locate button), so a
  /// stale cache from when the app opened doesn't pin you in place. Returns
  /// null when location is off, permission is refused, or there's no fix —
  /// never [fallback], so the caller can tell the user instead of silently
  /// showing the wrong place.
  static Future<LatLng?> locate() => _fetch(accuracy: LocationAccuracy.high);

  /// Concurrent callers (Home sharing your location, each mounted map)
  /// share one in-flight request, so the permission prompt shows once.
  static Future<LatLng?> _fetch({LocationAccuracy accuracy = LocationAccuracy.medium}) =>
      _pending ??= _request(accuracy).whenComplete(() => _pending = null);

  static Future<LatLng?> _request(LocationAccuracy accuracy) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: accuracy),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        // No fresh fix in time (indoors, cold GPS) — the OS's last known
        // position is still the device's real whereabouts, unlike [fallback].
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) return null;
      return _cached = LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
