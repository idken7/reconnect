import 'package:flutter/material.dart';

import '../models.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.contactsImported,
    required this.isImporting,
    required this.statusMessage,
    required this.onImportContacts,
    required this.onRankContacts,
    required this.onChangeLocation,
    this.onSpinWheel,
    this.onConversationStarter,
    this.onActivitySuggestion,
  });

  final ReconnectProfile profile;
  final bool contactsImported;
  final bool isImporting;
  final String? statusMessage;
  final VoidCallback onImportContacts;
  final VoidCallback onRankContacts;
  final VoidCallback onChangeLocation;
  final VoidCallback? onSpinWheel;
  final VoidCallback? onConversationStarter;
  final VoidCallback? onActivitySuggestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (statusMessage != null) ...[
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(statusMessage!),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Your reconnect profile',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(profile.bio),
                const SizedBox(height: 16),
                _ProfileRow(label: 'Email', value: profile.email),
                _ProfileRow(label: 'Phone', value: profile.phone),
                _ProfileRow(label: 'Home city', value: profile.homeCity),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('MVP actions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: contactsImported || isImporting ? null : onImportContacts,
                  icon: const Icon(Icons.contacts),
                  label: Text(
                    isImporting
                        ? 'Importing contacts...'
                        : contactsImported
                            ? 'Contacts imported'
                            : 'Import contacts',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onRankContacts,
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Rank contacts'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onChangeLocation,
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Change location'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (onSpinWheel != null || onConversationStarter != null || onActivitySuggestion != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Featured features', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (onSpinWheel != null) ...[
                    OutlinedButton.icon(
                      onPressed: onSpinWheel,
                      icon: const Icon(Icons.casino),
                      label: const Text('Spin the wheel'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onConversationStarter != null) ...[
                    OutlinedButton.icon(
                      onPressed: onConversationStarter,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Conversation starters'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onActivitySuggestion != null) ...[
                    OutlinedButton.icon(
                      onPressed: onActivitySuggestion,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Activity suggestions'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
