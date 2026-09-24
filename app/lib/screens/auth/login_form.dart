import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../l10n/strings.dart';
import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import 'auth_widgets.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthApi.loginWithPassword(_name.text.trim(), _password.text);
      await AuthSession.set(_name.text.trim(), token);
      widget.onSuccess();
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('Enter your name and password.'),
          style: AppText.reputationLine.copyWith(color: context.colors.ink50),
        ),
        const SizedBox(height: 20),
        AuthTextField(controller: _name, label: t('Name')),
        const SizedBox(height: 12),
        AuthTextField(controller: _password, label: t('Password'), obscureText: true),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBanner(message: t(_error!)),
        ],
        const SizedBox(height: 20),
        PrimaryAuthButton(label: t('Log in'), loading: _loading, onTap: _submit),
      ],
    );
  }
}
