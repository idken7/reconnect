import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/verification_panel.dart';

/// Standalone phone/email verification, opened from Profile for accounts that
/// skipped or have not finished verification.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key, required this.appState, required this.kind});

  final ReconnectAppState appState;
  final VerificationKind kind;

  @override
  Widget build(BuildContext context) {
    final isPhone = kind == VerificationKind.phone;
    return AdaptiveScaffold(
      title: isPhone ? 'Verify phone' : 'Verify email',
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final profile = appState.profile;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isPhone
                    ? 'Reconnect only matches verified phone numbers, so nobody can claim a number that is not theirs.'
                    : 'Verifying your email lets friends who only have your email find you.',
              ),
              const SizedBox(height: 16),
              VerificationPanel(
                kind: kind,
                appState: appState,
                destination: isPhone ? profile.phone : profile.email,
                verified: isPhone ? profile.phoneVerified : profile.emailVerified,
              ),
            ],
          );
        },
      ),
    );
  }
}
