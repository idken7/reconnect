import 'package:flutter/material.dart';

import '../models.dart';

class NearbyScreen extends StatelessWidget {
  const NearbyScreen({
    super.key,
    required this.contactsImported,
    required this.currentLocation,
    required this.supportedLocations,
    required this.suggestions,
    required this.isResolvingLocation,
    required this.isImporting,
    required this.statusMessage,
    required this.onUseLiveLocation,
    required this.onLocationSelected,
    required this.onImportContacts,
  });

  final bool contactsImported;
  final String currentLocation;
  final List<String> supportedLocations;
  final List<NearbySuggestion> suggestions;
  final bool isResolvingLocation;
  final bool isImporting;
  final String? statusMessage;
  final VoidCallback onUseLiveLocation;
  final ValueChanged<String> onLocationSelected;
  final VoidCallback onImportContacts;

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
          'Catch up nearby',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Live geolocation now drives nearby suggestions. If permission is unavailable, you can use a fallback location.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current location: $currentLocation', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: isResolvingLocation ? null : onUseLiveLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(isResolvingLocation ? 'Refreshing location...' : 'Use live location now'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LocationSelector(
          currentLocation: currentLocation,
          supportedLocations: supportedLocations,
          onLocationSelected: onLocationSelected,
        ),
        const SizedBox(height: 16),
        if (!contactsImported)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Import contacts to see nearby people.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: isImporting ? null : onImportContacts,
                    child: Text(isImporting ? 'Importing contacts...' : 'Import contacts'),
                  ),
                ],
              ),
            ),
          )
        else if (suggestions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No suggested meetups in $currentLocation right now. Try another nearby area.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
        else
          for (final suggestion in suggestions) ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.people_alt_outlined)),
                title: Text(suggestion.contact.name),
                subtitle: Text('${suggestion.distanceLabel}\n${suggestion.reason}'),
                isThreeLine: true,
                trailing: Text(suggestion.contact.preference.shortLabel),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({
    required this.currentLocation,
    required this.supportedLocations,
    required this.onLocationSelected,
  });

  final String currentLocation;
  final List<String> supportedLocations;
  final ValueChanged<String> onLocationSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: currentLocation,
              items: supportedLocations
                  .map(
                    (location) => DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onLocationSelected(value);
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Current city or neighborhood',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
