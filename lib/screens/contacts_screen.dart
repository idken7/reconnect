import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/birthday_reminder_card.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({
    super.key,
    required this.contactsImported,
    required this.contacts,
    required this.isImporting,
    required this.statusMessage,
    required this.onImportContacts,
    required this.onPreferenceChanged,
  });

  final bool contactsImported;
  final List<ReconnectContact> contacts;
  final bool isImporting;
  final String? statusMessage;
  final VoidCallback onImportContacts;
  final void Function(String contactId, ReconnectPreference preference) onPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    if (!contactsImported) {
      return _EmptyState(
        onImportContacts: onImportContacts,
        isImporting: isImporting,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (statusMessage != null) ...[
          _StatusCard(message: statusMessage!),
          const SizedBox(height: 12),
        ],
        // Birthday reminders
        BirthdayReminderCard(contacts: contacts),
        const SizedBox(height: 16),
        Text(
          'Who is already on Reconnect',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Rank people from “love to see” to “rather avoid” so the app can make better suggestions without exposing those preferences.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        for (final contact in contacts) ...[
          _ContactCard(
            contact: contact,
            onPreferenceChanged: (preference) => onPreferenceChanged(contact.id, preference),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImportContacts, required this.isImporting});

  final VoidCallback onImportContacts;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.import_contacts_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Import contacts to discover who is on the app.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This first pass keeps contact matching local in the product flow and only surfaces people who have already joined.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isImporting ? null : onImportContacts,
              icon: const Icon(Icons.contacts),
              label: Text(isImporting ? 'Importing contacts...' : 'Import contacts'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onPreferenceChanged});

  final ReconnectContact contact;
  final ValueChanged<ReconnectPreference> onPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(contact.lastSeen),
                    ],
                  ),
                ),
                Chip(
                  label: Text(contact.isOnApp ? 'On app' : 'Not on app'),
                  avatar: Icon(
                    contact.isOnApp ? Icons.verified_outlined : Icons.person_search_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PreferenceChip(
                  label: ReconnectPreference.loveToSee.shortLabel,
                  color: ReconnectPreference.loveToSee.color,
                  selected: contact.preference == ReconnectPreference.loveToSee,
                  onTap: () => onPreferenceChanged(ReconnectPreference.loveToSee),
                ),
                _PreferenceChip(
                  label: ReconnectPreference.neutral.shortLabel,
                  color: ReconnectPreference.neutral.color,
                  selected: contact.preference == ReconnectPreference.neutral,
                  onTap: () => onPreferenceChanged(ReconnectPreference.neutral),
                ),
                _PreferenceChip(
                  label: ReconnectPreference.ratherAvoid.shortLabel,
                  color: ReconnectPreference.ratherAvoid.color,
                  selected: contact.preference == ReconnectPreference.ratherAvoid,
                  onTap: () => onPreferenceChanged(ReconnectPreference.ratherAvoid),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Available in: ${contact.availableIn.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
