import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../l10n/strings.dart';
import '../../shell.dart';
import 'login_form.dart';
import 'signup_form.dart';

enum _Mode { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.login;

  void _onSuccess() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HereShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Hero(
                      tag: 'here-wordmark',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text('HERE', style: AppText.wordmark.copyWith(fontSize: 40, color: colors.ink)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(t('Someone HERE can help.'), style: AppText.meta.copyWith(color: colors.ink45)),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              _ModeToggle(mode: _mode, onChanged: (mode) => setState(() => _mode = mode)),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _mode == _Mode.login
                    ? LoginForm(key: const ValueKey('login'), onSuccess: _onSuccess)
                    : SignupForm(key: const ValueKey('signup'), onSuccess: _onSuccess),
              ),
            ],
          ),
        ),
      ),
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
      decoration: BoxDecoration(color: colors.sand, borderRadius: BorderRadius.circular(14)),
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
          style: AppText.chipLabel.copyWith(color: active ? colors.paper : colors.ink55, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
