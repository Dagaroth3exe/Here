import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:here_app/screens/auth/auth_screen.dart';
import 'package:here_app/widgets/app_tab_bar.dart';
import 'package:here_app/widgets/empty_state.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Navigation and empty state fit a narrow screen in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppTab? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: const HereEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No conversations yet',
                description: 'Ping someone in Discover to start chatting.',
              ),
              bottomNavigationBar: AppTabBar(
                current: AppTab.home,
                onSelect: (tab) => selected = tab,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Chats'));
        expect(selected, AppTab.chats);
      },
    );
  }

  testWidgets('Auth remains scrollable with a keyboard on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Password'));
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
