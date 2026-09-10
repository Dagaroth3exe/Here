import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';

enum AppTab { home, discover, askHere, chats }

class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  static const _labels = {
    AppTab.home: 'Home',
    AppTab.discover: 'Discover',
    AppTab.askHere: 'Ask HERE',
    AppTab.chats: 'Chats',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 12, 26, 0),
          child: Row(
            children: [
              for (final tab in AppTab.values)
                Expanded(
                  child: _TabItem(
                    label: _labels[tab]!,
                    active: tab == current,
                    onTap: () => onSelect(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? colors.ink : Colors.transparent,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: (active ? AppText.tabLabelActive : AppText.tabLabelInactive)
                  .copyWith(color: active ? colors.ink : colors.ink38),
            ),
          ],
        ),
      ),
    );
  }
}
