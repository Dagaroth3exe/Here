import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';

/// Placeholder for screens not yet designed (Ask HERE, Chats).
/// Intentionally minimal — do not invent a full design for these.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.paper,
      child: Center(
        child: Text(t('{label} · coming soon', {'label': label}), style: AppText.reputationLine.copyWith(color: colors.ink50)),
      ),
    );
  }
}
