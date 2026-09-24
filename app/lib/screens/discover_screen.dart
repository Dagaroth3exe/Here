import 'dart:async';

import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/realtime_service.dart';
import '../utils/initials.dart';
import '../widgets/empty_state.dart';
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

  @override
  void initState() {
    super.initState();
    _peopleSub = RealtimeService.instance.peopleStream.listen((people) {
      setState(() => _people = people);
    });
  }

  @override
  void dispose() {
    _peopleSub?.cancel();
    super.dispose();
  }

  List<ReachablePerson> get _others =>
      _people.where((p) => p.name != AuthSession.name).toList();

  void _ping(ReachablePerson person) {
    RealtimeService.instance.sendPing(person.id);
    setState(() => _pingedIds.add(person.id));
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
                    Text(
                      t('People HERE'),
                      style: AppText.screenTitle.copyWith(color: colors.ink),
                    ),
                    Text(
                      'Sector 62',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: colors.ink45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.green,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      t('{count} Reachable right now', {
                        'count': people.length,
                      }),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12.5,
                        color: colors.ink50,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? HereEmptyState(
                    icon: Icons.explore_outlined,
                    title: t('People HERE'),
                    description: t(
                      'No one else is Reachable right now — check back soon.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 11),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return _PersonCard(
                        person: person,
                        pinged: _pingedIds.contains(person.id),
                        onPing: () => _ping(person),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.pinged,
    required this.onPing,
  });

  final ReachablePerson person;
  final bool pinged;
  final VoidCallback onPing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(28, 26, 23, 0.03),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.sandDeep,
                ),
                child: Text(
                  initialsFor(person.name),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.02 * 14,
                    color: colors.inkMutedAvatar,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.green,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        person.name,
                        style: AppText.personName.copyWith(color: colors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPing,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: pinged ? colors.sand : colors.green,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: pinged ? colors.hairline : colors.green,
                      ),
                    ),
                    child: Text(
                      t(pinged ? 'Ping sent' : 'PING'),
                      style: AppText.pingButton.copyWith(
                        color: pinged ? colors.ink45 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      otherUserId: person.id,
                      otherName: person.name,
                    ),
                  ),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 19,
                    color: colors.ink70,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
