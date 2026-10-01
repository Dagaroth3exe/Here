import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../screens/chat_thread_screen.dart';
import '../services/realtime_service.dart';
import '../utils/initials.dart';
import 'ping_sheet.dart' show showPingSheet;

/// Someone Reachable, with PING (a ready-made opener, see [showPingSheet])
/// and a button to open the chat. Used on Discover and for the nearest
/// helper on Home.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    required this.pinged,
    required this.selected,
    required this.onTap,
    required this.onPing,
    this.subtitle,
  });

  final ReachablePerson person;
  final bool pinged;

  /// Picked on the map (or by tapping this card) — tinted and outlined.
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPing;

  /// Replaces the location line (e.g. "~350 m away").
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle =
        this.subtitle ??
        (!person.hasLocation
            ? t('Location not shared')
            : selected
            ? t('Shown on map')
            : t('Tap to locate'));
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: selected ? colors.greenTint : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? colors.green : colors.hairline),
        ),
        child: Row(
          children: [
            // Avatar with the Reachable dot tucked into its corner.
            SizedBox.square(
              dimension: 40,
              child: Stack(
                children: [
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: colors.sandDeep),
                    child: Text(
                      initialsFor(person.name),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        letterSpacing: 0.02 * 12.5,
                        color: colors.inkMutedAvatar,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.green,
                        border: Border.all(color: selected ? colors.greenTint : colors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.personName.copyWith(color: colors.ink, fontSize: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (person.hasLocation) ...[
                        Icon(
                          selected ? Icons.location_on : Icons.location_on_outlined,
                          size: 13,
                          color: selected ? colors.green : colors.ink45,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: selected ? colors.green : colors.ink45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onPing,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pinged ? colors.sand : colors.green,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t(pinged ? 'Ping sent' : 'PING'),
                  style: AppText.pingButton.copyWith(fontSize: 12, color: pinged ? colors.ink45 : Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: t('Chat'),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatThreadScreen(otherUserId: person.id, otherName: person.name),
                ),
              ),
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: colors.ink70),
            ),
          ],
        ),
      ),
    );
  }
}
