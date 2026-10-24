import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/adaptive_scaffold.dart';

/// Shown when the signed-in user's data cannot be loaded (offline, server
/// error). It never shows placeholder contacts; the user can retry or log out.
class LoadErrorScreen extends StatelessWidget {
  const LoadErrorScreen({super.key, required this.appState});

  final ReconnectAppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => AdaptiveScaffold(
        title: 'Reconnect',
        showBackButton: false,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: ReconnectColors.mutedTextStrong),
                const SizedBox(height: 16),
                Text(
                  'Can\'t load your data',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  appState.errorMessage ?? 'Check your connection and try again.',
                  key: const Key('load-error-message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AdaptiveFilledButton(
                  onPressed: appState.isRetrying ? null : appState.retryLoad,
                  child: Text(appState.isRetrying ? 'Retrying...' : 'Retry'),
                ),
                const SizedBox(height: 8),
                AdaptiveOutlinedButton(
                  onPressed: appState.isRetrying ? null : appState.logout,
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
