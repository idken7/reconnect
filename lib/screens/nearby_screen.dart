import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/adaptive_picker.dart';
import '../widgets/suggestion_deck_sheet.dart';

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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text('Nearby', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            if (statusMessage != null) ...[
              _StatusCard(message: statusMessage!),
              const SizedBox(height: 12),
            ],
            _LocationRow(
              currentLocation: currentLocation,
              supportedLocations: supportedLocations,
              isResolvingLocation: isResolvingLocation,
              onUseLiveLocation: onUseLiveLocation,
              onLocationSelected: onLocationSelected,
            ),
            const SizedBox(height: 18),
            if (!contactsImported)
              _ImportPrompt(onImportContacts: onImportContacts, isImporting: isImporting)
            else if (suggestions.isEmpty)
              _EmptyFeed(currentLocation: currentLocation)
            else ...[
              _PushBanner(top: suggestions.first),
              const SizedBox(height: 16),
              for (final suggestion in suggestions) ...[
                _NearbyCard(suggestion: suggestion),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PushBanner extends StatelessWidget {
  const _PushBanner({required this.top});

  final NearbySuggestion top;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: ReconnectColors.ink, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Text('📍', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${top.contact.name} is close by',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_distanceText(top.distanceLabel)} · you two like each other',
                  style: const TextStyle(color: Color(0xFFCFC7BD), fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => showSuggestionDeckSheet(context, contact: top.contact, kind: DeckKind.activity),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: ReconnectColors.accent, borderRadius: BorderRadius.circular(12)),
              child: const Text('Plan it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.suggestion});

  final NearbySuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final contact = suggestion.contact;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: contact.preference.color, shape: BoxShape.circle),
            child: Text(_initialOf(contact.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    Text(
                      _distanceText(suggestion.distanceLabel),
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ReconnectColors.mutedText),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    suggestion.reason,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => showSuggestionDeckSheet(context, contact: contact, kind: DeckKind.activity),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: ReconnectColors.accent, borderRadius: BorderRadius.circular(10)),
                          child: const Text(
                            'Plan activity',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.chat_bubble_rounded,
                      onTap: () => showSuggestionDeckSheet(context, contact: contact, kind: DeckKind.convo),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.call_rounded,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call feature coming soon')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 16, color: ReconnectColors.chipForeground),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.currentLocation,
    required this.supportedLocations,
    required this.isResolvingLocation,
    required this.onUseLiveLocation,
    required this.onLocationSelected,
  });

  final String currentLocation;
  final List<String> supportedLocations;
  final bool isResolvingLocation;
  final VoidCallback onUseLiveLocation;
  final ValueChanged<String> onLocationSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdaptivePicker<String>(
            label: 'Location',
            value: currentLocation,
            items: supportedLocations,
            labelBuilder: (location) => location,
            onChanged: onLocationSelected,
          ),
        ),
        const SizedBox(width: 10),
        AdaptiveOutlinedButton.icon(
          compact: true,
          onPressed: isResolvingLocation ? null : onUseLiveLocation,
          icon: const Icon(Icons.my_location_rounded, size: 16),
          label: Text(isResolvingLocation ? 'Locating…' : 'Live'),
        ),
      ],
    );
  }
}

class _ImportPrompt extends StatelessWidget {
  const _ImportPrompt({required this.onImportContacts, required this.isImporting});

  final VoidCallback onImportContacts;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Import contacts to see nearby people.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AdaptiveFilledButton(
            onPressed: isImporting ? null : onImportContacts,
            child: Text(isImporting ? 'Importing contacts...' : 'Import contacts'),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.currentLocation});

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Text(
        'No suggested meetups in $currentLocation right now. Try another nearby area.',
        style: TextStyle(fontWeight: FontWeight.w600, color: ReconnectColors.mutedText),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(14)),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

String _distanceText(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return 'Nearby';
  if (trimmed.endsWith('away') || trimmed == 'Nearby') return trimmed;
  if (trimmed.startsWith('Under ')) return '<${trimmed.substring('Under '.length)} away';
  return '$trimmed away';
}

String _initialOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts.last[0] : '';
  return (first + second).toUpperCase();
}
