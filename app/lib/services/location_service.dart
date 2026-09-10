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

  /// The last successfully resolved fix, if any — read synchronously so a
  /// map that was told to stop actively locating can still show the last
  /// known position instead of jumping back to the fallback.
  static LatLng? get cached => _cached;

  static Future<LatLng> resolve() async {
    if (_cached != null) return _cached!;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return fallback;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return fallback;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 8));
      return _cached = LatLng(position.latitude, position.longitude);
    } catch (_) {
      return fallback;
    }
  }
}
