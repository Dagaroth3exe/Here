import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/avatar_controller.dart';
import '../utils/initials.dart';
import '../widgets/avatar_thumb.dart';
import 'auth/auth_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _signOut(BuildContext context) {
    AuthSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = AuthSession.name ?? 'You';

    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        title: Text(t('Profile'), style: AppText.screenTitle.copyWith(color: colors.ink, fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: AvatarController.selected,
                      builder: (context, avatar, _) {
                        return Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: colors.sandDeep, shape: BoxShape.circle),
                          child: avatar != null
                              ? AvatarThumb(source: avatar, size: 76)
                              : Text(
                                  initialsFor(name),
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 24,
                                    color: colors.inkMutedAvatar,
                                  ),
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(name, style: AppText.screenTitle.copyWith(color: colors.ink)),
                    const SizedBox(height: 4),
                    Text(t('HERE member'), style: AppText.meta.copyWith(color: colors.ink45)),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              _MenuRow(
                label: t('Edit Profile'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _MenuRow(
                label: t('Settings'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _signOut(context),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.errorTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(t('Log out'), style: AppText.pingButton.copyWith(color: colors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.personName.copyWith(color: colors.ink)),
            Icon(Icons.chevron_right, color: colors.ink38),
          ],
        ),
      ),
    );
  }
}
