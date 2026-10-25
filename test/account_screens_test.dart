import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/app.dart';
import 'package:reconnect/app_state.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/forgot_password_screen.dart';
import 'package:reconnect/screens/load_error_screen.dart';
import 'package:reconnect/screens/profile_screen.dart';
import 'package:reconnect/services/backend/reconnect_api_client.dart';
import 'package:reconnect/services/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

StoredSession validSession() => StoredSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      accessTokenExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );

ReconnectAppState signedInState(FakeApiClient api, InMemorySessionStore store) {
  SharedPreferences.setMockInitialValues({
    LegacyTokenMigration.initializedKey: true,
    'reconnect_onboarding_complete': true,
  });
  final state = ReconnectAppState(
    apiClient: api,
    contactImportService: const FakeContactImportService(),
    liveLocationService: const FakeLiveLocationService(),
    sessionStore: store,
    demoAvailable: false,
  );
  addTearDown(state.dispose);
  return state;
}

Widget profileScreen({
  ReconnectProfile? profile,
  bool isDemoMode = false,
  Future<void> Function()? onLogout,
  Future<void> Function()? onLogoutEverywhere,
  Future<void> Function(String)? onDeleteAccount,
  ValueChanged<bool>? onToggleLocationShared,
  VoidCallback? onVerifyPhone,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProfileScreen(
        profile: profile ?? verifiedProfile,
        contactsImported: true,
        contactsCount: 2,
        isImporting: false,
        statusMessage: null,
        onImportContacts: () {},
        onChangeLocation: () {},
        onEditProfile: () {},
        isDemoMode: isDemoMode,
        onLogout: onLogout,
        onLogoutEverywhere: onLogoutEverywhere,
        onDeleteAccount: onDeleteAccount,
        onToggleLocationShared: onToggleLocationShared,
        onVerifyPhone: onVerifyPhone,
      ),
    ),
  );
}

