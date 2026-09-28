import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../services/emergency_api.dart';
import '../services/emergency_center.dart';
import '../services/location_service.dart';
import 'chat_thread_screen.dart';

/// Emergency red — deliberately fixed, not a theme color: it must read as an
/// alarm in light, dark, any accent, and even when you're not Reachable.
const emergencyRed = Color(0xFFD32F2F);
const emergencyRedDeep = Color(0xFF8E1616);

String emergencyReasonText(EmergencyReason? reason, String name) => switch (reason) {
  EmergencyReason.harassment => t('{name} is being harassed', {'name': name}),
  EmergencyReason.assault => t('{name} is being assaulted', {'name': name}),
  EmergencyReason.followed => t('{name} is being followed', {'name': name}),
  EmergencyReason.medical => t('{name} has a medical emergency', {'name': name}),
  _ => t('{name} needs immediate help', {'name': name}),
};

/// Full-screen alarm for someone nearby in danger: who, where (live, as they
/// move), what they said, and what you can do — go to them, message them,
/// or call the emergency services.
class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  MapLibreMapController? _map;
  Circle? _marker;

  final center = EmergencyCenter.instance;

  @override
  void initState() {
    super.initState();
    center.incoming.addListener(_follow);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _pulse.stop();
  }

  @override
  void dispose() {
    center.incoming.removeListener(_follow);
    _pulse.dispose();
    super.dispose();
  }

  EmergencyAlert? get _alert => center.incoming.value[widget.alertId];

  /// They moved: move the marker and the camera with them.
  Future<void> _follow() async {
    final alert = _alert;
    final map = _map;
    final marker = _marker;
    if (alert == null || map == null || marker == null) return;
    final at = LatLng(alert.lat, alert.lng);
    await map.updateCircle(marker, CircleOptions(geometry: at));
    await map.animateCamera(CameraUpdate.newLatLng(at));
  }

  Future<void> _onStyleLoaded() async {
    final alert = _alert;
    final map = _map;
    if (alert == null || map == null) return;
    final at = LatLng(alert.lat, alert.lng);
    await map.addCircle(CircleOptions(geometry: at, circleRadius: 22, circleColor: '#D32F2F', circleOpacity: 0.25));
    _marker = await map.addCircle(
      CircleOptions(
        geometry: at,
        circleRadius: 9,
        circleColor: '#D32F2F',
        circleStrokeWidth: 3,
        circleStrokeColor: '#FFFFFF',
      ),
    );
  }

  String? _distance(EmergencyAlert alert) {
    final me = LocationService.cached;
    if (me == null) return null;
    final meters = Geolocator.distanceBetween(me.latitude, me.longitude, alert.lat, alert.lng);
    return meters < 1000
        ? t('{meters} m away', {'meters': (meters / 10).round() * 10})
        : t('{km} km away', {'km': (meters / 1000).toStringAsFixed(1)});
  }

  /// Hands off to whatever maps app the phone has (geo: works with any of
  /// them); OpenStreetMap in the browser if none claims it.
  Future<void> _navigate(EmergencyAlert alert) async {
    final label = Uri.encodeComponent(alert.fromName);
    final geo = Uri.parse('geo:${alert.lat},${alert.lng}?q=${alert.lat},${alert.lng}($label)');
    if (await launchUrl(geo).catchError((_) => false)) return;
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/?mlat=${alert.lat}&mlon=${alert.lng}#map=18/${alert.lat}/${alert.lng}'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _call() => launchUrl(Uri(scheme: 'tel', path: emergencyNumber));

  void _message(EmergencyAlert alert) {
    center.stopSiren();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(otherUserId: alert.fromId, otherName: alert.fromName),
      ),
    );
  }

  bool _confirmFlag = false;
  bool _flagging = false;

  /// "It's a false alarm" — small and last, with a confirmation, since it
  /// counts against them (once someone else says the same).
  Widget _flagControl(EmergencyAlert alert) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: center.flagged,
      builder: (context, flagged, _) {
        if (flagged.contains(alert.id)) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              t('You flagged this as a false alarm.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.white70),
            ),
          );
        }
        if (!_confirmFlag) {
          return TextButton(
            onPressed: () => setState(() => _confirmFlag = true),
            style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size.fromHeight(44)),
            child: Text(t('It’s a false alarm')),
          );
        }
        return Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Only if you know it isn’t real. It counts against them only if someone else alerted says so too.'),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 13.5, height: 1.35, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _flagging ? null : () => setState(() => _confirmFlag = false),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: Text(t('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _flagging ? null : () => _flag(alert),
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: emergencyRedDeep),
                      child: Text(t('Flag it')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _flag(EmergencyAlert alert) async {
    setState(() => _flagging = true);
    try {
      await center.flag(alert.id);
      center.stopSiren();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(t("Couldn't reach the server. Check your connection and try again."))));
      }
    }
    if (mounted) setState(() => _flagging = false);
  }

  void _close() {
    center.stopSiren();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, EmergencyAlert>>(
      valueListenable: center.incoming,
      builder: (context, alerts, _) {
        final alert = alerts[widget.alertId];
        if (alert == null) return const Scaffold(backgroundColor: emergencyRed);
        final resolved = alert.resolved;
        final falseAlarm = alert.falseAlarm;
        return Scaffold(
          backgroundColor: falseAlarm
              ? const Color(0xFF455A64)
              : resolved
              ? const Color(0xFF2E7D32)
              : emergencyRed,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(resolved: resolved, falseAlarm: falseAlarm, pulse: _pulse),
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      falseAlarm
                          ? t('{name}’s alert was a false alarm', {'name': alert.fromName})
                          : resolved
                          ? t('{name} is safe now', {'name': alert.fromName})
                          : emergencyReasonText(alert.reason, alert.fromName),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [if (!resolved) t('They need immediate assistance.'), ?_distance(alert)].join(' · '),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 15, color: Colors.white70),
                  ),
                  if (alert.message != null && !resolved) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '“${alert.message}”',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: MapLibreMap(
                        styleString: MapLibreStyles.openfreemapLiberty,
                        initialCameraPosition: CameraPosition(target: LatLng(alert.lat, alert.lng), zoom: 16),
                        onMapCreated: (controller) => _map = controller,
                        onStyleLoadedCallback: _onStyleLoaded,
                        tiltGesturesEnabled: false,
                        myLocationEnabled: false,
                        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!resolved) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.directions_rounded,
                            label: t('Go to them'),
                            filled: true,
                            onTap: () => _navigate(alert),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.chat_bubble_rounded,
                            label: t('Message'),
                            onTap: () => _message(alert),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ActionButton(
                      icon: Icons.call_rounded,
                      label: t('Call {number}', {'number': emergencyNumber}),
                      onTap: _call,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      if (!resolved)
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: center.sounding,
                            builder: (context, sounding, _) => TextButton.icon(
                              onPressed: sounding ? center.stopSiren : null,
                              icon: Icon(sounding ? Icons.volume_off_rounded : Icons.volume_mute_rounded),
                              label: Text(sounding ? t('Silence siren') : t('Siren silenced')),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white54,
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextButton(
                          onPressed: _close,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(t('Close')),
                        ),
                      ),
                    ],
                  ),
                  if (!falseAlarm) _flagControl(alert),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.resolved, required this.falseAlarm, required this.pulse});

  final bool resolved;
  final bool falseAlarm;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FadeTransition(
          opacity: resolved ? const AlwaysStoppedAnimation(1) : Tween(begin: 0.45, end: 1.0).animate(pulse),
          child: Icon(
            falseAlarm
                ? Icons.do_not_disturb_on_rounded
                : resolved
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          falseAlarm
              ? t('FALSE ALARM')
              : resolved
              ? t('ALL CLEAR')
              : t('EMERGENCY NEARBY'),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.6,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(
                label,
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: emergencyRedDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(
                label,
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }
}
