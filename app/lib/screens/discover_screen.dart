import 'package:flutter/material.dart';
import '../data/seed_people.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../models/person.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _filters = ['All', 'Local questions', 'Tech', 'Travel', 'Study', 'Conversation'];

  String _activeFilter = 'All';
  final Set<String> _pingedIds = {};

  List<Person> get _filteredPeople {
    if (_activeFilter == 'All') return seedPeople;
    final key = _activeFilter.toLowerCase().split(' ').first;
    return seedPeople.where((p) => p.tags.any((t) => t.toLowerCase().contains(key))).toList();
  }

  void _togglePing(String id) {
    setState(() {
      if (_pingedIds.contains(id)) {
        _pingedIds.remove(id);
      } else {
        _pingedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = _filteredPeople;
    final colors = context.colors;

    return ColoredBox(
      color: colors.paper,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('People HERE', style: AppText.screenTitle.copyWith(color: colors.ink)),
                    Text('Sector 62', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: colors.ink45)),
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
                      '17 Reachable within 800 m',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: colors.ink50),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
              children: [
                for (final filter in _filters) ...[
                  _FilterChip(
                    label: filter,
                    active: filter == _activeFilter,
                    onTap: () => setState(() => _activeFilter = filter),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Center(
                      child: Text(
                        'No one Reachable for $_activeFilter within 800 m · try a wider radius',
                        textAlign: TextAlign.center,
                        style: AppText.reputationLine.copyWith(color: colors.ink50),
                      ),
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
                        onPing: () => _togglePing(person.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? colors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? colors.ink : colors.hairlineChip),
        ),
        child: Text(
          label,
          style: AppText.chipLabel.copyWith(color: active ? colors.paper : colors.ink55),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.pinged, required this.onPing});

  final Person person;
  final bool pinged;
  final VoidCallback onPing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.hairline),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(28, 26, 23, 0.03), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: person.avatarTint),
                child: Text(
                  person.initials,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.02 * 14,
                    color: person.avatarInk,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.green),
                        ),
                        const SizedBox(width: 7),
                        Text(person.name, style: AppText.personName.copyWith(color: colors.ink)),
                        const SizedBox(width: 4),
                        Text('${person.age}', style: AppText.personAge.copyWith(color: colors.ink42)),
                        const Spacer(),
                        Text(
                          person.distanceLabel,
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: colors.ink35),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(person.reputationLine, style: AppText.reputationLine.copyWith(color: colors.ink50)),
                    const SizedBox(height: 1),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in person.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(color: colors.sand, borderRadius: BorderRadius.circular(999)),
                            child: Text(tag, style: AppText.personTag.copyWith(color: colors.ink70)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: onPing,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pinged ? colors.sand : colors.green,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pinged ? colors.hairline : colors.green),
              ),
              child: Text(
                pinged ? 'Ping sent' : 'PING',
                style: AppText.pingButton.copyWith(color: pinged ? colors.ink45 : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
