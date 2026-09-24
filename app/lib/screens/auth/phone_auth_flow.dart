import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../l10n/strings.dart';
import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import 'auth_widgets.dart';

enum _Step { phone, otp }

/// India-only for now (fixed +91 prefix), matching the SMS gateway and the
/// app's Delhi NCR target market. A country picker is a future improvement.
const _countryCode = '+91';

class PhoneAuthFlow extends StatefulWidget {
  const PhoneAuthFlow({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<PhoneAuthFlow> createState() => _PhoneAuthFlowState();
}

class _PhoneAuthFlowState extends State<PhoneAuthFlow> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  _Step _step = _Step.phone;
  bool _loading = false;
  String? _error;

  String get _fullPhone => '$_countryCode${_phone.text.trim()}';

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthApi.requestOtp(_fullPhone);
      if (!mounted) return;
      setState(() => _step = _Step.otp);
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthApi.verifyOtp(_fullPhone, _code.text.trim());
      await AuthSession.set(_fullPhone, token);
      widget.onSuccess();
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(backgroundColor: colors.paper, elevation: 0),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _step == _Step.phone ? _phoneStep(colors) : _otpStep(colors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep(AppColors colors) {
    return [
      Text(
        t('Phone number'),
        style: AppText.reputationLine.copyWith(color: colors.ink50),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.hairline),
            ),
            child: Text(
              _countryCode,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: colors.ink),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AuthTextField(
              controller: _phone,
              label: t('Phone number'),
              keyboardType: TextInputType.phone,
              autofocus: true,
            ),
          ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        AuthErrorBanner(message: t(_error!)),
      ],
      const SizedBox(height: 20),
      PrimaryAuthButton(label: t('Send code'), loading: _loading, onTap: _sendCode),
    ];
  }

  List<Widget> _otpStep(AppColors colors) {
    return [
      Text(
        t('Enter code'),
        style: AppText.reputationLine.copyWith(color: colors.ink50),
      ),
      const SizedBox(height: 20),
      AuthTextField(
        controller: _code,
        label: t('Enter code'),
        keyboardType: TextInputType.number,
        maxLength: 6,
        letterSpacedDigits: true,
        autofocus: true,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        AuthErrorBanner(message: t(_error!)),
      ],
      const SizedBox(height: 20),
      PrimaryAuthButton(label: t('Verify'), loading: _loading, onTap: _verifyCode),
      const SizedBox(height: 16),
      Center(child: AuthLink(text: t('Resend code'), onTap: _sendCode)),
    ];
  }
}
