import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/backend/reconnect_api_client.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/adaptive_scaffold.dart';

/// Two-step password reset: request a code by email, then enter the code and
/// a new password. The server always answers the request the same way, so
/// this screen never says whether an account exists.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.appState,
    this.initialEmail = '',
  });

  final ReconnectAppState appState;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeRequested = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter the email address for your account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.appState.requestPasswordReset(email: email);
      if (mounted) setState(() => _codeRequested = true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_codeController.text.trim().isEmpty || _passwordController.text.length < 8) {
      setState(() => _error = 'Enter the code and a new password of at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.appState.confirmPasswordReset(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated. Log in with your new password.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Reset password',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _codeRequested ? 'Check your email' : 'Forgot your password?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            _codeRequested
                ? 'If an account exists for ${_emailController.text.trim()}, we sent a code to it. '
                    'Enter the code and choose a new password. This signs you out everywhere.'
                : 'Enter your account email and we will send you a code to reset it.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: !_codeRequested,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          if (_codeRequested) ...[
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters.'),
            ),
          ],
          const SizedBox(height: 16),
          AdaptiveFilledButton(
            onPressed: _busy ? null : (_codeRequested ? _confirmReset : _requestCode),
            child: Text(_busy ? 'Please wait...' : (_codeRequested ? 'Set new password' : 'Send code')),
          ),
          if (_codeRequested) ...[
            const SizedBox(height: 8),
            AdaptiveOutlinedButton(
              onPressed: _busy ? null : () => setState(() => _codeRequested = false),
              child: const Text('Use a different email'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('forgot-password-error'), style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
