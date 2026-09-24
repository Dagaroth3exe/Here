import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../l10n/strings.dart';
import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import 'auth_widgets.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
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
      final token = await AuthApi.signupWithPassword(_name.text.trim(), _password.text);
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
          t('Pick a name and password for your account.'),
          style: AppText.reputationLine.copyWith(color: context.colors.ink50),
        ),
        const SizedBox(height: 20),
        AuthTextField(controller: _name, label: t('Name'), autofocus: true),
        const SizedBox(height: 12),
        AuthTextField(controller: _password, label: t('Password (min. 8 characters)'), obscureText: true),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBanner(message: t(_error!)),
        ],
        const SizedBox(height: 20),
        PrimaryAuthButton(label: t('Sign up'), loading: _loading, onTap: _submit),
      ],
    );
  }
}
