import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:here_app/main.dart';
import 'package:here_app/screens/auth/auth_screen.dart';
import 'package:here_app/screens/splash_screen.dart';
import 'package:here_app/services/auth_api.dart';
import 'package:here_app/services/auth_session.dart';
import 'package:here_app/services/avatar_controller.dart';
import 'package:here_app/services/realtime_service.dart';
import 'package:here_app/shell.dart';
import 'package:here_app/widgets/avatar_thumb.dart';

/// Pulls the `sub` (user id) claim out of a JWT without verifying it — fine
/// for a test that already trusts the server that issued the token.
String _decodeJwtSub(String token) {
  final payloadSegment = token.split('.')[1];
  final normalized = base64Url.normalize(payloadSegment);
  final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
  return payload['sub'] as String;
}

/// Polls [condition] with a real (not simulated) delay between checks —
/// `tester.pump(duration)` only advances animation clocks, it doesn't
/// guarantee that much real wall-clock time actually elapses, which is what
/// a genuine network round-trip (signup, WebSocket messages) needs.
Future<bool> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 60,
  Duration interval = const Duration(milliseconds: 250),
}) async {
  for (var i = 0; i < attempts && !condition(); i++) {
    await Future<void>.delayed(interval);
    await tester.pump();
  }
  return condition();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash intro slides up to reveal the auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HereApp());
    await tester.pump(); // first frame: splash visible
    expect(find.byType(SplashScreen), findsOneWidget);

    // The splash's own AnimationController drives a fixed-length (3200ms)
    // intro, then a real page transition (550ms, with the "here-wordmark"
    // Hero flying into the title) hands off to AuthScreen.
    for (var i = 0; i < 28; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.byType(SplashScreen), findsNothing);
    // "Log in" is ambiguous once the auth screen is up (it's both the
    // mode-toggle segment and the submit button) — the tagline is unique.
    expect(find.text('Someone HERE can help.'), findsOneWidget);
  });

  testWidgets('Sign up with name+password reaches the app, backed by the real server', (WidgetTester tester) async {
    // Pumps AuthScreen directly rather than through the splash animation —
    // this test is about the signup flow, not the intro.
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    // Only the mode-toggle segment says "Sign up" until the form switches.
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    final name = 'itest-${DateTime.now().millisecondsSinceEpoch}';
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), 'a-strong-test-password');

    // Now both the toggle and the submit button say "Sign up" — target the
    // button specifically by widget type.
    await tester.tap(find.widgetWithText(GestureDetector, 'Sign up').last);
    // Bounded polling with real delays, not pumpAndSettle — the shell's map
    // has a looping animation that would never let settle finish, and a
    // fixed pump count can't guarantee the real signup round-trip finished.
    expect(
      await _pumpUntil(tester, () => find.text("You're Reachable").evaluate().isNotEmpty),
      isTrue,
      reason: 'signup should reach the shell within the poll window',
    );

    // Avatar → Profile → Log out should drop back to the auth screen.
    await tester.tap(find.byKey(const Key('profileAvatar')));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('Home shows Reachable status, and toggling it disconnects the realtime socket', (WidgetTester tester) async {
    final name = 'itest-home-${DateTime.now().millisecondsSinceEpoch}';
    AuthSession.set(name, await AuthApi.signupWithPassword(name, 'a-strong-test-password'));

    // Pumps the shell directly rather than the full app — this test is about
    // the core Home behavior, not the auth gate in front of it.
    await tester.pumpWidget(const MaterialApp(home: HereShell()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('HERE'), findsOneWidget);
    expect(find.text("You're Reachable"), findsOneWidget);
    expect(RealtimeService.instance.isConnected, isTrue);

    await tester.tap(find.text("You're Reachable"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not Reachable'), findsOneWidget);
    expect(RealtimeService.instance.isConnected, isFalse);
  });

  testWidgets('Realtime: two accounts see each other in Discover and can ping', (WidgetTester tester) async {
    // Backed by the real server and a real second WebSocket connection
    // (standing in for a second phone) — not mocked.
    final selfName = 'itest-self-${DateTime.now().millisecondsSinceEpoch}';
    final friendName = 'itest-friend-${DateTime.now().millisecondsSinceEpoch}';
    const password = 'a-strong-test-password';

    final selfToken = await AuthApi.signupWithPassword(selfName, password);
    final friendToken = await AuthApi.signupWithPassword(friendName, password);
    AuthSession.set(selfName, selfToken);

    await tester.pumpWidget(const MaterialApp(home: HereShell()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("You're Reachable"), findsOneWidget);

    // Bring a "friend" online via a raw WebSocket, simulating a second phone.
    final friendChannel = WebSocketChannel.connect(Uri.parse('ws://10.0.2.2:3000?token=$friendToken'));
    final friendPing = Completer<Map<String, dynamic>>();
    friendChannel.stream.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['event'] == 'ping' && !friendPing.isCompleted) {
        friendPing.complete(message);
      }
    });

    // Wait for the friend to show up in Discover via the live presence list.
    await tester.tap(find.text('Discover'));
    await tester.pump();
    expect(
      await _pumpUntil(tester, () => find.text(friendName).evaluate().isNotEmpty),
      isTrue,
      reason: 'friend should appear in Discover via the realtime presence list',
    );

    // Ping the friend from the UI — their raw socket should receive it.
    await tester.tap(find.widgetWithText(GestureDetector, 'PING').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ping sent'), findsOneWidget);

    final receivedPing = await friendPing.future.timeout(const Duration(seconds: 5));
    expect((receivedPing['data'] as Map)['fromName'], selfName);

    // Friend pings back — should surface as a SnackBar, visible from any tab.
    await tester.tap(find.text('Home'));
    await tester.pump();
    final selfId = _decodeJwtSub(selfToken);
    friendChannel.sink.add(jsonEncode({
      'event': 'ping',
      'data': {'targetId': selfId},
    }));
    expect(
      await _pumpUntil(tester, () => find.textContaining('pinged you').evaluate().isNotEmpty),
      isTrue,
      reason: 'incoming ping should show a SnackBar on Home',
    );

    await friendChannel.sink.close();
  });

  testWidgets('Settings: switching appearance actually changes the app theme', (WidgetTester tester) async {
    // Goes through the real HereApp (splash → signup → shell) rather than
    // pumping HereShell directly — the theme-mode wiring under test lives
    // in HereApp's MaterialApp, which a bare MaterialApp-in-test wouldn't have.
    await tester.pumpWidget(const HereApp());
    await tester.pump();
    for (var i = 0; i < 28; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    final name = 'itest-settings-${DateTime.now().millisecondsSinceEpoch}';
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), 'a-strong-test-password');
    await tester.tap(find.widgetWithText(GestureDetector, 'Sign up').last);
    expect(
      await _pumpUntil(tester, () => find.text("You're Reachable").evaluate().isNotEmpty),
      isTrue,
      reason: 'signup should reach the shell within the poll window',
    );

    await tester.tap(find.byKey(const Key('profileAvatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(Theme.of(tester.element(find.text('Settings'))).brightness, Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(Theme.of(tester.element(find.text('Settings'))).brightness, Brightness.light);
  });

  testWidgets('Settings: switching language actually translates the UI', (WidgetTester tester) async {
    await tester.pumpWidget(const HereApp());
    await tester.pump();
    for (var i = 0; i < 28; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    final name = 'itest-lang-${DateTime.now().millisecondsSinceEpoch}';
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), 'a-strong-test-password');
    await tester.tap(find.widgetWithText(GestureDetector, 'Sign up').last);
    expect(
      await _pumpUntil(tester, () => find.text("You're Reachable").evaluate().isNotEmpty),
      isTrue,
      reason: 'signup should reach the shell within the poll window',
    );

    await tester.tap(find.byKey(const Key('profileAvatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Switching to Hindi should retranslate the Settings screen itself —
    // it's rebuilt from the top (HereApp's MaterialApp) on every locale
    // change, so the currently-visible screen updates immediately too.
    await tester.tap(find.text('हिन्दी'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('दिखावट'), findsOneWidget, reason: '"Appearance" should read as Hindi');
    expect(find.text('भाषा'), findsOneWidget, reason: '"Language" should read as Hindi');

    await tester.tap(find.text('Español'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Apariencia'), findsOneWidget, reason: '"Appearance" should read as Spanish');
    expect(find.text('Idioma'), findsOneWidget, reason: '"Language" should read as Spanish');

    // Leave the global locale clean for any tests that might run after this one.
    await tester.tap(find.text('English'));
    await tester.pump();
  });

  testWidgets('Edit Profile: choosing an avatar shows it on Profile and Home', (WidgetTester tester) async {
    final name = 'itest-avatar-${DateTime.now().millisecondsSinceEpoch}';
    AuthSession.set(name, await AuthApi.signupWithPassword(name, 'a-strong-test-password'));

    await tester.pumpWidget(const MaterialApp(home: HereShell()));
    await tester.pump(const Duration(seconds: 1));

    // Starts on plain initials — no avatar picked yet.
    expect(find.byType(AvatarThumb), findsNothing);

    // Bounded pumps throughout, not pumpAndSettle — HereShell's map has a
    // looping animation that would never let settle finish.
    Future<void> settleABit() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.byKey(const Key('profileAvatar')));
    await settleABit();

    await tester.tap(find.text('Edit Profile'));
    await settleABit();

    await tester.tap(find.byKey(const Key('avatarOption_0')));
    await settleABit();

    // Picking pops back to Profile automatically — its avatar is now an image.
    expect(find.byType(AvatarThumb), findsOneWidget);

    // Tap the AppBar's back button directly rather than tester.pageBack()
    // (which also calls pumpAndSettle internally).
    await tester.tap(find.byTooltip('Back'));
    await settleABit();

    // Home's header avatar should reflect the same pick.
    expect(find.byType(AvatarThumb), findsOneWidget);

    // Leave state clean for any tests that might run after this one.
    AvatarController.selected.value = null;
  });

  testWidgets('Chat: sending a message from Discover delivers it live and persists', (WidgetTester tester) async {
    final selfName = 'itest-chatself-${DateTime.now().millisecondsSinceEpoch}';
    final friendName = 'itest-chatfriend-${DateTime.now().millisecondsSinceEpoch}';
    const password = 'a-strong-test-password';

    final selfToken = await AuthApi.signupWithPassword(selfName, password);
    final friendToken = await AuthApi.signupWithPassword(friendName, password);
    AuthSession.set(selfName, selfToken);

    await tester.pumpWidget(const MaterialApp(home: HereShell()));
    await tester.pump(const Duration(seconds: 1));

    // A raw socket standing in for the friend's phone.
    final friendChannel = WebSocketChannel.connect(Uri.parse('ws://10.0.2.2:3000?token=$friendToken'));
    final friendChatMessages = <Map<String, dynamic>>[];
    friendChannel.stream.listen((raw) {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      if (message['event'] == 'chat:message') friendChatMessages.add(message['data'] as Map<String, dynamic>);
    });

    Future<void> settleABit() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.tap(find.text('Discover'));
    await tester.pump();
    expect(
      await _pumpUntil(tester, () => find.text(friendName).evaluate().isNotEmpty),
      isTrue,
      reason: 'friend should appear in Discover via the realtime presence list',
    );

    // Tap the chat icon on the friend's card to open a thread with them.
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await settleABit();
    expect(find.text(friendName), findsWidgets);

    await tester.enterText(find.byType(TextField), 'hello from self!');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));

    // The sent message reaches the UI only via the server's echo, same as
    // the realtime ping test — proving the round-trip actually happened.
    expect(
      await _pumpUntil(tester, () => find.text('hello from self!').evaluate().isNotEmpty),
      isTrue,
      reason: 'sent message should appear in the thread via the realtime echo',
    );
    expect(friendChatMessages.length, 1, reason: "friend's raw socket should have received the message too");
    expect(friendChatMessages.first['body'], 'hello from self!');

    // Back to the Chats tab — the conversation should now be listed, backed
    // by the persisted history (not just the in-memory realtime stream).
    await tester.tap(find.byTooltip('Back'));
    await settleABit();
    await tester.tap(find.text('Chats'));
    await settleABit();
    expect(find.text(friendName), findsOneWidget, reason: 'friend should appear in the Chats list after messaging');
    expect(find.text('hello from self!'), findsOneWidget);

    await friendChannel.sink.close();
  });
}
