import 'package:flutter/material.dart';

import '../app_state.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.appState,
  });

  final ReconnectAppState appState;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int step = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _homeCityController = TextEditingController(text: 'Brooklyn');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _homeCityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Reconnect'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (step == 0) ...[
            Text('Reconnect with people you have not seen in a while.', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('This onboarding sets up your profile, imports contacts, and enables nearby suggestions.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() => step = 1),
              child: const Text('Start onboarding'),
            ),
          ] else if (step == 1) ...[
            Text('Create your account', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: _homeCityController, decoration: const InputDecoration(labelText: 'Home city')),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  await appState.signUp(
                    email: _emailController.text,
                    phone: _phoneController.text,
                    password: _passwordController.text,
                    name: _nameController.text,
                    bio: _bioController.text,
                    homeCity: _homeCityController.text,
                  );
                  if (mounted) {
                    setState(() => step = 2);
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              child: const Text('Create account'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                try {
                  await appState.login(
                    email: _emailController.text,
                    password: _passwordController.text,
                  );
                  if (mounted) {
                    setState(() => step = 2);
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() {});
                  }
                }
              },
              child: const Text('I already have an account'),
            ),
          ] else if (step == 2) ...[
            Text('Permissions', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('We need contacts and location so we can discover friends and suggest nearby catchups.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await appState.refreshLiveLocation();
                if (mounted) {
                  setState(() => step = 3);
                }
              },
              child: const Text('Allow location and continue'),
            ),
          ] else ...[
            Text('Import contacts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('Find who is already on Reconnect and view match results.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: appState.isImporting
                  ? null
                  : () async {
                      await appState.importContacts();
                      await appState.markOnboardingComplete();
                    },
              child: Text(appState.isImporting ? 'Importing contacts...' : 'Import contacts and finish'),
            ),
          ],
          if (appState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(appState.errorMessage!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
