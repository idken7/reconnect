import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/adaptive_picker.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/avatar_circle.dart';

const _bioMaxLength = 160;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.supportedLocations,
    required this.onSave,
    this.onSaveProfile,
  });

  final ReconnectProfile profile;
  final List<String> supportedLocations;
  final Function(String bio, String homeCity) onSave;
  final Function(String bio, String homeCity, String profileImageUrl)? onSaveProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _bioController;
  late TextEditingController _profileImageController;
  late String _selectedCity;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.profile.bio);
    _profileImageController = TextEditingController(text: widget.profile.profileImageUrl);
    _selectedCity = widget.profile.homeCity;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_bioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bio cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final imageUrl = _profileImageController.text.trim();
      if (widget.onSaveProfile != null) {
        await widget.onSaveProfile!(_bioController.text.trim(), _selectedCity, imageUrl);
      } else {
        await widget.onSave(_bioController.text.trim(), _selectedCity);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Edit profile',
      showBackButton: !_isSaving,
      backgroundColor: ReconnectColors.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: AvatarCircle(
              imageUrl: _profileImageController.text.trim(),
              initials: _initialOf(widget.profile.name),
              size: 84,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              widget.profile.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              '${widget.profile.email} • ${widget.profile.phone}',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ReconnectColors.mutedText),
            ),
          ),
          const SizedBox(height: 24),
          Text('Profile picture URL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ReconnectColors.ink)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('profileImageField'),
            controller: _profileImageController,
            decoration: const InputDecoration(hintText: 'https://…'),
            keyboardType: TextInputType.url,
            enabled: !_isSaving,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: ReconnectColors.ink)),
              Text(
                '${_bioController.text.length}/$_bioMaxLength',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: ReconnectColors.mutedTextStrong),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('bioField'),
            controller: _bioController,
            decoration: const InputDecoration(hintText: 'A little about you'),
            maxLength: _bioMaxLength,
            maxLines: 3,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            enabled: !_isSaving,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 20),
          AdaptivePicker<String>(
            label: 'Home city',
            value: _selectedCity,
            items: widget.supportedLocations,
            labelBuilder: (location) => location,
            enabled: !_isSaving,
            onChanged: (value) => setState(() => _selectedCity = value),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: AdaptiveOutlinedButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AdaptiveFilledButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
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
