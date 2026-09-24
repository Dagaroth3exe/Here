import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../l10n/strings.dart';
import '../../shell.dart';
import 'auth_widgets.dart';
import 'login_form.dart';
import 'phone_auth_flow.dart';
import 'signup_form.dart';
import 'social_signin_buttons.dart';

enum _Mode { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.login;

  void _onSuccess() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HereShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
      (route) => false,
    );
  }

  void _openPhoneFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PhoneAuthFlow(onSuccess: _onSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.greenTint,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: colors.reachableStatBorder,
                            ),
                          ),
                          child: Image.asset(
                            'assets/mascot/mascot_idle.png',
                            filterQuality: FilterQuality.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Hero(
                          tag: 'here-wordmark',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              'HERE',
                              style: AppText.wordmark.copyWith(
                                fontSize: 40,
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t('Someone HERE can help.'),
                          style: AppText.reputationLine.copyWith(
                            color: colors.ink70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  _ModeToggle(
                    mode: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _mode == _Mode.login
                        ? LoginForm(
                            key: const ValueKey('login'),
                            onSuccess: _onSuccess,
                          )
                        : SignupForm(
                            key: const ValueKey('signup'),
                            onSuccess: _onSuccess,
                          ),
                  ),
                  const SizedBox(height: 20),
                  _OrDivider(),
                  const SizedBox(height: 16),
                  GoogleSignInButton(onSuccess: _onSuccess),
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    AppleSignInButton(onSuccess: _onSuccess),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: AuthLink(
                      text: t('Use phone number instead'),
                      onTap: _openPhoneFlow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            t('or continue with'),
            style: AppText.chipLabel.copyWith(color: colors.ink55),
          ),
        ),
        Expanded(child: Divider(color: colors.hairline)),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.sand,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _segment(context, t('Log in'), _Mode.login)),
          Expanded(child: _segment(context, t('Sign up'), _Mode.signup)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, _Mode value) {
    final colors = context.colors;
    final active = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: AppText.chipLabel.copyWith(
            color: active ? colors.paper : colors.ink55,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