void main() {
  group('Profile account actions', () {
    testWidgets('shows log out, log out everywhere and delete account', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        profileScreen(onLogout: () async {}, onLogoutEverywhere: () async {}, onDeleteAccount: (_) async {}),
      );

      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Log out everywhere'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('account actions are hidden when no callbacks are given', (tester) async {
      await tester.pumpWidget(profileScreen());
      expect(find.text('Log out'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('log out everywhere asks for confirmation first', (tester) async {
      useTallSurface(tester);
      var called = 0;
      await tester.pumpWidget(profileScreen(onLogout: () async {}, onLogoutEverywhere: () async => called++));

      await tester.tap(find.text('Log out everywhere'));
      await tester.pumpAndSettle();
      expect(find.text('Log out everywhere?'), findsOneWidget);
      expect(called, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(called, 0);

      await tester.tap(find.text('Log out everywhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Log out everywhere')));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('a failed log out everywhere is reported, not swallowed', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        profileScreen(
          onLogout: () async {},
          onLogoutEverywhere: () async => throw const ReconnectApiException.network(),
        ),
      );

      await tester.tap(find.text('Log out everywhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Log out everywhere')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to reach Reconnect'), findsOneWidget);
    });

    testWidgets('delete account requires a password and keeps the dialog open on a wrong one', (tester) async {
      useTallSurface(tester);
      final attempts = <String>[];
      await tester.pumpWidget(
        profileScreen(
          onLogout: () async {},
          onDeleteAccount: (password) async {
            attempts.add(password);
            throw const ReconnectApiException(statusCode: 401, code: 'invalid_credentials', message: 'x');
          },
        ),
      );

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);

      // No password: nothing is sent.
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete account')));
      await tester.pumpAndSettle();
      expect(attempts, isEmpty);
      expect(find.text('Enter your password to confirm.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('delete-account-password')), 'wrong-password');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete account')));
      await tester.pumpAndSettle();

      expect(attempts, ['wrong-password']);
      expect(find.text('That password is not correct.'), findsOneWidget);
      expect(find.text('Delete your account?'), findsOneWidget);
    });

    testWidgets('delete account closes the dialog on success', (tester) async {
      useTallSurface(tester);
      String? deletedWith;
      await tester.pumpWidget(
        profileScreen(onLogout: () async {}, onDeleteAccount: (password) async => deletedWith = password),
      );

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('delete-account-password')), 'right-password');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete account')));
      await tester.pumpAndSettle();

      expect(deletedWith, 'right-password');
      expect(find.text('Delete your account?'), findsNothing);
    });

    testWidgets('location sharing switch reflects the profile and reports changes', (tester) async {
      useTallSurface(tester);
      bool? toggled;
      await tester.pumpWidget(profileScreen(onToggleLocationShared: (value) => toggled = value));

      final switchFinder = find.byKey(const Key('location-sharing-switch'));
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
      expect(find.textContaining('never your exact location'), findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pump();
      expect(toggled, isTrue);
    });

    testWidgets('unverified phones get a verify prompt', (tester) async {
      useTallSurface(tester);
      var tapped = false;
      await tester.pumpWidget(profileScreen(profile: unverifiedProfile, onVerifyPhone: () => tapped = true));

      await tester.tap(find.text('Verify phone'));
      expect(tapped, isTrue);
    });

    testWidgets('demo mode is labeled', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(profileScreen(isDemoMode: true));
      expect(find.byKey(const Key('demo-banner')), findsOneWidget);
    });
  });

  group('offline and error states', () {
    testWidgets('an unreachable backend shows an error state with retry, never demo contacts', (tester) async {
      useTallSurface(tester);
      final api = FakeApiClient(dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan Real')], contactsImported: true))
        ..failures['fetchDashboard'] = const ReconnectApiException.network();
      final state = signedInState(api, InMemorySessionStore(validSession()));

      await tester.pumpWidget(ReconnectApp(appState: state));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(LoadErrorScreen), findsOneWidget);
      expect(find.text('Can\'t load your data'), findsOneWidget);
      expect(find.textContaining('Unable to reach Reconnect'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      // No placeholder people.
      expect(find.text('Jordan Patel'), findsNothing);
      expect(find.text('Maya Chen'), findsNothing);
      expect(find.text('Jordan Real'), findsNothing);
    });

    testWidgets('Retry reloads and shows the real data when the backend is back', (tester) async {
      useTallSurface(tester);
      final api = FakeApiClient(dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan Real')], contactsImported: true))
        ..failures['fetchDashboard'] = const ReconnectApiException.network();
      final state = signedInState(api, InMemorySessionStore(validSession()));
      await tester.pumpWidget(ReconnectApp(appState: state));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(LoadErrorScreen), findsOneWidget);

      api.failures.clear();
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LoadErrorScreen), findsNothing);
      expect(state.contacts.single.name, 'Jordan Real');
      expect(find.text('Jordan Real'), findsWidgets);
    });

    testWidgets('Log out from the error state signs out', (tester) async {
      useTallSurface(tester);
      final api = FakeApiClient()..failures['fetchDashboard'] = const ReconnectApiException.network();
      final store = InMemorySessionStore(validSession());
      final state = signedInState(api, store);
      await tester.pumpWidget(ReconnectApp(appState: state));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Log out'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.isAuthenticated, isFalse);
      expect(await store.read(), isNull);
      expect(find.text('Start onboarding'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('request code then set a new password', (tester) async {
      useTallSurface(tester);
      final api = FakeApiClient();
      SharedPreferences.setMockInitialValues({LegacyTokenMigration.initializedKey: true});
      final state = ReconnectAppState(apiClient: api, sessionStore: InMemorySessionStore());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(appState: state, initialEmail: 'sam@example.com')),
      );
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('requestPasswordReset'));
      expect(find.text('Check your email'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Code'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'New password'), 'a brand new password');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();

      expect(api.calls, contains('confirmPasswordReset'));
    });

    testWidgets('a 429 on request is explained', (tester) async {
      final api = FakeApiClient()
        ..failures['requestPasswordReset'] =
            const ReconnectApiException(statusCode: 429, code: 'rate_limited', message: 'x', retryAfterSeconds: 120);
      SharedPreferences.setMockInitialValues({LegacyTokenMigration.initializedKey: true});
      final state = ReconnectAppState(apiClient: api, sessionStore: InMemorySessionStore());
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(appState: state, initialEmail: 'sam@example.com')),
      );
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.text('Forgot your password?'), findsOneWidget);
    });
  });

  group('SecureSessionStore', () {
    test('round-trips and clears tokens', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SecureSessionStore();

      expect(await store.read(), isNull);
      await store.write(
        StoredSession(accessToken: 'a', refreshToken: 'r', accessTokenExpiresAt: DateTime.utc(2099)),
      );

      final stored = await store.read();
      expect(stored?.accessToken, 'a');
      expect(stored?.refreshToken, 'r');
      expect(stored?.accessTokenExpiresAt, DateTime.utc(2099));

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('migration end to end with the real secure store', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        'reconnect_auth_token': 'legacy-a',
        'reconnect_refresh_token': 'legacy-r',
      });
      final prefs = await SharedPreferences.getInstance();
      const store = SecureSessionStore();

      await LegacyTokenMigration.run(prefs, store);

      expect((await store.read())?.refreshToken, 'legacy-r');
      expect(prefs.getString('reconnect_auth_token'), isNull);
      expect(prefs.getString('reconnect_refresh_token'), isNull);
    });
  });
}
