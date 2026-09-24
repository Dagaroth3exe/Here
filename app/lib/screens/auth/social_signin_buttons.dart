import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../design/colors.dart';
import '../../l10n/strings.dart';
import '../../services/auth_api.dart';
import '../../services/auth_session.dart';
import 'auth_widgets.dart';

/// The OAuth client id for HERE's backend (a Google Cloud "Web" client),
/// passed as `serverClientId` so the id token's audience matches what
/// `GOOGLE_CLIENT_ID` on the backend verifies against. Empty until a Google
/// Cloud project is created — sign-in will fail cleanly until then.
const _googleServerClientId = '';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(serverClientId: _googleServerClientId);
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw AuthApiException("Couldn't get a Google sign-in token, try again.");
      }
      final token = await AuthApi.signInWithGoogle(idToken);
      await AuthSession.set(account.displayName ?? account.email, token);
      widget.onSuccess();
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't sign in with Google, try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          label: t('Continue with Google'),
          loading: _loading,
          onTap: _signIn,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          AuthErrorBanner(message: t(_error!)),
        ],
      ],
    );
  }
}

class AppleSignInButton extends StatefulWidget {
  const AppleSignInButton({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends State<AppleSignInButton> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw AuthApiException("Couldn't get an Apple sign-in token, try again.");
      }
      // Apple only ever supplies the name on the very first authorization —
      // it's never present in the token itself, so it must be forwarded now.
      final fullName = [
        credential.givenName,
        credential.familyName,
      ].where((part) => part != null && part.isNotEmpty).join(' ');
      final token = await AuthApi.signInWithApple(idToken, fullName.isEmpty ? null : fullName);
      await AuthSession.set(fullName.isEmpty ? (credential.email ?? 'You') : fullName, token);
      widget.onSuccess();
    } on AuthApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't sign in with Apple, try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          label: t('Continue with Apple'),
          loading: _loading,
          onTap: _signIn,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          AuthErrorBanner(message: t(_error!)),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.hairline),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: colors.ink55),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colors.ink,
                ),
              ),
      ),
    );
  }
}
