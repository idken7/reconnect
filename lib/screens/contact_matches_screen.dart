import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';

enum _MatchTab { mutual, discovered, invite }

class ContactMatchesScreen extends StatefulWidget {
  const ContactMatchesScreen({super.key, required this.matches});

  final ContactMatches matches;

  @override
  State<ContactMatchesScreen> createState() => _ContactMatchesScreenState();
}

class _ContactMatchesScreenState extends State<ContactMatchesScreen> {
  _MatchTab _tab = _MatchTab.mutual;

  List<MatchCandidate> _itemsFor(_MatchTab tab) {
    switch (tab) {
      case _MatchTab.mutual:
        return widget.matches.mutual;
      case _MatchTab.discovered:
        return widget.matches.oneWay;
      case _MatchTab.invite:
        return widget.matches.notOnApp;
    }
  }

  String _badgeFor(_MatchTab tab) {
    switch (tab) {
      case _MatchTab.mutual:
        return 'Mutual';
      case _MatchTab.discovered:
        return 'Discovered';
      case _MatchTab.invite:
        return 'Invite';
    }
  }

  String _emptyMessageFor(_MatchTab tab) {
    switch (tab) {
      case _MatchTab.mutual:
        return 'No two-way reconnects yet.';
      case _MatchTab.discovered:
        return 'No discovered contacts yet.';
      case _MatchTab.invite:
        return 'Everyone in this set is already on Reconnect.';
    }
  }

  Future<void> _handleInvite(BuildContext context, MatchCandidate item) async {
    final message = 'Hey ${item.name}! I am using Reconnect to make catching up easier.\n\n'
        'Download the app to see who from your contacts wants to reconnect with you.\n'
        'Reconnect App';
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'Join me on Reconnect',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.matches;
    final total = matches.mutual.length + matches.oneWay.length + matches.notOnApp.length;

    if (total == 0) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matches', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 20),
                const Text(
                  'No matches found yet. Import contacts first to see who is already on Reconnect.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: ReconnectColors.mutedText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = _itemsFor(_tab);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matches', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'People already on Reconnect, found through your contacts.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        for (final tab in _MatchTab.values)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _tab = tab),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _tab == tab ? ReconnectColors.ink : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  _badgeFor(tab),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: _tab == tab ? Colors.white : ReconnectColors.chipForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(_emptyMessageFor(_tab), style: const TextStyle(color: ReconnectColors.mutedText, fontWeight: FontWeight.w600)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _MatchRow(
                        item: items[index],
                        isInvite: _tab == _MatchTab.invite,
                        badgeText: _badgeFor(_tab),
                        onInvite: () => _handleInvite(context, items[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.item, required this.isInvite, required this.badgeText, required this.onInvite});

  final MatchCandidate item;
  final bool isInvite;
  final String badgeText;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFE4DCCF), shape: BoxShape.circle),
            child: Text(_initialOf(item.name), style: const TextStyle(color: Color(0xFF7A6F61), fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  item.contact?.lastSeen ?? item.status ?? 'Not on app',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ReconnectColors.mutedText),
                ),
              ],
            ),
          ),
          if (isInvite)
            AdaptiveFilledButton(compact: true, onPressed: onInvite, child: const Text('Invite'))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(10)),
              child: Text(badgeText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: ReconnectColors.chipForeground)),
            ),
        ],
      ),
    );
  }
}

String _initialOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts.last[0] : '';
  return (first + second).toUpperCase();
}
