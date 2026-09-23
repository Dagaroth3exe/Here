import 'dart:async';
import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../l10n/strings.dart';
import '../services/auth_session.dart';
import '../services/users_api.dart';
import '../utils/initials.dart';
import 'chat_thread_screen.dart';

/// Finds an account by username to start a new conversation with — unlike
/// Discover, this isn't limited to who's currently online.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _controller = TextEditingController();
  List<UserSearchResult> _results = const [];
  bool _loading = false;
  bool _searched = false;
  Timer? _debounce;
  int _requestId = 0;

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = AuthSession.accessToken;
    if (token == null) return;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _searched = false;
      });
      return;
    }

    final requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final results = await UsersApi.search(token, trimmed);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _searched = true;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

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
        title: Text(t('New chat'), style: AppText.screenTitle.copyWith(color: colors.ink, fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.hairline),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 14.5, color: colors.ink),
                  decoration: InputDecoration(
                    hintText: t('Search by username'),
                    hintStyle: AppText.meta.copyWith(color: colors.ink38),
                    prefixIcon: Icon(Icons.search_rounded, color: colors.ink38, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_loading) return const SizedBox.shrink();

    if (!_searched) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            t('Search for someone to start a new conversation.'),
            textAlign: TextAlign.center,
            style: AppText.reputationLine.copyWith(color: colors.ink50),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            t('No users found'),
            textAlign: TextAlign.center,
            style: AppText.reputationLine.copyWith(color: colors.ink50),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final result = _results[index];
        return _UserRow(
          result: result,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ChatThreadScreen(otherUserId: result.id, otherName: result.username),
            ),
          ),
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.result, required this.onTap});

  final UserSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.sandDeep, shape: BoxShape.circle),
              child: Text(
                initialsFor(result.username),
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13, color: colors.inkMutedAvatar),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(result.username, style: AppText.personName.copyWith(color: colors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
