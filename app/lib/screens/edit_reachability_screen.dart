import 'package:flutter/material.dart';
import '../data/reachability_categories.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/profile_controller.dart';
import 'auth/auth_widgets.dart';

/// Lets a user pick what they're currently open to being approached about
/// (gates Pings later) and add free-text interest/expertise tags (shown on
/// their profile) — the two pieces of real per-user data that used to be
/// hardcoded copy on Home.
class EditReachabilityScreen extends StatefulWidget {
  const EditReachabilityScreen({super.key});

  @override
  State<EditReachabilityScreen> createState() => _EditReachabilityScreenState();
}

class _EditReachabilityScreenState extends State<EditReachabilityScreen> {
  late Set<String> _categories;
  late List<String> _interests;
  final _interestController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ProfileController.current.value;
    _categories = {...?profile?.categories};
    _interests = [...?profile?.interests];
  }

  @override
  void dispose() {
    _interestController.dispose();
    super.dispose();
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_categories.contains(key)) {
        _categories.remove(key);
      } else {
        _categories.add(key);
      }
    });
  }

  void _addInterest() {
    final value = _interestController.text.trim();
    if (value.isEmpty || _interests.length >= 10 || _interests.contains(value)) return;
    setState(() {
      _interests.add(value);
      _interestController.clear();
    });
  }

  void _removeInterest(String value) {
    setState(() => _interests.remove(value));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ProfileController.update(categories: _categories.toList(), interests: _interests);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        title: Text(t("You're open to"), style: AppText.screenTitle.copyWith(color: colors.ink, fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                children: [
                  Text(
                    t('Nearby people can ping you about the topics you chose.'),
                    style: AppText.reputationLine.copyWith(color: colors.ink50),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in reachabilityCategories)
                        _CategoryChip(
                          label: t(category.label),
                          selected: _categories.contains(category.key),
                          dating: category.key == 'dating',
                          onTap: () => _toggleCategory(category.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(t('Interests'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
                  const SizedBox(height: 6),
                  Text(
                    t('What can you help with? Add a few tags.'),
                    style: AppText.reputationLine.copyWith(color: colors.ink50),
                  ),
                  const SizedBox(height: 14),
                  if (_interests.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final interest in _interests)
                          _RemovableChip(label: interest, onRemove: () => _removeInterest(interest)),
                      ],
                    ),
                  if (_interests.isNotEmpty) const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.hairline),
                          ),
                          child: TextField(
                            controller: _interestController,
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 14.5, color: colors.ink),
                            decoration: InputDecoration(
                              hintText: t('Add an interest'),
                              hintStyle: AppText.meta.copyWith(color: colors.ink38),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _addInterest(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _addInterest,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: PrimaryAuthButton(label: t('Save'), loading: _saving, onTap: _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dating = false,
  });

  final String label;
  final bool selected;
  final bool dating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = dating ? colors.dating : colors.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : (dating ? colors.datingTint : colors.sand),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : (dating ? accent.withValues(alpha: 0.4) : colors.hairline)),
        ),
        child: Text(
          label,
          style: AppText.chipLabel.copyWith(
            color: selected ? Colors.white : (dating ? colors.dating : colors.ink70),
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: colors.sand,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.chipLabel.copyWith(color: colors.ink70)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 15, color: colors.ink45),
          ),
        ],
      ),
    );
  }
}
