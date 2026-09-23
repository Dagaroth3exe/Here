import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLength,
    this.letterSpacedDigits = false,
    this.autofocus = false,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool letterSpacedDigits;
  final bool autofocus;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.hairline),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        autofocus: autofocus,
        obscureText: obscureText,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: letterSpacedDigits ? 20 : 15,
          fontWeight: letterSpacedDigits ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: letterSpacedDigits ? 8 : 0,
          color: colors.ink,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppText.meta.copyWith(color: colors.ink45),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class PrimaryAuthButton extends StatelessWidget {
  const PrimaryAuthButton({super.key, required this.label, required this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? colors.green : colors.green.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white.withValues(alpha: 0.9)),
              )
            : Text(label, style: AppText.pingButton.copyWith(color: Colors.white)),
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: colors.errorTint, borderRadius: BorderRadius.circular(10)),
      child: Text(
        message,
        style: TextStyle(fontFamily: 'Outfit', fontSize: 12.5, color: colors.error),
      ),
    );
  }
}

class AuthLink extends StatelessWidget {
  const AuthLink({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 13, color: context.colors.greenInk),
      ),
    );
  }
}
