import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
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
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthApi.loginWithTotp(_email.text.trim(), _code.text.trim());
      AuthSession.set(_email.text.trim(), token);
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
          'Enter your email and the code from your authenticator app.',
          style: AppText.reputationLine.copyWith(color: context.colors.ink50),
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AuthTextField(
          controller: _code,
          label: 'Authenticator code',
          keyboardType: TextInputType.number,
          maxLength: 6,
          letterSpacedDigits: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        PrimaryAuthButton(label: 'Log in', loading: _loading, onTap: _submit),
      ],
    );
  }
}
