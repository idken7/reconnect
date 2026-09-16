import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/suggestion_deck_sheet.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key, required this.contact});

  final ReconnectContact contact;

  @override
  Widget build(BuildContext context) {
    final tier = contact.preference.tierStyle;
    return Scaffold(
      backgroundColor: ReconnectColors.background,
      appBar: AppBar(title: Text(contact.name)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              AvatarCircle(
                imageUrl: '',
                initials: _initialOf(contact.name),
                size: 88,
                background: tier.color,
                fontSize: 30,
              ),
              const SizedBox(height: 14),
              Text(contact.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: contact.isOnApp ? const Color(0xFF3F9E6B) : ReconnectColors.mutedTextStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      contact.isOnApp ? 'On Reconnect' : 'Not on Reconnect',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ReconnectColors.chipForeground),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Text('Your preference', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ReconnectColors.mutedText)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: tier.background,
                        border: Border.all(color: tier.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(contact.preference.emoji, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            contact.preference.shortLabel,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: tier.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Text('📍', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available in', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: ReconnectColors.mutedText)),
                          const SizedBox(height: 2),
                          Text(
                            contact.availableIn.isEmpty ? 'Not shared' : contact.availableIn.join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _DetailActionButton(
                label: 'Start conversation',
                filled: true,
                onTap: () => showSuggestionDeckSheet(context, contact: contact, kind: DeckKind.convo),
              ),
              const SizedBox(height: 10),
              _DetailActionButton(
                label: 'Suggest activity',
                filled: false,
                onTap: () => showSuggestionDeckSheet(context, contact: contact, kind: DeckKind.activity),
              ),
              const SizedBox(height: 10),
              _DetailActionButton(
                label: 'Call or message',
                filled: false,
                icon: Icons.phone_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact options coming soon')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({required this.label, required this.filled, required this.onTap, this.icon});

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: filled ? ReconnectColors.ink : ReconnectColors.chipBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: filled ? Colors.white : ReconnectColors.chipForeground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: filled ? Colors.white : ReconnectColors.ink,
                ),
              ),
            ],
          ),
        ),
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
