import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/app_state.dart';
import 'package:reconnect/screens/onboarding_flow.dart';
import 'package:reconnect/services/backend/reconnect_api_client.dart';
import 'package:reconnect/services/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

Future<ReconnectAppState> pumpOnboarding(
  WidgetTester tester, {
  FakeApiClient? api,
  bool demoAvailable = false,
  InMemorySessionStore? store,
}) async {
  SharedPreferences.setMockInitialValues({LegacyTokenMigration.initializedKey: true});
  // A tall surface so the whole (lazily built) form is on screen.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final appState = ReconnectAppState(
    apiClient: api ?? FakeApiClient(),
    contactImportService: const FakeContactImportService(),
    liveLocationService: const FakeLiveLocationService(),
    sessionStore: store ?? InMemorySessionStore(),
    demoAvailable: demoAvailable,
  );
  addTearDown(appState.dispose);
  await tester.pumpWidget(MaterialApp(home: OnboardingFlow(appState: appState)));
  await tester.pump(const Duration(milliseconds: 100));
  return appState;
}

Future<void> fillAndCreateAccount(WidgetTester tester) async {
  await tester.tap(find.text('Start onboarding'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Sam Rivera');
  await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sam@example.com');
  await tester.enterText(find.widgetWithText(TextField, 'Phone'), '4155550124');
  await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse');
  await tester.ensureVisible(find.text('Create account'));
  await tester.tap(find.text('Create account'));
  await tester.pumpAndSettle();
}

void main() {
  group('demo entry point', () {
    testWidgets('Try demo is hidden when demo is not available (release builds)', (tester) async {
      await pumpOnboarding(tester);
      expect(find.text('Try demo'), findsNothing);
    });

    testWidgets('Try demo is offered, labeled, when demo is available', (tester) async {
      final appState = await pumpOnboarding(tester, demoAvailable: true);
      expect(find.text('Try demo'), findsOneWidget);
      expect(find.textContaining('made-up sample contacts'), findsOneWidget);

      await tester.tap(find.text('Try demo'));
      await tester.pump();
      expect(appState.isDemoMode, isTrue);
    });
  });

  group('verification before contact import', () {
    testWidgets('sign-up leads to phone verification, then the permission explanation', (tester) async {
      final api = FakeApiClient();
      final appState = await pumpOnboarding(tester, api: api);

      await fillAndCreateAccount(tester);

      expect(api.calls, contains('signUp'));
      expect(find.text('Verify your phone'), findsOneWidget);
      expect(find.textContaining('+14155550124'), findsWidgets);
      // Cannot continue before verifying.
      final continueButton = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('phone-code-field')), '123456');
      await tester.ensureVisible(find.text('Verify phone number'));
      await tester.tap(find.text('Verify phone number'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('confirmPhoneVerification'));
      expect(appState.profile.phoneVerified, isTrue);
      expect(find.byKey(const Key('verified-phone')), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      // Pre-permission explanation of location use, with the consent toggle off.
      expect(find.text('How your location is used'), findsOneWidget);
      expect(find.text('Let mutual matches see my city'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('onboarding-location-shared'))).value, isFalse);
    });

    testWidgets('a wrong code shows the server message and stays on the step', (tester) async {
      final api = FakeApiClient()
        ..failures['confirmPhoneVerification'] =
            const ReconnectApiException(statusCode: 400, code: 'validation_error', message: 'That code is not valid.');
      await pumpOnboarding(tester, api: api);
      await fillAndCreateAccount(tester);

      await tester.enterText(find.byKey(const Key('phone-code-field')), '000001');
      await tester.ensureVisible(find.text('Verify phone number'));
      await tester.tap(find.text('Verify phone number'));
      await tester.pumpAndSettle();

      expect(find.text('That code is not valid.'), findsOneWidget);
      expect(find.text('Verify your phone'), findsOneWidget);
    });

    testWidgets('the code must be six digits', (tester) async {
      final api = FakeApiClient();
      await pumpOnboarding(tester, api: api);
      await fillAndCreateAccount(tester);

      await tester.enterText(find.byKey(const Key('phone-code-field')), '123');
      await tester.ensureVisible(find.text('Verify phone number'));
      await tester.tap(find.text('Verify phone number'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
      expect(api.calls, isNot(contains('confirmPhoneVerification')));
    });

    testWidgets('resend sends another code and a 429 is explained', (tester) async {
      final api = FakeApiClient();
      await pumpOnboarding(tester, api: api);
      await fillAndCreateAccount(tester);

      await tester.ensureVisible(find.text('Resend code').first);
      await tester.tap(find.text('Resend code').first);
      await tester.pumpAndSettle();
      expect(api.calls, contains('sendPhoneVerification'));
      expect(find.textContaining('Code sent'), findsOneWidget);

      api.failures['sendPhoneVerification'] =
          const ReconnectApiException(statusCode: 429, code: 'rate_limited', message: 'x', retryAfterSeconds: 45);
      await tester.tap(find.text('Resend code').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Too many attempts. Please try again in 45 seconds.'), findsOneWidget);
    });

    testWidgets('an already verified account skips straight past verification after login', (tester) async {
      final api = FakeApiClient(); // dashboard profile is verified
      await pumpOnboarding(tester, api: api);

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sam@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse');
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your phone'), findsNothing);
      expect(find.text('How your location is used'), findsOneWidget);
    });

    testWidgets('a failed sign-up shows the friendly error and stays on the form', (tester) async {
      final api = FakeApiClient()
        ..failures['signUp'] = const ReconnectApiException(statusCode: 409, code: 'account_exists', message: 'x');
      await pumpOnboarding(tester, api: api);

      await fillAndCreateAccount(tester);

      expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
      expect(find.textContaining('already exists'), findsOneWidget);
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('an offline sign-up says so', (tester) async {
      final api = FakeApiClient()..failures['signUp'] = const ReconnectApiException.network();
      await pumpOnboarding(tester, api: api);

      await fillAndCreateAccount(tester);

      expect(find.textContaining('Unable to reach Reconnect'), findsOneWidget);
    });
  });

  group('contacts step', () {
    testWidgets('explains what is uploaded before importing, and can be skipped', (tester) async {
      final api = FakeApiClient();
      final appState = await pumpOnboarding(tester, api: api);

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sam@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse');
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('What happens to your contacts'), findsOneWidget);
      expect(find.textContaining('one-way, keyed hash'), findsOneWidget);
      expect(find.textContaining('sends them to our server'), findsOneWidget);

      await tester.ensureVisible(find.text('Skip for now'));
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(appState.onboardingComplete, isTrue);
      expect(api.calls, isNot(contains('importContacts')));
    });

    testWidgets('a 403 verification_required during import returns to verification', (tester) async {
      final api = FakeApiClient()
        ..failures['importContacts'] = const ReconnectApiException(statusCode: 403, code: 'verification_required', message: 'x');
      await pumpOnboarding(tester, api: api);

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sam@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse');
      await tester.ensureVisible(find.text('I already have an account'));
      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Import contacts and finish'));
      await tester.tap(find.text('Import contacts and finish'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your phone'), findsOneWidget);
      expect(find.textContaining('verify your phone'), findsWidgets);
    });
  });
}
