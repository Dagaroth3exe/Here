import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/area_safety.dart';
import '../services/emergency_api.dart';
import '../services/emergency_center.dart';
import '../services/push_notifications.dart';
import '../services/avatar_controller.dart';
import '../services/profile_api.dart';
import '../services/profile_controller.dart';
import '../utils/initials.dart';
import '../widgets/avatar_thumb.dart';
import 'auth/auth_screen.dart';
import 'edit_profile_screen.dart';
import 'emergency_alert_screen.dart';
import 'emergency_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    EmergencyCenter.instance.reset();
    AreaSafety.instance.reset();
    await PushNotifications.disable();
    await AuthSession.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
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
        child: SingleChildScrollView(
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
                    ValueListenableBuilder<UserProfile?>(
                      valueListenable: ProfileController.current,
                      builder: (context, profile, _) {
                        final interests = profile?.interests ?? const [];
                        if (interests.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final interest in interests)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colors.sand,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: colors.hairline),
                                  ),
                                  child: Text(interest, style: AppText.chipLabel.copyWith(color: colors.ink70)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              _MenuRow(
                label: t('Edit Profile'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              ),
              const SizedBox(height: 12),
              _MenuRow(
                label: t('Settings'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              const SizedBox(height: 12),
              // Safety, last in the list.
              ValueListenableBuilder<EmergencyAlert?>(
                valueListenable: EmergencyCenter.instance.mine,
                builder: (context, active, _) => _MenuRow(
                  label: t('Emergency SOS'),
                  subtitle: active != null ? t('Your alert is on') : t('Alert people nearby'),
                  icon: Icons.sos_rounded,
                  iconColor: emergencyRed,
                  emphasized: active != null,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                ),
              ),
              const SizedBox(height: 12),
              _MenuRow(
                label: t('Alerts near you'),
                subtitle: t('Recent alerts and official figures'),
                icon: Icons.shield_outlined,
                iconColor: colors.trust,
                onTap: () => showAreaSheet(context),
              ),
              const SizedBox(height: 24),
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
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.emphasized = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  /// Outlined in the icon's color — e.g. while your SOS alert is on.
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: emphasized ? (iconColor ?? colors.hairline) : colors.hairline,
              width: emphasized ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, color: iconColor ?? colors.ink70, size: 22), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppText.personName.copyWith(color: colors.ink)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.meta.copyWith(
                          color: emphasized ? (iconColor ?? colors.ink50) : colors.ink50,
                          fontWeight: emphasized ? FontWeight.w600 : null,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.ink38),
            ],
          ),
        ),
      ),
    );
  }
}
