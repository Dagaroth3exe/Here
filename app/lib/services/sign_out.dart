import 'package:flutter/material.dart';

import '../screens/auth/auth_screen.dart';
import 'area_safety.dart';
import 'auth_session.dart';
import 'emergency_center.dart';
import 'push_notifications.dart';

/// Ends the session on this phone and goes back to the sign-in screen —
/// after "Log out", and after deleting the account. Nothing of the account
/// keeps sounding, sharing or showing.
Future<void> signOut(BuildContext context) async {
  EmergencyCenter.instance.reset();
  AreaSafety.instance.reset();
  await PushNotifications.disable();
  await AuthSession.clear();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
}
