import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/safety_api.dart';
import '../widgets/empty_state.dart';

/// Everyone you've blocked, with a way to unblock them.
class BlockedPeopleScreen extends StatefulWidget {
  const BlockedPeopleScreen({super.key});

  @override
  State<BlockedPeopleScreen> createState() => _BlockedPeopleScreenState();
}

class _BlockedPeopleScreenState extends State<BlockedPeopleScreen> {
  List<BlockedPerson>? _blocked;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    setState(() => _failed = false);
    try {
      final blocked = await SafetyApi.blocked(token);
      if (mounted) setState(() => _blocked = blocked);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _unblock(BlockedPerson person) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    try {
      await SafetyApi.unblock(token, person.userId);
      if (mounted) setState(() => _blocked = [...?_blocked]..removeWhere((b) => b.userId == person.userId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Something went wrong. Try again.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final blocked = _blocked;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        title: Text(t('Blocked people'), style: AppText.screenTitle.copyWith(color: colors.ink, fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: blocked == null
            ? Center(
                child: _failed
                    ? TextButton(onPressed: _load, child: Text(t("Couldn't load. Tap to retry.")))
                    : CircularProgressIndicator(strokeWidth: 2, color: colors.green),
              )
            : blocked.isEmpty
                ? HereEmptyState(
                    icon: Icons.block,
                    title: t('No one blocked'),
                    description: t('People you block will show up here.'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                    children: [
                      for (final person in blocked)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(person.name, style: AppText.personName.copyWith(color: colors.ink)),
                              ),
                              TextButton(onPressed: () => _unblock(person), child: Text(t('Unblock'))),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
