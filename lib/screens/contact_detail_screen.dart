import 'package:flutter/material.dart';

import '../models.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({
    super.key,
    required this.contact,
  });

  final ReconnectContact contact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: contact.preference.color.withOpacity(0.2),
                          child: Text(
                            contact.preference.emoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Tooltip(
                                message: 'Time since last contact',
                                child: Text(
                                  contact.lastSeen,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    contact.isOnApp ? Icons.verified_outlined : Icons.person_search_outlined,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    contact.isOnApp ? 'On app' : 'Not on app',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your preference',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(contact.preference.label),
                      avatar: Text(contact.preference.emoji),
                      backgroundColor: contact.preference.color.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Available in: ${contact.availableIn.join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Suggested Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // TODO: Open conversation starters for this contact
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation starters coming soon')),
                  );
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Start Conversation'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  // TODO: Open activity suggestions for this contact
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity suggestions coming soon')),
                  );
                },
                icon: const Icon(Icons.lightbulb_outlined),
                label: const Text('Suggest Activity'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Open contact options (call, message, etc.)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact options coming soon')),
                  );
                },
                icon: const Icon(Icons.call_outlined),
                label: const Text('Contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
