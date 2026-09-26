import 'dart:async';

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/realtime_service.dart';
import '../utils/initials.dart';
import '../widgets/empty_state.dart';
import '../widgets/map_canvas.dart';
import '../widgets/ping_sheet.dart';
import 'chat_thread_screen.dart';

/// Live "who's Reachable right now" — sourced entirely from the realtime
/// WebSocket connection (see [RealtimeService]), not sample data. Pinging
/// someone here sends a real message over that socket.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final Set<String> _pingedIds = {};
  List<ReachablePerson> _people = const [];
  StreamSubscription<List<ReachablePerson>>? _peopleSub;

  /// Who the map currently shows; null until its camera first settles, and
  /// until then the list is shown ungrouped.
  Set<String>? _inViewIds;

  /// The person picked on the map or in the list — highlighted in both.
  String? _selectedId;
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _people = RealtimeService.instance.people;
    _peopleSub = RealtimeService.instance.peopleStream.listen((people) {
      setState(() {
        _people = people;
        if (!people.any((p) => p.id == _selectedId)) _selectedId = null;
      });
    });
  }

  @override
  void dispose() {
    _peopleSub?.cancel();
    super.dispose();
  }

  List<ReachablePerson> get _others => _people.where((p) => p.id != AuthSession.userId).toList();

  /// Tapping a marker: highlight that person's card and scroll it into view.
  void _selectFromMap(String? id) {
    setState(() => _selectedId = id);
    _revealSelected();
  }

  /// Tapping a card: select them, which flies the map to their position.
  void _selectFromList(ReachablePerson person) {
    if (!person.hasLocation) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(t("{name} hasn't shared a location yet.", {'name': person.name}))));
      return;
    }
    setState(() => _selectedId = _selectedId == person.id ? null : person.id);
  }

  void _onPeopleInViewChanged(Set<String> ids) {
    // Reported every time the camera settles, usually with the same people.
    final current = _inViewIds;
    if (current != null && current.length == ids.length && current.containsAll(ids)) return;
    setState(() => _inViewIds = ids);
    // Flying to someone can move their card from "Not in view" up into
    // "On the map" — follow it.
    _revealSelected();
  }

  void _revealSelected() {
    final id = _selectedId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardContext = _cardKeys[id]?.currentContext;
      if (cardContext == null || !cardContext.mounted) return;
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  /// Sends a personalised opener right from Discover. As the first message
  /// it becomes a chat request ("say what you need") they accept or decline.
  Future<void> _ping(ReachablePerson person) async {
    final sent = await showPingSheet(context, person);
    if (!sent || !mounted) return;
    setState(() => _pingedIds.add(person.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Ping sent to {name}', {'name': person.name})),
        action: isDemoPerson(person.id)
            ? null
            : SnackBarAction(
                label: t('Open chat'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(otherUserId: person.id, otherName: person.name),
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = _others;
    final colors = context.colors;

    return ColoredBox(
      color: colors.paper,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t('People HERE'), style: AppText.screenTitle.copyWith(color: colors.ink)),
                    Text(
                      'Sector 62',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: colors.ink45),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.green),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      t('{count} Reachable right now', {'count': people.length}),
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: colors.ink50),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 220,
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: colors.hairline),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: MapCanvas(
                  // Being connected is being Reachable (see RealtimeService),
                  // and the people stream rebuilds this when that changes.
                  locationEnabled: RealtimeService.instance.isConnected,
                  interactive: true,
                  selectedPersonId: _selectedId,
                  onPersonSelected: _selectFromMap,
                  onPeopleInViewChanged: _onPeopleInViewChanged,
                ),
              ),
            ),
          ),
          // The list scrolls beneath this line, never up against the map.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Divider(height: 1, thickness: 1, color: colors.hairlineDashed),
          ),
          Expanded(
            child: people.isEmpty
                ? HereEmptyState(
                    icon: Icons.explore_outlined,
                    title: t('People HERE'),
                    description: t('No one else is Reachable right now — check back soon.'),
                  )
                : _buildList(people),
          ),
        ],
      ),
    );
  }

  /// A plain Column rather than a lazy ListView: selecting someone on the map
  /// scrolls to their card, which needs every card built. Discover only
  /// ever lists who is nearby right now, so the list stays short.
  Widget _buildList(List<ReachablePerson> people) {
    _cardKeys.removeWhere((id, _) => !people.any((p) => p.id == id));
    final inViewIds = _inViewIds;
    final onMap = inViewIds == null ? people : people.where((p) => inViewIds.contains(p.id)).toList();
    final elsewhere = inViewIds == null
        ? const <ReachablePerson>[]
        : people.where((p) => !inViewIds.contains(p.id)).toList();

    Widget card(ReachablePerson person) => Padding(
      key: _cardKeys.putIfAbsent(person.id, GlobalKey.new),
      padding: const EdgeInsets.only(bottom: 8),
      child: _PersonCard(
        person: person,
        pinged: _pingedIds.contains(person.id),
        selected: person.id == _selectedId,
        onTap: () => _selectFromList(person),
        onPing: () => _ping(person),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inViewIds != null && onMap.isNotEmpty) _SectionLabel(t('On the map')),
          ...onMap.map(card),
          if (elsewhere.isNotEmpty) _SectionLabel(t('Not in view')),
          ...elsewhere.map(card),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.08 * 11,
          color: context.colors.ink45,
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.pinged,
    required this.selected,
    required this.onTap,
    required this.onPing,
  });

  final ReachablePerson person;
  final bool pinged;

  /// Picked on the map (or by tapping this card) — tinted and outlined.
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = !person.hasLocation
        ? t('Location not shared')
        : selected
        ? t('Shown on map')
        : t('Tap to locate');
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
