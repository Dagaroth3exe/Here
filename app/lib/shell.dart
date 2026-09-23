import 'package:flutter/material.dart';
import 'design/colors.dart';
import 'l10n/strings.dart';
import 'screens/chat_list_screen.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/app_tab_bar.dart';

class HereShell extends StatefulWidget {
  const HereShell({super.key});

  @override
  State<HereShell> createState() => _HereShellState();
}

class _HereShellState extends State<HereShell> {
  AppTab _current = AppTab.home;

  Map<AppTab, Widget> get _screens => {
        AppTab.home: const HomeScreen(),
        AppTab.discover: const DiscoverScreen(),
        AppTab.askHere: ComingSoonScreen(label: t('Ask HERE')),
        AppTab.chats: const ChatListScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.paper,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: AppTab.values.indexOf(_current),
          children: [for (final tab in AppTab.values) _screens[tab]!],
        ),
      ),
      bottomNavigationBar: AppTabBar(
        current: _current,
        onSelect: (tab) => setState(() => _current = tab),
      ),
    );
  }
}
