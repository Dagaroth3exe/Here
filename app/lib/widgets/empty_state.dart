import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// A shared, quiet landing state for screens waiting for their first activity.
class HereEmptyState extends StatelessWidget {
  const HereEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.greenTint,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: colors.reachableStatBorder),
                ),
                child: Icon(icon, size: 36, color: colors.greenInk),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.sectionHeader.copyWith(color: colors.ink),
              ),
              if (description != null) ...[
                const SizedBox(height: 10),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: AppText.reputationLine.copyWith(color: colors.ink70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
