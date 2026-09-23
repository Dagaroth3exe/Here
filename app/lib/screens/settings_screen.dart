import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.ink,
        title: Text(t('Settings'), style: AppText.screenTitle.copyWith(color: colors.ink, fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          children: [
            Text(t('Appearance'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
            const SizedBox(height: 11),
            const _AppearancePicker(),
            const SizedBox(height: 28),
            Text(t('Language'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
            const SizedBox(height: 11),
            const _LanguagePicker(),
          ],
        ),
      ),
    );
  }
}

class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker();

  static const _options = [
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
    (ThemeMode.system, 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, current, _) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: colors.sand, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              for (final (mode, label) in _options)
                Expanded(
                  child: GestureDetector(
                    onTap: () => ThemeController.mode.value = mode,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: current == mode ? colors.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        t(label),
                        style: AppText.chipLabel.copyWith(
                          color: current == mode ? colors.paper : colors.ink55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocale.current,
      builder: (context, current, _) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.hairline),
          ),
          child: Column(
            children: [
              for (final locale in AppLocale.supported) ...[
                if (locale != AppLocale.supported.first)
                  Divider(height: 1, color: colors.hairline),
                GestureDetector(
                  onTap: () => AppLocale.current.value = locale,
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocale.nativeNames[locale]!, style: AppText.personName.copyWith(color: colors.ink)),
                        if (locale == current) Icon(Icons.check, color: colors.green, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
