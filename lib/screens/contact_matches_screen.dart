import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';

class ContactMatchesScreen extends StatelessWidget {
  const ContactMatchesScreen({
    super.key,
    required this.matches,
  });

  final ContactMatches matches;

  @override
  Widget build(BuildContext context) {
    final total = matches.mutual.length + matches.oneWay.length + matches.notOnApp.length;

    if (total == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Contact matches', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No matches found yet. Import contacts first to see who is already on Reconnect.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matches found: $total', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                const Text('These people are already on Reconnect or can be invited.'),
                const SizedBox(height: 12),
                const TabBar(
                  tabs: [
                    Tab(text: 'Mutual'),
                    Tab(text: 'Discovered'),
                    Tab(text: 'Not on app'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MatchList(
                  items: matches.mutual,
                  badge: 'Mutual match',
                ),
                _MatchList(
                  items: matches.oneWay,
                  badge: 'Discovered',
                ),
                _MatchList(
                  items: matches.notOnApp,
                  badge: 'Invite',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.items,
    required this.badge,
  });

  final List<MatchCandidate> items;
  final String badge;

  Widget _buildBadge(String badge, MatchCandidate item) {
    final tooltipText = _getTooltipText(badge);
    
    // For "Invite" badge, make it a button
    if (badge == 'Invite') {
      return Tooltip(
        message: tooltipText,
        child: TextButton(
          onPressed: () => _handleInvite(item),
          child: Chip(
            label: const Text('Invite'),
            labelStyle: const TextStyle(
              color: Colors.white,
            ),
            backgroundColor: Colors.blue,
          ),
        ),
      );
    }
    
    return Tooltip(
      message: tooltipText,
      child: Chip(
        label: Text(badge),
      ),
    );
  }

  String _getInviteMessage(String contactName) {
    return 'Hey $contactName! Let me reconnect with you on Reconnect! 🔗\n\n'
        'Download the app to see who from your contacts wants to reconnect with you.\n'
        'Reconnect App';
  }

  void _handleInvite(MatchCandidate item) {
    final message = _getInviteMessage(item.name);
    Share.share(
      message,
      subject: 'Join me on Reconnect!',
    );
  }

  String _getTooltipText(String badge) {
    switch (badge) {
      case 'Mutual match':
        return 'You both have each other in your top reconnect list';
      case 'Discovered':
        return 'This person has you in their reconnect list';
      case 'Invite':
        return 'This contact is not yet on Reconnect';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No contacts in this category yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            title: Text(item.name),
            subtitle: Text(item.contact?.lastSeen ?? item.status ?? 'Not on app'),
            trailing: _buildBadge(badge, item),
          ),
        );
      },
    );
  }
}
