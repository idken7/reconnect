import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/app_state.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/backend/reconnect_api_client.dart';
import 'package:reconnect/services/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fakes.dart';

StoredSession storedSession({String access = 'access-1', String refresh = 'refresh-1'}) {
  return StoredSession(
    accessToken: access,
    refreshToken: refresh,
    accessTokenExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
  );
}

/// Builds a state and waits for startup to finish.
Future<ReconnectAppState> startState({
  required FakeApiClient api,
  InMemorySessionStore? store,
  bool demoAvailable = false,
}) async {
  final state = ReconnectAppState(
    apiClient: api,
    contactImportService: const FakeContactImportService(),
    liveLocationService: const FakeLiveLocationService(),
    sessionStore: store ?? InMemorySessionStore(),
    demoAvailable: demoAvailable,
  );
  addTearDown(state.dispose);
  for (var i = 0; i < 50 && state.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return state;
}

const initializedPrefs = {LegacyTokenMigration.initializedKey: true};

void main() {
  group('no demo data in release', () {
    test('signed out in a release build: empty state, no auto-onboarding, no fake token', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final state = await startState(api: FakeApiClient());

      expect(state.isAuthenticated, isFalse);
      expect(state.requiresOnboarding, isTrue);
      expect(state.contacts, isEmpty);
      expect(state.matches.mutual, isEmpty);
      expect(state.profile.name, isEmpty);
      expect(state.demoAvailable, isFalse);
    });

    test('startDemo is a no-op when demo is not available', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final state = await startState(api: FakeApiClient());

      state.startDemo();

      expect(state.isDemoMode, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.contacts, isEmpty);
    });

    test('demo availability defaults to the inverse of release mode', () {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final state = ReconnectAppState(apiClient: FakeApiClient(), sessionStore: InMemorySessionStore());
      addTearDown(state.dispose);
      expect(state.demoAvailable, !kReleaseMode);
    });

    test('an unreachable backend shows an error state, never fabricated contacts', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()..failures['fetchDashboard'] = const ReconnectApiException.network();
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));

      expect(state.isAuthenticated, isTrue);
      expect(state.loadFailed, isTrue);
      expect(state.errorMessage, contains('Unable to reach Reconnect'));
      expect(state.contacts, isEmpty);
      expect(state.nearbySuggestions, isEmpty);
      expect(state.matches.mutual, isEmpty);
      expect(state.isDemoMode, isFalse);
    });

    test('retryLoad recovers once the backend is reachable', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient(
        dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan Patel')], contactsImported: true),
      )..failures['fetchDashboard'] = const ReconnectApiException.network();
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));
      expect(state.loadFailed, isTrue);

      api.failures.clear();
      await state.retryLoad();

      expect(state.loadFailed, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.contacts.single.name, 'Jordan Patel');
      expect(state.isAuthenticated, isTrue);
    });

    test('a 5xx on startup keeps the session and shows the error state', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final store = InMemorySessionStore(storedSession());
      final api = FakeApiClient()
        ..failures['fetchDashboard'] = const ReconnectApiException(statusCode: 503, message: 'down', code: 'unavailable');
      final state = await startState(api: api, store: store);

      expect(state.loadFailed, isTrue);
      expect(await store.read(), isNotNull);
    });
  });

  group('explicit demo mode (debug builds)', () {
    test('startDemo shows labeled sample data without any account or network', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final api = FakeApiClient();
      final store = InMemorySessionStore();
      final state = await startState(api: api, store: store, demoAvailable: true);

      expect(state.contacts, isEmpty, reason: 'nothing is seeded until the user opts in');
      state.startDemo();

      expect(state.isDemoMode, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(state.contacts, isNotEmpty);
      expect(await store.read(), isNull, reason: 'no fake token is persisted');

      await state.updatePreference(state.contacts.first.id, ReconnectPreference.neutral);
      expect(api.calls, isNot(contains('updatePreference')));
    });

    test('logging out of the demo returns to a clean signed-out state', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final state = await startState(api: FakeApiClient(), demoAvailable: true);
      state.startDemo();

      await state.logout();

      expect(state.isDemoMode, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.contacts, isEmpty);
    });
  });

  group('secure storage migration', () {
    test('moves legacy SharedPreferences tokens into secure storage and deletes the old keys', () async {
      SharedPreferences.setMockInitialValues({
        'reconnect_auth_token': 'legacy-access',
        'reconnect_refresh_token': 'legacy-refresh',
        'reconnect_auth_token_expiry': '2099-01-01T00:00:00.000Z',
        'reconnect_onboarding_complete': true,
      });
      final store = InMemorySessionStore();
      final state = await startState(api: FakeApiClient(), store: store);

      final stored = await store.read();
      expect(stored?.accessToken, 'legacy-access');
      expect(stored?.refreshToken, 'legacy-refresh');
      expect(stored?.accessTokenExpiresAt, DateTime.utc(2099));
      expect(state.isAuthenticated, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('reconnect_auth_token'), isFalse);
      expect(prefs.containsKey('reconnect_refresh_token'), isFalse);
      expect(prefs.containsKey('reconnect_auth_token_expiry'), isFalse);
      expect(prefs.getBool('reconnect_onboarding_complete'), isTrue, reason: 'non-secret flags stay in prefs');
    });

    test('is idempotent and does not resurrect old keys', () async {
      SharedPreferences.setMockInitialValues({'reconnect_auth_token': 'legacy-access', 'reconnect_refresh_token': 'r'});
      final prefs = await SharedPreferences.getInstance();
      final store = InMemorySessionStore();

      await LegacyTokenMigration.run(prefs, store);
      await LegacyTokenMigration.run(prefs, store);

      expect((await store.read())?.accessToken, 'legacy-access');
      expect(prefs.getKeys().where((k) => k.startsWith('reconnect_auth')), isEmpty);
    });

    test('a fresh install wipes stale secure-storage tokens left by a previous install', () async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final store = InMemorySessionStore(storedSession());

      await LegacyTokenMigration.run(prefs, store);

      expect(await store.read(), isNull);
      expect(prefs.getBool(LegacyTokenMigration.initializedKey), isTrue);
    });

    test('later launches keep the secure session', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final prefs = await SharedPreferences.getInstance();
      final store = InMemorySessionStore(storedSession());

      await LegacyTokenMigration.run(prefs, store);

      expect(await store.read(), isNotNull);
    });
  });

  group('sign-in and sign-out', () {
    test('signUp stores tokens in secure storage only', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final store = InMemorySessionStore();
      final state = await startState(api: FakeApiClient(), store: store);

      await state.signUp(
        email: 'sam@example.com',
        phone: '+14155550124',
        password: 'correct horse',
        name: 'Sam',
        bio: '',
        homeCity: 'Brooklyn',
      );

      expect(state.isAuthenticated, isTrue);
      expect((await store.read())?.accessToken, 'access-1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains('token')), isEmpty);
    });

    test('a failed login shows a friendly message and stays signed out', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final api = FakeApiClient()
        ..failures['login'] = const ReconnectApiException(statusCode: 401, code: 'invalid_credentials', message: 'x');
      final state = await startState(api: api);

      await expectLater(state.login(email: 'a@example.com', password: 'bad'), throwsA(isA<ReconnectApiException>()));

      expect(state.isAuthenticated, isFalse);
      expect(state.errorMessage, 'Incorrect email or password.');
    });

    test('a rate-limited login reports when to retry', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final api = FakeApiClient()
        ..failures['login'] = const ReconnectApiException(statusCode: 429, code: 'rate_limited', message: 'x', retryAfterSeconds: 30);
      final state = await startState(api: api);

      await expectLater(state.login(email: 'a@example.com', password: 'pw'), throwsA(isA<ReconnectApiException>()));

      expect(state.errorMessage, contains('30 seconds'));
    });

    test('logout revokes the session on the server and clears local tokens', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient(dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan')]));
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);
      expect(state.isAuthenticated, isTrue);

      await state.logout();

      expect(api.calls, contains('logout'));
      expect(state.isAuthenticated, isFalse);
      expect(state.requiresOnboarding, isTrue);
      expect(state.contacts, isEmpty);
      expect(await store.read(), isNull);
      expect(api.currentSession, isNull);
    });

    test('logout still signs out locally when the server is unreachable', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()..failures['logout'] = const ReconnectApiException.network();
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);

      await state.logout();

      expect(state.isAuthenticated, isFalse);
      expect(await store.read(), isNull);
    });

    test('logout everywhere calls the server and signs out', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient();
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);

      await state.logoutEverywhere();

      expect(api.calls, contains('logoutAll'));
      expect(state.isAuthenticated, isFalse);
      expect(await store.read(), isNull);
    });

    test('logout everywhere keeps the session when the server cannot be reached', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()..failures['logoutAll'] = const ReconnectApiException.network();
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);

      await expectLater(state.logoutEverywhere(), throwsA(isA<ReconnectApiException>()));

      expect(state.isAuthenticated, isTrue, reason: 'the user must not be told sessions were revoked when they were not');
      expect(await store.read(), isNotNull);
    });
  });

  group('revoked sessions', () {
    for (final code in ['invalid_refresh_token', 'refresh_token_reused', 'refresh_token_expired']) {
      test('$code during startup signs out cleanly with a message', () async {
        SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
        final api = FakeApiClient()..failures['fetchDashboard'] = ReconnectApiException(statusCode: 401, code: code, message: 'x');
        final store = InMemorySessionStore(storedSession());
        final state = await startState(api: api, store: store);

        expect(state.isAuthenticated, isFalse);
        expect(state.requiresOnboarding, isTrue);
        expect(state.loadFailed, isFalse);
        expect(state.errorMessage, 'Your session has ended. Please log in again.');
        expect(await store.read(), isNull);
      });
    }

    test('a revoked session mid-use signs the user out', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient(dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan')], contactsImported: true));
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);
      expect(state.isAuthenticated, isTrue);

      api.failures['updateLocation'] =
          const ReconnectApiException(statusCode: 401, code: 'refresh_token_reused', message: 'x');
      await state.setLocation('Manhattan');

      expect(state.isAuthenticated, isFalse);
      expect(await store.read(), isNull);
    });
  });

  group('delete account', () {
    test('success deletes remotely then clears tokens, prefs and in-memory data', () async {
      SharedPreferences.setMockInitialValues({
        ...initializedPrefs,
        'reconnect_onboarding_complete': true,
        'spin_history': 'something-local',
      });
      final api = FakeApiClient(dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan')], contactsImported: true));
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);
      expect(state.contacts, isNotEmpty);

      await state.deleteAccount(password: 'my password');

      expect(api.lastDeletePassword, 'my password');
      expect(state.isAuthenticated, isFalse);
      expect(state.contacts, isEmpty);
      expect(state.profile.name, isEmpty);
      expect(await store.read(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k != LegacyTokenMigration.initializedKey), isEmpty);
    });

    test('a wrong password changes nothing and keeps the session', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()
        ..failures['deleteAccount'] = const ReconnectApiException(statusCode: 401, code: 'invalid_credentials', message: 'x');
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);

      await expectLater(state.deleteAccount(password: 'wrong'), throwsA(isA<ReconnectApiException>()));

      expect(state.isAuthenticated, isTrue);
      expect(await store.read(), isNotNull);
    });

    test('a network failure does not wipe local data', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()..failures['deleteAccount'] = const ReconnectApiException.network();
      final store = InMemorySessionStore(storedSession());
      final state = await startState(api: api, store: store);

      await expectLater(state.deleteAccount(password: 'pw'), throwsA(isA<ReconnectApiException>()));

      expect(state.isAuthenticated, isTrue);
      expect(await store.read(), isNotNull);
    });
  });

  group('verification', () {
    test('confirming the phone code updates the profile', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final api = FakeApiClient();
      final state = await startState(api: api);
      await state.signUp(
        email: 'sam@example.com',
        phone: '+14155550124',
        password: 'correct horse',
        name: 'Sam',
        bio: '',
        homeCity: 'Brooklyn',
      );
      // The dashboard fetched after sign-up still says unverified.
      api.dashboard = dashboardWith(profile: unverifiedProfile);
      await state.login(email: 'sam@example.com', password: 'correct horse');
      expect(state.profile.phoneVerified, isFalse);

      await state.sendPhoneVerification();
      await state.confirmPhoneVerification('123456');

      expect(api.calls, containsAllInOrder(['sendPhoneVerification', 'confirmPhoneVerification']));
      expect(state.profile.phoneVerified, isTrue);
      expect(state.profile.name, 'Sam Rivera', reason: 'other profile fields are kept');
    });

    test('a wrong code throws and leaves the phone unverified', () async {
      SharedPreferences.setMockInitialValues(initializedPrefs);
      final api = FakeApiClient(dashboard: dashboardWith(profile: unverifiedProfile))
        ..failures['confirmPhoneVerification'] =
            const ReconnectApiException(statusCode: 400, code: 'validation_error', message: 'That code is not valid.');
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));

      await expectLater(state.confirmPhoneVerification('000001'), throwsA(isA<ReconnectApiException>()));

      expect(state.profile.phoneVerified, isFalse);
    });

    test('importing contacts with an unverified phone (403) sends the user back to verification', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()
        ..failures['importContacts'] = const ReconnectApiException(statusCode: 403, code: 'verification_required', message: 'x');
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));
      expect(state.profile.phoneVerified, isTrue);

      await state.importContacts();

      expect(state.profile.phoneVerified, isFalse);
      expect(state.errorMessage, contains('verify your phone'));
      expect(state.isAuthenticated, isTrue, reason: '403 verification_required is not a sign-out');
      expect(state.contacts, isEmpty);
    });

    test('a 429 during import is shown without fabricating data', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient()
        ..failures['importContacts'] = const ReconnectApiException(statusCode: 429, code: 'rate_limited', message: 'x', retryAfterSeconds: 600);
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));

      await state.importContacts();

      expect(state.errorMessage, contains('10 minutes'));
      expect(state.contacts, isEmpty);
      expect(state.contactsImported, isFalse);
    });
  });

  group('failed writes are rolled back, not faked', () {
    test('a failed preference change reverts and explains', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient(dashboard: dashboardWith(contacts: [serverContact('u1', 'Jordan')], contactsImported: true));
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));
      api.failures['updatePreference'] = const ReconnectApiException.network();

      await state.updatePreference('u1', ReconnectPreference.loveToSee);

      expect(state.contacts.single.preference, ReconnectPreference.neutral);
      expect(state.errorMessage, contains('Could not save'));
    });

    test('location sharing is rolled back when the server rejects it', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient();
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));
      api.failures['updateProfile'] = const ReconnectApiException.network();

      await state.setLocationShared(true);

      expect(state.profile.locationShared, isFalse);
      expect(state.errorMessage, contains('location sharing'));
    });

    test('location sharing consent is sent to the server', () async {
      SharedPreferences.setMockInitialValues({...initializedPrefs, 'reconnect_onboarding_complete': true});
      final api = FakeApiClient();
      final state = await startState(api: api, store: InMemorySessionStore(storedSession()));
      expect(state.profile.locationShared, isFalse);

      await state.setLocationShared(true);

      expect(state.profile.locationShared, isTrue);
      expect(api.calls, contains('updateProfile'));
    });
  });
}
