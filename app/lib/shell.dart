import 'package:flutter/material.dart';
import 'design/colors.dart';
import 'screens/ask_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'services/chat_notifications.dart';
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

  Map<AppTab, Widget> get _screens => {
        AppTab.home: const HomeScreen(),
        AppTab.discover: const DiscoverScreen(),
        AppTab.askHere: const AskScreen(),
        AppTab.chats: ChatListScreen(key: _chatListKey),
      };

  @override
  void initState() {
    super.initState();
    ChatNotifications.instance.start();
    // Signed in by now (at start-up or right after login/signup).
    PushNotifications.enable().then((_) => PushNotifications.openLaunchNotification());
    ProfileController.load();
  }

  void _selectTab(AppTab tab) {
    setState(() {
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
    return Scaffold(
      backgroundColor: context.colors.paper,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: AppTab.values.indexOf(_current),
          children: [
            for (final tab in AppTab.values)
              // Tabs are built on first visit (Discover carries a second live
              // map, no need to pay for it until it's opened), and hidden
              // tabs keep their state but stop animating.
              _visited.contains(tab)
                  ? TickerMode(enabled: tab == _current, child: _screens[tab]!)
                  : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: AppTabBar(
        current: _current,
        onSelect: _selectTab,
      ),
    );
  }
}
