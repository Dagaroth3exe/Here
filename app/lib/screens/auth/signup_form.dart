import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import 'auth_widgets.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<SignupForm> createState() => _SignupFormState();
}

enum _Step { email, confirm }

class _SignupFormState extends State<SignupForm> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.email;
  TotpSetupResult? _setup;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _startSetup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AuthApi.setupTotp(_email.text.trim());
      setState(() {
        _setup = result;
        _step = _Step.confirm;
      });
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthApi.confirmTotp(_email.text.trim(), _code.text.trim());
      AuthSession.set(_email.text.trim(), token);
      widget.onSuccess();
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToEmail() {
    setState(() {
      _step = _Step.email;
      _setup = null;
      _code.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _step == _Step.email ? _buildEmailStep(context) : _buildConfirmStep(context);
  }

  Widget _buildEmailStep(BuildContext context) {
    return Column(
      key: const ValueKey('email-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "We'll set up an authenticator app as your login — no password, no phone number.",
          style: AppText.reputationLine.copyWith(color: context.colors.ink50),
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        PrimaryAuthButton(label: 'Continue', loading: _loading, onTap: _startSetup),
      ],
    );
  }

  Widget _buildConfirmStep(BuildContext context) {
    final colors = context.colors;
    final setup = _setup!;
    final groupedSecret = [
      for (var i = 0; i < setup.secret.length; i += 4) setup.secret.substring(i, (i + 4).clamp(0, setup.secret.length)),
    ].join(' ');

    return Column(
      key: const ValueKey('confirm-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scan this with an authenticator app (Google Authenticator, Aegis, etc.)',
          style: AppText.reputationLine.copyWith(color: colors.ink50),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // Fixed white/black regardless of app theme — scanners expect
              // dark modules on a light background.
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.hairline),
            ),
            child: QrImageView(
              data: setup.otpauthUrl,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: setup.secret));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Code copied')),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.sand,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Can't scan? Enter this code manually", style: AppText.meta.copyWith(color: colors.ink45)),
                const SizedBox(height: 4),
                Text(
                  groupedSecret,
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 14, color: colors.ink70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _code,
          label: 'Enter the 6-digit code',
          keyboardType: TextInputType.number,
          maxLength: 6,
          letterSpacedDigits: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        PrimaryAuthButton(label: 'Confirm', loading: _loading, onTap: _confirm),
        const SizedBox(height: 14),
        Center(child: AuthLink(text: '← Use a different email', onTap: _backToEmail)),
      ],
    );
  }
}
