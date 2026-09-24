import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/chat_notifications.dart';

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

  static const _icons = {
    AppTab.home: Icons.home_rounded,
    AppTab.discover: Icons.explore_outlined,
    AppTab.askHere: Icons.add_comment_outlined,
    AppTab.chats: Icons.chat_bubble_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ValueListenableBuilder<int>(
            valueListenable: ChatNotifications.instance.unreadCount,
            builder: (context, unreadCount, _) {
              return Row(
                children: [
                  for (final tab in AppTab.values)
                    Expanded(
                      child: _TabItem(
                        icon: _icons[tab]!,
                        label: t(_labels[tab]!),
                        active: tab == current,
                        showBadge: tab == AppTab.chats && unreadCount > 0,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 54,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: active ? colors.greenTint : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: active ? colors.greenInk : colors.ink50,
                ),
              ),
              const SizedBox(height: 5),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style:
                        (active
                                ? AppText.tabLabelActive
                                : AppText.tabLabelInactive)
                            .copyWith(
                              color: active ? colors.greenInk : colors.ink70,
                            ),
                  ),
                  if (showBadge)
                    Positioned(
                      right: -8,
                      top: -2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.error,
                          border: Border.all(color: colors.paper, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
