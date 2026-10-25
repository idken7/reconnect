import 'package:flutter/material.dart';

import '../models.dart';
import '../services/backend/reconnect_api_client.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/avatar_circle.dart';
import '../widgets/delete_account_dialog.dart';

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
    this.isDemoMode = false,
    this.onToggleLocationShared,
    this.onVerifyPhone,
    this.onVerifyEmail,
    this.onLogout,
    this.onLogoutEverywhere,
    this.onExportData,
    this.onDeleteAccount,
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

  /// Debug-only demo mode: shows a label that the data is made up.
  final bool isDemoMode;

  /// Account and privacy actions. A row is only shown when its callback is
  /// provided. Async callbacks may throw; the message is shown to the user.
  final ValueChanged<bool>? onToggleLocationShared;
  final VoidCallback? onVerifyPhone;
  final VoidCallback? onVerifyEmail;
  final Future<void> Function()? onLogout;
  final Future<void> Function()? onLogoutEverywhere;
  final Future<void> Function()? onExportData;
  final Future<void> Function(String password)? onDeleteAccount;

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
            if (isDemoMode) ...[
              const _StatusCard(
                key: Key('demo-banner'),
                message: 'Demo mode: sample contacts on this device only. Nothing is saved or uploaded.',
              ),
              const SizedBox(height: 12),
            ],
            if (statusMessage != null) ...[
              _StatusCard(message: statusMessage!),
              const SizedBox(height: 12),
            ],
            if (!profile.phoneVerified && onVerifyPhone != null) ...[
              _VerifyCard(
                message: 'Verify your phone number to import contacts and be found by friends.',
                actionLabel: 'Verify phone',
                onPressed: onVerifyPhone!,
              ),
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
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText),
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: ReconnectColors.mutedText),
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
                    showDivider: onVerifyEmail != null && !profile.emailVerified,
                    onTap: onEditProfile,
                  ),
                  if (onVerifyEmail != null && !profile.emailVerified)
                    _ProfileListRow(
                      emoji: '✉️',
                      label: 'Verify email (optional)',
                      showChevron: true,
                      showDivider: false,
                      onTap: onVerifyEmail,
                    ),
                ],
              ),
            ),
            if (onToggleLocationShared != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: SwitchListTile(
                  key: const Key('location-sharing-switch'),
                  title: const Text('Share my city with mutual matches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text(
                    'When on, people who also have you in their contacts can see which city you are in, so you can meet up. '
                    'Only your city is shared, never your exact location. Off by default; turn it off any time.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: profile.locationShared,
                  onChanged: onToggleLocationShared,
                ),
              ),
            ],
            if (onSpinWheel != null) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onSpinWheel,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: ReconnectColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: const Row(
                    children: [
                      Icon(Icons.shuffle_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Spin the wheel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(
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
            if (onLogout != null || onDeleteAccount != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    if (onLogout != null)
                      _ProfileListRow(
                        emoji: '🚪',
                        label: 'Log out',
                        showChevron: false,
                        showDivider: true,
                        onTap: () => _runWithFeedback(context, onLogout!),
                      ),
                    if (onLogoutEverywhere != null)
                      _ProfileListRow(
                        emoji: '📱',
                        label: 'Log out everywhere',
                        showChevron: false,
                        showDivider: true,
                        onTap: () => _confirmLogoutEverywhere(context),
                      ),
                    if (onExportData != null)
                      _ProfileListRow(
                        emoji: '📦',
                        label: 'Export my data',
                        showChevron: false,
                        showDivider: onDeleteAccount != null,
                        onTap: () => _runWithFeedback(context, onExportData!),
                      ),
                    if (onDeleteAccount != null)
                      _ProfileListRow(
                        emoji: '🗑️',
                        label: 'Delete account',
                        showChevron: false,
                        showDivider: false,
                        destructive: true,
                        onTap: () => showDeleteAccountDialog(context, onDelete: onDeleteAccount!),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogoutEverywhere(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out everywhere?'),
        content: const Text('This signs you out of Reconnect on every device, including this one.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Log out everywhere')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _runWithFeedback(context, onLogoutEverywhere!);
    }
  }

  /// Runs [action]; a failure is shown in a snackbar instead of being lost.
  Future<void> _runWithFeedback(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await action();
    } catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    }
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
    this.destructive = false,
  });

  final String emoji;
  final String label;
  final bool showChevron;
  final bool showDivider;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: ReconnectColors.hairlineSoft)) : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: destructive ? Colors.red : null),
              ),
            ),
            ?trailing,
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, color: ReconnectColors.mutedTextStrong),
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

class _VerifyCard extends StatelessWidget {
  const _VerifyCard({required this.message, required this.actionLabel, required this.onPressed});

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          AdaptiveFilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.message});

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
