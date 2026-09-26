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
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final index = AppTab.values.indexOf(current);
    return ColoredBox(
      color: colors.paper,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        // A floating, fully rounded pill (the iOS style). Solid rather than
        // frosted: a backdrop blur would re-render every frame the page
        // scrolls, and this bar should cost next to nothing.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          // Big accessibility text sizes still grow the labels, but capped so
          // four tabs keep fitting side by side in one pill.
          child: MediaQuery(
            data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 1.3)),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.hairlineChip),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 18, offset: Offset(0, 6)),
                ],
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: ChatNotifications.instance.unreadCount,
                builder: (context, unreadCount, _) {
                  // Its own ink layer, so tap ripples draw on the pill rather
                  // than underneath it on the page.
                  return Material(
                    type: MaterialType.transparency,
                    child: Stack(
                      children: [
                        // The selected-tab highlight, gliding between tabs.
                        Positioned.fill(
                          child: AnimatedAlign(
                            alignment: Alignment(-1 + 2 * index / (AppTab.values.length - 1), 0),
                            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: FractionallySizedBox(
                              widthFactor: 1 / AppTab.values.length,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: colors.greenTint,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
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
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
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
    final color = active ? colors.greenInk : colors.ink70;
    return Semantics(
      selected: active,
      button: true,
      label: showBadge ? t('{label}, unread messages', {'label': label}) : label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          // Comfortably above the 48 px minimum touch target.
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 22, color: color),
                    if (showBadge)
                      Positioned(
                        right: -3,
                        top: -2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.error,
                            border: Border.all(color: colors.surface, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: (active ? AppText.tabLabelActive : AppText.tabLabelInactive).copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
