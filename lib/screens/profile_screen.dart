import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/avatar_circle.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.contactsImported,
    required this.contactsCount,
    required this.isImporting,
    required this.statusMessage,
    required this.onImportContacts,
    required this.onChangeLocation,
    required this.onEditProfile,
    this.onSpinWheel,
  });

  final ReconnectProfile profile;
  final bool contactsImported;
  final int contactsCount;
  final bool isImporting;
  final String? statusMessage;
  final VoidCallback onImportContacts;
  final VoidCallback onChangeLocation;
  final VoidCallback onEditProfile;
  final VoidCallback? onSpinWheel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            if (statusMessage != null) ...[
              _StatusCard(message: statusMessage!),
              const SizedBox(height: 12),
            ],
            if (!contactsImported) ...[
              _ImportCard(onImportContacts: onImportContacts, isImporting: isImporting),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  AvatarCircle(imageUrl: profile.profileImageUrl, initials: _initialOf(profile.name), size: 72),
                  const SizedBox(height: 12),
                  Text(profile.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    profile.homeCity,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _ProfileListRow(
                    emoji: '👥',
                    label: 'Contacts imported',
                    trailing: Text(
                      '$contactsCount',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ReconnectColors.mutedText),
                    ),
                    showChevron: false,
                    showDivider: true,
                    onTap: null,
                  ),
                  _ProfileListRow(
                    emoji: '📍',
                    label: 'Change home location',
                    showChevron: true,
                    showDivider: true,
                    onTap: onChangeLocation,
                  ),
                  _ProfileListRow(
                    emoji: '✏️',
                    label: 'Edit profile',
                    showChevron: true,
                    showDivider: false,
                    onTap: onEditProfile,
                  ),
                ],
              ),
            ),
            if (onSpinWheel != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onSpinWheel,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: ReconnectColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Spin the wheel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            const Text(
                              'Reach out to someone at random',
                              style: TextStyle(color: Color(0xFFCFC7BD), fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileListRow extends StatelessWidget {
  const _ProfileListRow({
    required this.emoji,
    required this.label,
    required this.showChevron,
    required this.showDivider,
    required this.onTap,
    this.trailing,
  });

  final String emoji;
  final String label;
  final bool showChevron;
  final bool showDivider;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: ReconnectColors.hairlineSoft)) : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            if (trailing != null) trailing!,
            if (showChevron)
              Icon(Icons.chevron_right_rounded, color: ReconnectColors.mutedTextStrong),
          ],
        ),
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({required this.onImportContacts, required this.isImporting});

  final VoidCallback onImportContacts;
  final bool isImporting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isImporting ? 'Importing contacts...' : 'Import contacts to get started',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          AdaptiveFilledButton.icon(
            onPressed: isImporting ? null : onImportContacts,
            icon: const Icon(Icons.people_alt_rounded),
            label: const Text('Import contacts'),
          ),
        ],
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

String _initialOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts.last[0] : '';
  return (first + second).toUpperCase();
}
