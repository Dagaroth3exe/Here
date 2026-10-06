import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_api.dart';
import '../services/auth_session.dart';
import '../services/profile_api.dart';
import '../services/sign_out.dart';

/// The word to type before the delete button unlocks — a deliberate step for
/// something that can't be undone.
const _confirmWord = 'DELETE';

/// Says exactly what deleting the account removes, asks for [_confirmWord],
/// then deletes it and signs out.
Future<void> showDeleteAccountSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.colors.paper,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
  builder: (_) => const _DeleteAccountSheet(),
);

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  bool get _confirmed => _confirm.text.trim().toUpperCase() == _confirmWord;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final token = AuthSession.accessToken;
    if (token == null || !_confirmed) return;
    // The sheet's own context goes with the sign-in screen swap, so sign out
    // through the navigator's, which outlives it.
    final navigatorContext = Navigator.of(context, rootNavigator: true).context;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ProfileApi.deleteAccount(token);
    } on AuthApiException catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = t(e.message);
        });
      }
      return;
    }
    if (!navigatorContext.mounted) return;
    await signOut(navigatorContext);
    if (navigatorContext.mounted) {
      ScaffoldMessenger.of(navigatorContext).showSnackBar(SnackBar(content: Text(t('Your account was deleted.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = [
      t('Your profile, name and sign-in methods'),
      t('All your chats and messages, for you and the people you talked to'),
      t('Your SOS alerts and location history'),
      t('Your blocks, reports and settings'),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 22, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('Delete your account?'), style: AppText.sectionHeader.copyWith(color: colors.ink)),
            const SizedBox(height: 6),
            Text(
              t('This can’t be undone. It permanently deletes:'),
              style: AppText.reputationLine.copyWith(color: colors.ink70),
            ),
            const SizedBox(height: 10),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.remove_circle_outline, size: 16, color: colors.error),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item, style: AppText.reputationLine.copyWith(color: colors.ink)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              t('Questions and answers you posted on Ask HERE stay up anonymously, with no link to you.'),
              style: AppText.meta.copyWith(color: colors.ink50, height: 1.4),
            ),
            const SizedBox(height: 18),
            Text(
              t('Type {word} to confirm', {'word': _confirmWord}),
              style: AppText.meta.copyWith(color: colors.ink70, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              enabled: !_deleting,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              style: AppText.reputationLine.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: _confirmWord,
                hintStyle: AppText.reputationLine.copyWith(color: colors.ink38),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.hairline),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: AppText.meta.copyWith(color: colors.error)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _confirmed && !_deleting ? _delete : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.error.withValues(alpha: 0.3),
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _deleting ? t('Deleting…') : t('Delete my account'),
                style: AppText.pingButton.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _deleting ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: colors.ink70, minimumSize: const Size.fromHeight(46)),
              child: Text(t('Cancel')),
            ),
          ],
        ),
      ),
    );
  }
}
