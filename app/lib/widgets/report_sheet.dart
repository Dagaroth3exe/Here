import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/safety_api.dart';

String reportReasonLabel(ReportReason reason) => switch (reason) {
      ReportReason.spam => t('Spam or advertising'),
      ReportReason.harassment => t('Harassment or bullying'),
      ReportReason.inappropriate => t('Inappropriate or sexual content'),
      ReportReason.scam => t('Scam or fraud'),
      ReportReason.unsafe => t('Made me feel unsafe'),
      ReportReason.other => t('Something else'),
    };

/// Asks why, then files a report. For people ([blockUserId] set) it also
/// offers to block them in the same step. Returns whether they were blocked.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  String? blockUserId,
  String? blockName,
}) async {
  final blocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _ReportSheet(target: target, targetId: targetId, blockUserId: blockUserId, blockName: blockName),
  );
  return blocked ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target, required this.targetId, this.blockUserId, this.blockName});

  final ReportTarget target;
  final String targetId;
  final String? blockUserId;
  final String? blockName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  late bool _alsoBlock = widget.blockUserId != null;
  bool _sending = false;

  Future<void> _submit() async {
    final token = AuthSession.accessToken;
    final reason = _reason;
    if (token == null || reason == null || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SafetyApi.report(token, target: widget.target, targetId: widget.targetId, reason: reason, details: _details.text);
      final blockId = widget.blockUserId;
      if (_alsoBlock && blockId != null) await SafetyApi.block(token, blockId);
      if (!mounted) return;
      Navigator.of(context).pop(_alsoBlock && blockId != null);
      messenger.showSnackBar(SnackBar(content: Text(t('Thanks — we got your report.'))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(t("Couldn't send the report. Try again."))));
    }
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Report'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
            const SizedBox(height: 4),
            Text(t("What's wrong? Reports are private."), style: AppText.meta.copyWith(color: colors.ink50)),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: [
                  for (final reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: colors.green,
                      title: Text(reportReasonLabel(reason), style: AppText.reputationLine.copyWith(color: colors.ink)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 1000,
              minLines: 1,
              maxLines: 3,
              style: AppText.reputationLine.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: t('Anything else we should know? (optional)'),
                hintStyle: AppText.meta.copyWith(color: colors.ink38),
              ),
            ),
            if (widget.blockUserId != null)
              CheckboxListTile(
                value: _alsoBlock,
                onChanged: (value) => setState(() => _alsoBlock = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: colors.green,
                title: Text(
                  t('Also block {name}', {'name': widget.blockName ?? ''}),
                  style: AppText.reputationLine.copyWith(color: colors.ink),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reason == null || _sending ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: colors.green, foregroundColor: Colors.white),
                child: Text(t('Send report')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
