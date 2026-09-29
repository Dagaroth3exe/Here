import 'package:flutter/material.dart';

import 'design/colors.dart';
import 'l10n/strings.dart';
import 'screens/ask_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'screens/sos_screen.dart';
import 'services/area_safety.dart';
import 'services/chat_notifications.dart';
import 'services/emergency_center.dart';
import 'services/profile_controller.dart';
import 'services/push_notifications.dart';
import 'widgets/app_tab_bar.dart';

class HereShell extends StatefulWidget {
  const HereShell({super.key});

  @override
  State<HereShell> createState() => _HereShellState();
}

class _HereShellState extends State<HereShell> {
  AppTab _current = AppTab.home;
  final Set<AppTab> _visited = {AppTab.home};
  final _chatListKey = GlobalKey<ChatListScreenState>();

  /// Ask HERE slides up over the current tab from the floating button. Built
  /// on first open and then kept (hidden) so a question still being
  /// answered isn't lost when you close it.
  bool _askOpen = false;
  bool _askBuilt = false;

  void _setAsk(bool open) => setState(() {
    _askOpen = open;
    if (open) _askBuilt = true;
  });

  Map<AppTab, Widget> get _screens => {
    AppTab.home: const HomeScreen(),
    AppTab.discover: const DiscoverScreen(),
    AppTab.sos: const SosScreen(),
    AppTab.chats: ChatListScreen(key: _chatListKey),
  };

  @override
  void initState() {
    super.initState();
    ChatNotifications.instance.start();
    EmergencyCenter.instance.start();
    AreaSafety.instance.start();
    // Signed in by now (at start-up or right after login/signup).
    PushNotifications.enable().then((_) => PushNotifications.openLaunchNotification());
    ProfileController.load();
  }

  void _selectTab(AppTab tab) {
    setState(() {
      _askOpen = false;
      _current = tab;
      _visited.add(tab);
    });
    if (tab == AppTab.chats) {
      ChatNotifications.instance.refresh();
      _chatListKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: context.colors.paper,
      body: PopScope(
        // Back closes Ask HERE rather than leaving the app.
        canPop: !_askOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _askOpen) _setAsk(false);
        },
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              IndexedStack(
                index: AppTab.values.indexOf(_current),
                children: [
                  for (final tab in AppTab.values)
                    // Tabs are built on first visit (Discover carries a second
                    // live map, no need to pay for it until it's opened), and
                    // hidden tabs keep their state but stop animating.
                    _visited.contains(tab)
                        ? TickerMode(enabled: tab == _current && !_askOpen, child: _screens[tab]!)
                        : const SizedBox.shrink(),
                ],
              ),
              if (_askBuilt)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_askOpen,
                    child: AnimatedSlide(
                      offset: _askOpen ? Offset.zero : const Offset(0, 1),
                      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: TickerMode(
                        enabled: _askOpen,
                        child: AskScreen(onClose: () => _setAsk(false)),
                      ),
                    ),
                  ),
                ),
              // Not on Safety: nothing should sit next to the SOS button.
              if (_current != AppTab.sos)
                Positioned(
                  right: 22,
                  bottom: 14,
                  child: AnimatedScale(
                    scale: _askOpen ? 0 : 1,
                    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                    child: _AskButton(onTap: () => _setAsk(true)),
                  ),
                ),
            ],
          ),
        ),
      ),
      // Its own layer: the pill and its soft shadow are painted once, not on
      // every frame something above it animates.
      bottomNavigationBar: RepaintBoundary(
        child: AppTabBar(current: _current, onSelect: _selectTab),
      ),
    );
  }
}

/// The floating "Ask HERE" button, bottom right above the tab bar.
class _AskButton extends StatelessWidget {
  const _AskButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: t('Ask HERE'),
      excludeSemantics: true,
      // Clearly there, but not a bright accent blob: a strong tint of the
      // accent with a thin accent ring, rather than solid colour.
      child: Material(
        color: Color.alphaBlend(colors.green.withValues(alpha: 0.32), colors.surface),
        shape: CircleBorder(side: BorderSide(color: colors.green.withValues(alpha: 0.7), width: 1.5)),
        elevation: 6,
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.auto_awesome_rounded, color: colors.greenInkDeep, size: 26),
          ),
        ),
      ),
    );
  }
}
