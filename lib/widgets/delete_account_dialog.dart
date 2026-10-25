import 'package:flutter/material.dart';

import '../services/backend/reconnect_api_client.dart';

/// Confirms account deletion and collects the password the server requires.
/// [onDelete] should throw if the deletion failed; the message is shown in
/// the dialog and the dialog stays open so the user can retry.
Future<void> showDeleteAccountDialog(
  BuildContext context, {
  required Future<void> Function(String password) onDelete,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteAccountDialog(onDelete: onDelete),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.onDelete});

  final Future<void> Function(String password) onDelete;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDelete(_passwordController.text);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ReconnectApiException && error.code == 'invalid_credentials'
            ? 'That password is not correct.'
            : friendlyErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your profile, your imported contacts, your preferences and all of your '
              'sessions from Reconnect. It cannot be undone, and all data on this device is removed too.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delete-account-password'),
              controller: _passwordController,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('delete-account-error'), style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(_busy ? 'Deleting...' : 'Delete account'),
        ),
      ],
    );
  }
}
