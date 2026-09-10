import 'dart:math';
import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:here_app/main.dart';
import 'package:here_app/screens/auth/auth_screen.dart';
import 'package:here_app/shell.dart';

/// RFC 6238 TOTP, matching the backend's otplib defaults (SHA1, 30s, 6 digits).
/// Used to drive the real signup flow end-to-end without a human typing a
/// code from an authenticator app.
String generateTotp(String base32Secret) {
  final key = base32.decode(base32Secret);
  final counter = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
  final counterBytes = ByteData(8)..setUint64(0, counter, Endian.big);
  final digest = Hmac(sha1, key).convert(counterBytes.buffer.asUint8List()).bytes;
  final offset = digest[digest.length - 1] & 0x0f;
  final binaryCode = ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
  return (binaryCode % pow(10, 6).toInt()).toString().padLeft(6, '0');
}

/// The setup step shows the secret grouped as "XXXX XXXX ...". Find it
/// however it flows onto the widget tree rather than assuming layout.
String findGroupedSecret(WidgetTester tester) {
  final pattern = RegExp(r'^[A-Z2-7]{4}( [A-Z2-7]{4})+$');
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data != null && pattern.hasMatch(data)) return data.replaceAll(' ', '');
  }
  throw StateError('Secret text not found on screen');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash animation hands off to the auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HereApp());
    await tester.pump(); // first frame: splash visible
    expect(find.text('Log in'), findsNothing);

    // The splash's own AnimationController drives a fixed-length intro then
    // navigates away — bounded pumps rather than pumpAndSettle since the
    // destination (AuthScreen) briefly overlaps during the fade transition.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('Sign up with TOTP reaches the app, backed by the real server', (WidgetTester tester) async {
    // Pumps AuthScreen directly rather than through the splash animation —
    // this test is about the signup flow, not the intro.
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    final email = 'itest-${DateTime.now().millisecondsSinceEpoch}@example.com';
    await tester.enterText(find.byType(TextField).first, email);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 15));

    final secret = findGroupedSecret(tester);
    final code = generateTotp(secret);

    await tester.enterText(find.byType(TextField).first, code);
    await tester.tap(find.text('Confirm'));
    // Bounded pumps, not pumpAndSettle — this navigates into the shell,
    // whose map has a looping animation that would never let settle finish.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text("You're Reachable"), findsOneWidget);
  });

  testWidgets('Home shows Reachable status and Discover lists people', (WidgetTester tester) async {
    // Pumps the shell directly rather than the full app — this test is about
    // the core Home/Discover behavior, not the auth gate in front of it.
    await tester.pumpWidget(const MaterialApp(home: HereShell()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('HERE'), findsOneWidget);
    expect(find.text("You're Reachable"), findsOneWidget);

    await tester.tap(find.text("You're Reachable"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Not Reachable'), findsOneWidget);

    await tester.tap(find.text('Discover'));
    await tester.pump();
    expect(find.text('People HERE'), findsOneWidget);
    expect(find.text('Rahul K.'), findsOneWidget);

    await tester.tap(find.widgetWithText(GestureDetector, 'PING').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ping sent'), findsOneWidget);
  });
}
