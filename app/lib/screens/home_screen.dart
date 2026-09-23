import 'dart:async';
import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/avatar_controller.dart';
import '../services/realtime_service.dart';
import '../utils/initials.dart';
import '../widgets/avatar_thumb.dart';
import '../widgets/mini_map.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _reachable = true;
  int _reachableCount = 0;
  StreamSubscription<List<ReachablePerson>>? _peopleSub;
  StreamSubscription<IncomingPing>? _pingSub;

  static const _openTopics = ['Local questions', 'Recommendations', 'Tech', 'Conversation'];
  static const _moreTopicsCount = 5;

  @override
  void initState() {
    super.initState();
    _peopleSub = RealtimeService.instance.peopleStream.listen((people) {
      setState(() => _reachableCount = people.length);
    });
    _pingSub = RealtimeService.instance.pingStream.listen((ping) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('{name} pinged you!', {'name': ping.fromName}))),
      );
    });
    if (_reachable) _goReachable();
  }

  void _goReachable() {
    final token = AuthSession.accessToken;
    if (token != null) RealtimeService.instance.connect(token);
  }

  void _toggle() {
    setState(() => _reachable = !_reachable);
    if (_reachable) {
      _goReachable();
    } else {
      RealtimeService.instance.disconnect();
    }
  }

  @override
  void dispose() {
    _peopleSub?.cancel();
    _pingSub?.cancel();
    RealtimeService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.paper,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Header(
            onAvatarTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: _StatusCard(reachable: _reachable, onTap: _toggle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Row(
              children: [
                Expanded(child: _StatCard.plain(value: '64', caption: t('people nearby'))),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard.reachable(value: '$_reachableCount', caption: t('Reachable right now')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: MiniMap(reachableInView: 5, locationEnabled: _reachable),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
            child: _OpenToSection(topics: _openTopics, moreCount: _moreTopicsCount),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 22, 0),
            child: _ReputationCard(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HERE', style: AppText.wordmark.copyWith(color: colors.ink)),
              const SizedBox(height: 1),
              Text('Sector 62, Noida · 800 m radius', style: AppText.meta.copyWith(color: colors.ink45)),
            ],
          ),
          GestureDetector(
            key: const Key('profileAvatar'),
            onTap: onAvatarTap,
            child: ValueListenableBuilder<String?>(
              valueListenable: AvatarController.selected,
              builder: (context, avatar, _) {
                return Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.sandDeep, shape: BoxShape.circle),
                  child: avatar != null
                      ? AvatarThumb(source: avatar, size: 38)
                      : Text(
                          initialsFor(AuthSession.name ?? 'You'),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colors.inkMutedAvatar,
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.reachable, required this.onTap});

  final bool reachable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        decoration: BoxDecoration(
          color: reachable ? colors.greenTint : colors.sand,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: reachable ? colors.reachableCardBorder : colors.hairlineDashed),
          boxShadow: reachable
              ? [const BoxShadow(color: Color.fromRGBO(46, 158, 91, 0.07), blurRadius: 10, offset: Offset(0, 2))]
              : const [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('YOUR STATUS'),
                    style: AppText.statusEyebrow.copyWith(
                      color: reachable ? colors.statusEyebrowOn : colors.ink40,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    t(reachable ? "You're Reachable" : 'Not Reachable'),
                    style: AppText.statusTitle.copyWith(
                      color: reachable ? colors.greenInkDeep : colors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      t(reachable
                          ? 'Nearby people can ping you about the topics you chose.'
                          : 'Tap to let nearby people reach you.'),
                      style: AppText.statusSubtext.copyWith(
                        color: reachable ? colors.statusSubtextOn : colors.ink50,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _VerticalSwitch(on: reachable),
          ],
        ),
      ),
    );
  }
}

class _VerticalSwitch extends StatelessWidget {
  const _VerticalSwitch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 40,
      height: 66,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: on ? colors.greenTrack : colors.switchTrackOff,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: on ? Alignment.topCenter : Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? colors.green : colors.surface,
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.1), blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard.plain({required this.value, required this.caption}) : reachable = false;
  const _StatCard.reachable({required this.value, required this.caption}) : reachable = true;

  final String value;
  final String caption;
  final bool reachable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: reachable ? colors.reachableStatBorder : colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reachable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.green),
                ),
                const SizedBox(width: 7),
                Text(value, style: AppText.bigNumeral.copyWith(color: colors.ink)),
              ],
            )
          else
            Text(value, style: AppText.bigNumeral.copyWith(color: colors.ink)),
          const SizedBox(height: 3),
          Text(caption, style: AppText.meta.copyWith(fontSize: 11.5, color: colors.ink50)),
        ],
      ),
    );
  }
}

class _OpenToSection extends StatelessWidget {
  const _OpenToSection({required this.topics, required this.moreCount});

  final List<String> topics;
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t("You're open to"), style: AppText.sectionHeader.copyWith(color: colors.ink)),
            Text(
              t('Edit'),
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 12.5, color: colors.greenInk),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final topic in topics)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.sand,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.hairline),
                ),
                child: Text(t(topic), style: AppText.chipLabel.copyWith(color: colors.ink70)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.hairlineDashed),
              ),
              child: Text(
                t('+{count} more', {'count': moreCount}),
                style: AppText.chipLabel.copyWith(color: colors.ink40, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReputationCard extends StatelessWidget {
  const _ReputationCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Helped 32 people · replies in ~4 min'), style: AppText.reputationLine.copyWith(color: colors.ink50)),
          const SizedBox(height: 9),
          Row(
            children: [
              _Badge(text: t('TRUSTED HELPER'), color: colors.greenInk, background: colors.greenTintBadge),
              const SizedBox(width: 8),
              _Badge(text: t('LOCAL · 3 YRS'), color: colors.inkMutedAvatar, background: colors.sand),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: AppText.reputationBadge.copyWith(color: color)),
    );
  }
}
