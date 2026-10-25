import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../services/backend/reconnect_api_client.dart';
import '../theme/reconnect_theme.dart';
import 'adaptive_buttons.dart';

enum VerificationKind { phone, email }

/// Enter-the-code verification for a phone number or email address: sends a
/// code on request, confirms it, and reflects the verified state.
class VerificationPanel extends StatefulWidget {
  const VerificationPanel({
    super.key,
    required this.kind,
    required this.appState,
    required this.destination,
    required this.verified,
  });

  final VerificationKind kind;
  final ReconnectAppState appState;

  /// The phone number or email address being verified (display only).
  final String destination;
  final bool verified;

  @override
  State<VerificationPanel> createState() => _VerificationPanelState();
}

class _VerificationPanelState extends State<VerificationPanel> {
  final _codeController = TextEditingController();
  // The server sends the phone code at sign-up, so that panel opens on the
  // code field; email codes are sent on request.
  late bool _codeSent = widget.kind == VerificationKind.phone;
  bool _busy = false;
  String? _error;
  String? _notice;

  bool get _isPhone => widget.kind == VerificationKind.phone;
  String get _noun => _isPhone ? 'phone number' : 'email';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? successNotice}) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (mounted) setState(() => _notice = successNotice);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() {
    return _run(
      () async {
        if (_isPhone) {
          await widget.appState.sendPhoneVerification();
        } else {
          await widget.appState.sendEmailVerification();
        }
        if (mounted) setState(() => _codeSent = true);
      },
      successNotice: 'Code sent. It can take a minute to arrive.',
    );
  }

  Future<void> _confirm() {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return Future.value();
    }
    return _run(() async {
      if (_isPhone) {
        await widget.appState.confirmPhoneVerification(code);
      } else {
        await widget.appState.confirmEmailVerification(code);
      }
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.verified) {
      return Container(
        key: Key('verified-${widget.kind.name}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: ReconnectColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your $_noun ${widget.destination.isEmpty ? '' : '(${widget.destination}) '}is verified.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _codeSent
                ? 'Enter the 6-digit code we sent to ${widget.destination.isEmpty ? 'your $_noun' : widget.destination}.'
                : 'We will send a 6-digit code to ${widget.destination.isEmpty ? 'your $_noun' : widget.destination}.',
          ),
          if (_codeSent) ...[
            const SizedBox(height: 8),
            TextField(
              key: Key('${widget.kind.name}-code-field'),
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Verification code', counterText: ''),
            ),
            const SizedBox(height: 8),
            AdaptiveFilledButton(
              onPressed: _busy ? null : _confirm,
              child: Text(_busy ? 'Please wait...' : 'Verify $_noun'),
            ),
          ],
          const SizedBox(height: 8),
          AdaptiveOutlinedButton(
            onPressed: _busy ? null : _send,
            child: Text(_codeSent ? 'Resend code' : 'Send code'),
          ),
          if (_notice != null) ...[
            const SizedBox(height: 8),
            Text(_notice!, style: const TextStyle(fontSize: 13, color: ReconnectColors.chipForeground)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: Key('${widget.kind.name}-verification-error'), style: const TextStyle(fontSize: 13, color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
