import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/legal.dart';
import '../services/push_notifications.dart';

/// The "prominent disclosure" before the system's location prompt: what HERE
/// uses your location for, who sees it, and when. Returns whether to go on
/// and ask, or null when there's no screen to show it on yet.
Future<bool?> showLocationDisclosure() async {
  final context = PushNotifications.navigatorKey.currentContext;
  if (context == null || !context.mounted) return null;
  final goOn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: context.colors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _LocationDisclosure(),
  );
  return goOn ?? false;
}

class _LocationDisclosure extends StatelessWidget {
  const _LocationDisclosure();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final uses = [
      (
        icon: Icons.people_alt_outlined,
        text: t('While you’re Reachable, people nearby see you on the map, rounded to about 110 m.'),
      ),
      (
        icon: Icons.sos_outlined,
        text: t('If you raise an SOS, people alerted see your exact location until you say you’re safe.'),
      ),
      (
        icon: Icons.shield_outlined,
        text: t('It tells you about recent alerts in your area, and makes Ask HERE answers local.'),
      ),
    ];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.greenTint, shape: BoxShape.circle),
              child: Icon(Icons.location_on_outlined, color: colors.greenInk, size: 28),
            ),
            const SizedBox(height: 16),
            Text(t('HERE uses your location'), style: AppText.sectionHeader.copyWith(color: colors.ink, fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              t('Location is how HERE connects you with people close by. Here’s what it’s used for:'),
              style: AppText.reputationLine.copyWith(color: colors.ink70, height: 1.45),
            ),
            const SizedBox(height: 16),
            for (final use in uses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(use.icon, size: 22, color: colors.greenInk),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(use.text, style: AppText.reputationLine.copyWith(color: colors.ink, height: 1.4)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              t('Only while you’re using the app. Never sold, never used for ads.'),
              style: AppText.meta.copyWith(color: colors.ink50, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: openPrivacyPolicy,
                style: TextButton.styleFrom(foregroundColor: colors.greenInk, padding: EdgeInsets.zero),
                child: Text(t('Read the privacy policy')),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(t('Continue'), style: AppText.pingButton.copyWith(color: Colors.white)),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: colors.ink70, minimumSize: const Size.fromHeight(46)),
              child: Text(t('Not now')),
            ),
          ],
        ),
      ),
    );
  }
}
