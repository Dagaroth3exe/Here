import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/app_locale.dart';
import '../l10n/strings.dart';
import '../services/area_api.dart';
import '../services/area_safety.dart';

/// Recent HERE alerts around you, the official NCRB figures, and the switch
/// for area heads-ups — shared by the Home sheet and the SOS tab.
class AreaInfo extends StatelessWidget {
  const AreaInfo({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(t('Alerts near you'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
          const SizedBox(height: 10),
        ],
        ValueListenableBuilder<AreaSummary?>(
          valueListenable: AreaSafety.instance.current,
          builder: (context, summary, _) => Text(
            summary == null ? '' : areaSummaryText(summary),
            style: AppText.reputationLine.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t(
            'This counts emergency alerts raised on HERE by different people within about 1 km over the last 30 days. False alarms and alerts from the last hour are left out, and nothing is shown for fewer than 2 people, so no single alert can be identified.',
          ),
          style: AppText.meta.copyWith(color: colors.ink70, height: 1.45),
        ),
        const SizedBox(height: 8),
        Text(
          t('That count is a heads-up, not a safety rating.'),
          style: AppText.meta.copyWith(color: colors.ink70, height: 1.45),
        ),
        ValueListenableBuilder<AreaCrime?>(
          valueListenable: AreaSafety.instance.district,
          builder: (context, crime, _) => crime == null ? const SizedBox.shrink() : _OfficialFigures(crime: crime),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<bool?>(
          valueListenable: AreaSafety.instance.notices,
          builder: (context, on, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: on ?? true,
            onChanged: on == null ? null : (value) => AreaSafety.instance.setNotices(value).ignore(),
            activeThumbColor: colors.green,
            title: Text(
              t('Notify me in areas with recent alerts'),
              style: AppText.reputationLine.copyWith(color: colors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

/// What the area line means — its source, and what it isn't.
void showAreaSheet(BuildContext context) {
  final colors = context.colors;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.paper,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => const SafeArea(
      child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(22, 20, 22, 16), child: AreaInfo()),
    ),
  );
}

/// Official figures in the explainer sheet: the city's newest (where the
/// district is part of one of NCRB's metropolitan cities) and the district's,
/// each with its year, the change from the year before, and its source.
class _OfficialFigures extends StatelessWidget {
  const _OfficialFigures({required this.crime});

  final AreaCrime crime;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numbers = NumberFormat.decimalPattern(AppLocale.current.value.languageCode);
    final city = crime.cityFigures;
    final district = crime.districtFigures;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: AppText.reputationLine.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
      ),
    );
    Widget line(String text, {Color? color}) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(text, style: AppText.meta.copyWith(color: color ?? colors.ink70, height: 1.4)),
    );
    String? change(CrimeFigures f) {
      final c = f.changePercent;
      if (c == null || f.previousYear == null) return null;
      final args = {'percent': c.abs().toStringAsFixed(1), 'year': f.previousYear};
      return c >= 0 ? t('Up {percent}% from {year}', args) : t('Down {percent}% from {year}', args);
    }

    Widget source(CrimeFigures f, String via) => InkWell(
      onTap: () => launchUrl(Uri.parse(f.sourceUrl), mode: LaunchMode.externalApplication),
      child: line(
        t('Source: NCRB, Crime in India — {title} ({via}).', {'title': f.sourceTitle, 'via': via}),
        color: colors.greenInk,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(t('Official figures'), style: AppText.sectionHeader.copyWith(color: colors.ink, fontSize: 16)),
        if (city != null) ...[
          heading(
            t('{city} city: {count} reported crimes in {year}', {
              'city': crime.city,
              'count': numbers.format(city.total),
              'year': city.year,
            }),
          ),
          ?change(city) == null ? null : line(change(city)!),
          if (crime.ratePerLakh != null)
            line(
              t('{rate} per lakh people (NCRB’s rate, on 2011 population)', {
                'rate': crime.ratePerLakh!.toStringAsFixed(1),
              }),
            ),
          source(city, 'OpenCity'),
        ],
        if (district != null) ...[
          heading(
            t('{district} district: {count} reported crimes in {year}', {
              'district': crime.district,
              'count': numbers.format(district.total),
              'year': district.year,
            }),
          ),
          ?change(district) == null ? null : line(change(district)!),
          if (crime.top.isNotEmpty)
            line(
              t('Most reported: {list}', {
                'list': crime.top.map((h) => '${crimeHeadLabel(h.$1)} (${numbers.format(h.$2)})').join(', '),
              }),
            ),
          line(
            t('District-level figures are published only up to {year}.', {'year': district.year}),
            color: colors.ink50,
          ),
          source(district, 'data.gov.in'),
        ],
        const SizedBox(height: 8),
        Text(
          t(
            'These are crimes reported to police over a whole year — not a measure of any one street, and they rise and fall with how often people report. Updated automatically when NCRB publishes new figures.',
          ),
          style: AppText.meta.copyWith(color: colors.ink50, height: 1.45),
        ),
        line(t('Boundaries: {boundaries}.', {'boundaries': crime.boundaries}), color: colors.ink45),
      ],
    );
  }
}
