import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/reconnect_theme.dart';
import '../widgets/adaptive_buttons.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/verification_panel.dart';
import 'forgot_password_screen.dart';

enum _Stage { welcome, account, verify, permissions, contacts }

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
  late _Stage stage;
  bool _busy = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _homeCityController = TextEditingController(text: 'Brooklyn');

  @override
  void initState() {
    super.initState();
    // Resume where an interrupted sign-up left off (signed in, not finished).
    final appState = widget.appState;
    if (appState.isAuthenticated && !appState.isDemoMode) {
      stage = appState.profile.phoneVerified ? _Stage.permissions : _Stage.verify;
    } else {
      stage = _Stage.welcome;
    }
  }

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

  void _goTo(_Stage next) => setState(() => stage = next);

  /// After signing in: unverified accounts must verify before contact import.
  void _afterSignIn() {
    if (!mounted) return;
    _goTo(widget.appState.profile.phoneVerified ? _Stage.permissions : _Stage.verify);
  }

  Future<void> _submitAccount({required bool signUp}) async {
    final appState = widget.appState;
    setState(() => _busy = true);
    try {
      if (signUp) {
        await appState.signUp(
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          homeCity: _homeCityController.text.trim(),
        );
      } else {
        await appState.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      _afterSignIn();
    } catch (_) {
      // The error is shown from appState.errorMessage.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importAndFinish() async {
    final appState = widget.appState;
    await appState.importContacts();
    if (!mounted) return;
    if (!appState.profile.phoneVerified) {
      _goTo(_Stage.verify);
    } else if (appState.contactsImported) {
      await appState.markOnboardingComplete();
    }
    // Otherwise the import failed: stay here, the error card explains why.
  }

  int get _dotIndex => switch (stage) {
        _Stage.welcome => 0,
        _Stage.account => 1,
        _Stage.verify => 2,
        _Stage.permissions => 3,
        _Stage.contacts => 4,
      };

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    return AdaptiveScaffold(
      title: 'Welcome to Reconnect',
      showBackButton: false,
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (stage != _Stage.welcome) ...[
              _OnboardingDots(activeStep: _dotIndex, totalSteps: 4),
              const SizedBox(height: 16),
            ],
            ...switch (stage) {
              _Stage.welcome => _welcome(context),
              _Stage.account => _account(context),
              _Stage.verify => _verify(context),
              _Stage.permissions => _permissions(context),
              _Stage.contacts => _contacts(context),
            },
            if (appState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(appState.errorMessage!, key: const Key('onboarding-error')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _welcome(BuildContext context) {
    final appState = widget.appState;
    return [
      Text('Reconnect with people you have not seen in a while.', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('This onboarding sets up your profile, verifies your phone, imports contacts, and enables nearby suggestions.'),
      const SizedBox(height: 20),
      AdaptiveFilledButton(
        onPressed: () {
          appState.clearError();
          _goTo(_Stage.account);
        },
        child: const Text('Start onboarding'),
      ),
      const SizedBox(height: 8),
      AdaptiveOutlinedButton(
        onPressed: () {
          appState.clearError();
          _goTo(_Stage.account);
        },
        child: const Text('Log in'),
      ),
      if (appState.demoAvailable) ...[
        const SizedBox(height: 24),
        AdaptiveOutlinedButton(
          onPressed: appState.startDemo,
          child: const Text('Try demo'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Debug builds only: browse made-up sample contacts on this device. No account is created.',
          style: TextStyle(fontSize: 12, color: ReconnectColors.mutedText),
        ),
      ],
    ];
  }

  List<Widget> _account(BuildContext context) {
    return [
      Text('Create your account', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: const InputDecoration(
          labelText: 'Phone',
          helperText: 'US numbers work as-is. Otherwise start with + and your country code.',
        ),
      ),
      TextField(
        controller: _passwordController,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters.'),
      ),
      TextField(controller: _homeCityController, decoration: const InputDecoration(labelText: 'Home city')),
      TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio')),
      const SizedBox(height: 16),
      AdaptiveFilledButton(
        onPressed: _busy ? null : () => _submitAccount(signUp: true),
        child: Text(_busy ? 'Please wait...' : 'Create account'),
      ),
      const SizedBox(height: 8),
      AdaptiveOutlinedButton(
        onPressed: _busy ? null : () => _submitAccount(signUp: false),
        child: const Text('I already have an account'),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _busy
              ? null
              : () {
                  widget.appState.clearError();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ForgotPasswordScreen(
                        appState: widget.appState,
                        initialEmail: _emailController.text.trim(),
                      ),
                    ),
                  );
                },
          child: const Text('Forgot password?'),
        ),
      ),
    ];
  }

  List<Widget> _verify(BuildContext context) {
    final appState = widget.appState;
    final profile = appState.profile;
    return [
      Text('Verify your phone', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text(
        'Reconnect only matches verified phone numbers, so nobody can claim a number that is not theirs '
        'and see who has it in their contacts. You need to verify before importing contacts.',
      ),
      const SizedBox(height: 16),
      VerificationPanel(
        kind: VerificationKind.phone,
        appState: appState,
        destination: profile.phone,
        verified: profile.phoneVerified,
      ),
      const SizedBox(height: 20),
      Text('Email (optional)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('Verifying your email also lets friends who only have your email find you.'),
      const SizedBox(height: 12),
      VerificationPanel(
        kind: VerificationKind.email,
        appState: appState,
        destination: profile.email,
        verified: profile.emailVerified,
      ),
      const SizedBox(height: 20),
      AdaptiveFilledButton(
        onPressed: profile.phoneVerified ? () => _goTo(_Stage.permissions) : null,
        child: const Text('Continue'),
      ),
    ];
  }

  List<Widget> _permissions(BuildContext context) {
    final appState = widget.appState;
    return [
      Text('Location', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const _ExplainerCard(
        icon: Icons.location_on_outlined,
        title: 'How your location is used',
        lines: [
          'Reconnect uses your approximate location to work out which city you are in, so it can suggest friends who are nearby.',
          'Only your city is stored, not a trail of exact locations.',
        ],
      ),
      const SizedBox(height: 12),
      SwitchListTile(
        key: const Key('onboarding-location-shared'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Let mutual matches see my city'),
        subtitle: const Text(
          'Off by default. Only people who also have you in their contacts could see it. '
          'You can change this any time in Profile.',
        ),
        value: appState.profile.locationShared,
        onChanged: (value) => appState.setLocationShared(value),
      ),
      const SizedBox(height: 12),
      AdaptiveFilledButton(
        onPressed: appState.isResolvingLocation
            ? null
            : () async {
                await appState.refreshLiveLocation();
                if (mounted) _goTo(_Stage.contacts);
              },
        child: Text(appState.isResolvingLocation ? 'Finding your city...' : 'Allow location and continue'),
      ),
      const SizedBox(height: 8),
      AdaptiveOutlinedButton(
        onPressed: () => _goTo(_Stage.contacts),
        child: const Text('Not now'),
      ),
    ];
  }

  List<Widget> _contacts(BuildContext context) {
    final appState = widget.appState;
    return [
      Text('Import contacts', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const _ExplainerCard(
        icon: Icons.people_alt_outlined,
        title: 'What happens to your contacts',
        lines: [
          'Reconnect reads the names, phone numbers and emails in your address book and sends them to our server over an encrypted connection.',
          'The server keeps only a one-way, keyed hash of each phone number and email, plus the name you already have saved, so it can tell who is already on Reconnect.',
          'Nobody in your contacts is messaged, and who you would rather avoid is never shown to them.',
          'You can delete everything at any time with Delete account in Profile.',
        ],
      ),
      const SizedBox(height: 16),
      AdaptiveFilledButton(
        onPressed: appState.isImporting ? null : _importAndFinish,
        child: Text(appState.isImporting ? 'Importing contacts...' : 'Import contacts and finish'),
      ),
      const SizedBox(height: 8),
      AdaptiveOutlinedButton(
        onPressed: appState.isImporting ? null : appState.markOnboardingComplete,
        child: const Text('Skip for now'),
      ),
    ];
  }
}

/// A titled card of plain-language bullet points used for the pre-permission
/// explanations.
class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard({required this.icon, required this.title, required this.lines});

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ReconnectColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Step-progress dots for onboarding steps 1-4: the active dot grows and
/// darkens, passed dots stay dark, and upcoming ones stay light.
class _OnboardingDots extends StatelessWidget {
  const _OnboardingDots({required this.activeStep, required this.totalSteps});

  final int activeStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= totalSteps; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: i == activeStep ? 22 : 8,
            height: 6,
            decoration: BoxDecoration(
              color: i <= activeStep ? ReconnectColors.ink : ReconnectColors.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}
