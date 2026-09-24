import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/colors.dart';
import 'l10n/app_locale.dart';
import 'screens/splash_screen.dart';
import 'services/accent_controller.dart';
import 'services/auth_session.dart';
import 'services/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSession.restore();
  runApp(const HereApp());
}

/// Material 3's default overscroll indicator on Android is a "stretch"
/// effect that visibly distorts the content when you drag past the edge —
/// too much for this app's quiet, flat aesthetic. Swap it for the classic,
/// subtle glow instead.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: context.colors.ink.withValues(alpha: 0.06),
      child: child,
    );
  }
}

class HereApp extends StatelessWidget {
  const HereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppLocale.current,
          builder: (context, locale, _) {
            return ValueListenableBuilder<double?>(
              valueListenable: AccentController.hue,
              builder: (context, _, _) {
                final lightColors = AppColors.light.resolveAccent(dark: false);
                final darkColors = AppColors.dark.resolveAccent(dark: true);
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'HERE',
                  locale: locale,
                  supportedLocales: AppLocale.supported,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.light,
                    fontFamily: 'Outfit',
                    scaffoldBackgroundColor: lightColors.paper,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: lightColors.green,
                      brightness: Brightness.light,
                      surface: lightColors.paper,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    brightness: Brightness.dark,
                    fontFamily: 'Outfit',
                    scaffoldBackgroundColor: darkColors.paper,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: darkColors.green,
                      brightness: Brightness.dark,
                      surface: darkColors.paper,
                    ),
                  ),
                  themeMode: themeMode,
                  scrollBehavior: _AppScrollBehavior(),
                  home: const SplashScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}
