import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/area_api.dart';
import '../services/area_safety.dart';
import '../widgets/alert_heat_map.dart';
import '../widgets/area_info.dart';
import 'emergency_screen.dart';

/// The Safety tab, kept simple: the SOS button and "Call 112" first, and
/// everything else (the alerts map, what's known about the area, helplines,
/// area heads-ups) one tap away as tiles.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // One screen, no scrolling: the SOS card takes whatever height is left
    // after the title and the options.
    return Material(
      color: colors.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('Safety'), style: AppText.screenTitle.copyWith(color: colors.ink)),
            const SizedBox(height: 14),
            const Expanded(child: EmergencyScreen(embedded: true)),
            const SizedBox(height: 14),
            const _Options(),
          ],
        ),
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options();

  @override
  Widget build(BuildContext context) {
    final area = AreaSafety.instance;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _OptionTile(
                icon: Icons.map_outlined,
                title: t('Alerts map'),
                subtitle: t('Last 30 days'),
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _AlertsMapPage())),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ValueListenableBuilder<AreaSummary?>(
                valueListenable: area.current,
                builder: (context, summary, _) => _OptionTile(
                  icon: Icons.shield_outlined,
                  title: t('Your area'),
                  subtitle: summary?.people == null
                      ? t('No recent alerts')
                      : t('{count} alerts nearby', {'count': summary!.people}),
                  onTap: () => showAreaSheet(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OptionTile(
                icon: Icons.phone_in_talk_outlined,
                title: t('Helplines'),
                subtitle: t('Free, 24×7'),
                onTap: () => _showHelplines(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ValueListenableBuilder<bool?>(
                valueListenable: area.notices,
                builder: (context, on, _) => _OptionTile(
                  icon: on ?? false ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                  title: t('Area heads-ups'),
                  subtitle: on == null ? '' : (on ? t('On') : t('Off')),
                  onTap: on == null
                      ? null
                      : () => area.setNotices(!on).catchError((_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t("Couldn't reach the server. Check your connection and try again.")),
                            ),
                          );
                        }),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.hairlineChip),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          child: Row(
            children: [
              Icon(icon, color: colors.greenInk, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.reputationLine.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(color: colors.ink50, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The recent-alerts heat map, full screen.
class _AlertsMapPage extends StatelessWidget {
  const _AlertsMapPage();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        title: Text(t('Alerts map')),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Areas where several people raised emergency alerts in the last 30 days. Pan or zoom to explore.'),
                  style: AppText.meta.copyWith(color: colors.ink50, height: 1.4),
                ),
                const SizedBox(height: 12),
                // Leaves room for the text above and the legend below.
                AlertHeatMap(height: (constraints.maxHeight - 110).clamp(240, double.infinity)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// India's national helplines — all free, all work without HERE.
const _helplines = [
  (number: '112', label: 'Emergency (all services)'),
  (number: '100', label: 'Police'),
  (number: '108', label: 'Ambulance'),
  (number: '101', label: 'Fire'),
  (number: '1091', label: 'Women helpline'),
  (number: '1098', label: 'Child helpline'),
  (number: '1930', label: 'Cyber crime'),
];

void _showHelplines(BuildContext context) {
  final colors = context.colors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(t('Helplines'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          ),
          for (final line in _helplines)
            ListTile(
              leading: Icon(Icons.call_outlined, color: colors.greenInk),
              title: Text(t(line.label), style: AppText.reputationLine.copyWith(color: colors.ink)),
              trailing: Text(
                line.number,
                style: AppText.reputationLine.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
              ),
              onTap: () => launchUrl(Uri(scheme: 'tel', path: line.number)),
            ),
        ],
      ),
    ),
  );
}
