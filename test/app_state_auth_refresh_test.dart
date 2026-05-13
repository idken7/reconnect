import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/app_state.dart';
import 'package:reconnect/data/mock_reconnect_repository.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/backend/reconnect_api_client.dart';
import 'package:reconnect/services/contacts/contact_import_service.dart';
import 'package:reconnect/services/location/live_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeContactImportService extends ContactImportService {
  const FakeContactImportService();
}

class FakeLiveLocationService extends LiveLocationService {
  const FakeLiveLocationService();
}

class FakeApiClient extends ReconnectApiClient {
  FakeApiClient({
    required this.expired,
    required this.refreshAvailable,
    required this.refreshShouldFail,
    required this.dashboard,
    required this.matches,
  }) : super(baseUri: Uri.parse('http://127.0.0.1:65535'));

  final bool expired;
  final bool refreshAvailable;
  final bool refreshShouldFail;
  final ReconnectDashboardData dashboard;
  final ContactMatches matches;

  bool refreshCalled = false;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  @override
  void setAuthSession({required String? accessToken, required String? refreshToken, required DateTime? accessTokenExpiresAt}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresAt = accessTokenExpiresAt;
  }

  @override
  bool get hasRefreshToken => refreshAvailable && (_refreshToken?.isNotEmpty ?? false);

  @override
  bool get isAccessTokenExpired => expired;

  @override
  Future<AuthSession> refreshSession() async {
    refreshCalled = true;
    if (refreshShouldFail) {
      throw const ReconnectApiException(statusCode: 401, code: 'refresh_token_expired', message: 'expired');
    }

    _accessToken = 'new-access';
    _refreshToken = 'new-refresh';
    _expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));

    return AuthSession(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      accessTokenExpiresAt: _expiresAt!,
      profile: dashboard.profile,
    );
  }

  @override
  Future<ReconnectDashboardData> fetchDashboard({required String location}) async {
    return dashboard.copyWith(currentLocation: location);
  }

  @override
  Future<ContactMatches> fetchContactMatches() async {
    return matches;
  }

  @override
  AuthSession? get currentSession {
    if (_accessToken == null || _refreshToken == null || _expiresAt == null) {
      return null;
    }

    return AuthSession(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      accessTokenExpiresAt: _expiresAt!,
      profile: dashboard.profile,
    );
  }
}

void main() {
  const seedRepo = MockReconnectRepository();
  final seedDashboard = seedRepo.seedState(
    location: 'Brooklyn',
    contactsImported: false,
    contacts: const [],
  );

  test('startup silently refreshes expired token', () async {
    SharedPreferences.setMockInitialValues({
      'reconnect_auth_token': 'expired-access',
      'reconnect_refresh_token': 'refresh-token',
      'reconnect_auth_token_expiry': DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String(),
      'reconnect_onboarding_complete': true,
    });

    final apiClient = FakeApiClient(
      expired: true,
      refreshAvailable: true,
      refreshShouldFail: false,
      dashboard: seedDashboard,
      matches: ContactMatches.empty,
    );

    final appState = ReconnectAppState(
      apiClient: apiClient,
      contactImportService: const FakeContactImportService(),
      liveLocationService: const FakeLiveLocationService(),
      seedRepository: seedRepo,
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(apiClient.refreshCalled, true);
    expect(appState.isAuthenticated, true);
    expect(appState.requiresOnboarding, false);
  });

  test('startup clears session when refresh fails', () async {
    SharedPreferences.setMockInitialValues({
      'reconnect_auth_token': 'expired-access',
      'reconnect_refresh_token': 'expired-refresh',
      'reconnect_auth_token_expiry': DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String(),
      'reconnect_onboarding_complete': true,
    });

    final apiClient = FakeApiClient(
      expired: true,
      refreshAvailable: true,
      refreshShouldFail: true,
      dashboard: seedDashboard,
      matches: ContactMatches.empty,
    );

    final appState = ReconnectAppState(
      apiClient: apiClient,
      contactImportService: const FakeContactImportService(),
      liveLocationService: const FakeLiveLocationService(),
      seedRepository: seedRepo,
    );

    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(apiClient.refreshCalled, true);
    expect(appState.isAuthenticated, false);
    expect(appState.requiresOnboarding, true);
  });
}
