import 'dart:async';

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/reachability_controller.dart';
import '../services/realtime_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/map_canvas.dart';
import '../widgets/person_card.dart';
import '../widgets/ping_sheet.dart';
import '../widgets/app_tab_bar.dart' show floatingButtonClearance;

/// Live "who's Reachable right now" — sourced entirely from the realtime
/// WebSocket connection (see [RealtimeService]), not sample data. Pinging
/// someone here sends a real message over that socket.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<ReachablePerson> _people = const [];
  StreamSubscription<List<ReachablePerson>>? _peopleSub;

  /// Who the map currently shows; null until its camera first settles, and
  /// until then the list is shown ungrouped.
  Set<String>? _inViewIds;

  /// The person picked on the map or in the list — highlighted in both.
  String? _selectedId;
  final Map<String, GlobalKey> _cardKeys = {};

  /// Keeps the native map alive as [_greyWhenOff] wraps and unwraps it.
  final _mapKey = GlobalKey();

  /// The theme greys everything it draws while you're not Reachable, but the
  /// map's tiles come from the native view — filter those too, and only then,
  /// since a filter over a platform view isn't free.
  Widget _greyWhenOff(Widget map) {
    if (ReachabilityController.on.value) return map;
    // dart format off
    // Greyscale, dimmed to ~82% so the bright tiles sit with the grey page.
    const greyscale = ColorFilter.matrix([
      0.1743, 0.5865, 0.0592, 0, 0,
      0.1743, 0.5865, 0.0592, 0, 0,
      0.1743, 0.5865, 0.0592, 0, 0,
      0,      0,      0,      1, 0,
    ]);
    // dart format on
    return ColorFiltered(colorFilter: greyscale, child: map);
  }

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
    // "Ping sent" also changes from Home's nearest-helper card.
    pingedPeople.addListener(_onPinged);
  }

  void _onPinged() => setState(() {});

  @override
  void dispose() {
    _peopleSub?.cancel();
    pingedPeople.removeListener(_onPinged);
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

  Future<void> _ping(ReachablePerson person) => pingPerson(context, person);

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
                // The app's main map (Home has none): most of the top half of
                // the screen, with the list of people underneath.
                height: (MediaQuery.sizeOf(context).height * 0.42).clamp(240, 440),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: colors.hairline),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _greyWhenOff(
                  KeyedSubtree(
                    key: _mapKey,
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

    final pinged = pingedPeople.value;
    Widget card(ReachablePerson person) => Padding(
      key: _cardKeys.putIfAbsent(person.id, GlobalKey.new),
      padding: const EdgeInsets.only(bottom: 8),
      child: PersonCard(
        person: person,
        pinged: pinged.contains(person.id),
        selected: person.id == _selectedId,
        onTap: () => _selectFromList(person),
        onPing: () => _ping(person),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, floatingButtonClearance),
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
