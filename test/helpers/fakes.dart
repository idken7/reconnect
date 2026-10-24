import 'package:reconnect/data/mock_reconnect_repository.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/backend/reconnect_api_client.dart';
import 'package:reconnect/services/contacts/contact_import_service.dart';
import 'package:reconnect/services/location/live_location_service.dart';

const unverifiedProfile = ReconnectProfile(
  name: 'Sam Rivera',
  email: 'sam@example.com',
  phone: '+14155550124',
  homeCity: 'Brooklyn',
  bio: 'Hello',
);

final verifiedProfile = unverifiedProfile.copyWith(phoneVerified: true);

ReconnectContact serverContact(String id, String name, {DateTime? lastSeenAt}) {
  return ReconnectContact(
    id: id,
    name: name,
    email: '',
    phone: '',
    isOnApp: true,
    lastSeen: '',
    lastSeenAt: lastSeenAt,
    availableIn: const [],
    preference: ReconnectPreference.neutral,
    mutual: true,
  );
}

ReconnectDashboardData dashboardWith({
  ReconnectProfile? profile,
  List<ReconnectContact> contacts = const [],
  bool contactsImported = false,
}) {
  return ReconnectDashboardData(
    profile: profile ?? verifiedProfile,
    supportedLocations: const ['Brooklyn', 'Manhattan', 'Other'],
    currentLocation: 'Brooklyn',
    contactsImported: contactsImported,
    contacts: contacts,
    suggestions: const [],
  );
}

AuthSession sessionFor(ReconnectProfile profile, {String access = 'access-1', String refresh = 'refresh-1'}) {
  return AuthSession(
    accessToken: access,
    refreshToken: refresh,
    accessTokenExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
    profile: profile,
  );
}

class FakeContactImportService extends ContactImportService {
  const FakeContactImportService([this.contacts = const []]);

  final List<ImportedDeviceContact> contacts;

  @override
  Future<List<ImportedDeviceContact>> importContacts() async => contacts;
}

class FakeLiveLocationService extends LiveLocationService {
  const FakeLiveLocationService();

  @override
  Future<LiveCoordinates> getCurrentCoordinates() async {
    return const LiveCoordinates(latitude: 40.7, longitude: -73.95);
  }
}

/// A scriptable stand-in for the backend. Every route records its name in
/// [calls]; put an error in [failures] under the route name to make it throw.
class FakeApiClient extends ReconnectApiClient {
  FakeApiClient({ReconnectDashboardData? dashboard, ContactMatches? matches})
      : dashboard = dashboard ?? dashboardWith(),
        matches = matches ?? ContactMatches.empty,
        super(baseUri: Uri.parse('http://127.0.0.1:65535'));

  ReconnectDashboardData dashboard;
  ContactMatches matches;
  final calls = <String>[];
  final failures = <String, Object>{};
  ReconnectProfile signUpProfile = unverifiedProfile;
  ReconnectProfile profileAfterVerification = verifiedProfile;
  String? lastDeletePassword;

  String? _access;
  String? _refresh;

  Future<T> _call<T>(String name, T Function() ok) async {
    calls.add(name);
    final failure = failures[name];
    if (failure != null) {
      throw failure;
    }
    return ok();
  }

  @override
  void setAuthSession({required String? accessToken, required String? refreshToken, required DateTime? accessTokenExpiresAt}) {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  bool get hasRefreshToken => _refresh != null && _refresh!.isNotEmpty;

  @override
  bool get isAccessTokenExpired => false;

  @override
  AuthSession? get currentSession => _access == null ? null : sessionFor(dashboard.profile, access: _access!, refresh: _refresh ?? '');

  @override
  Future<AuthSession> signUp({
    required String email,
    required String phone,
    required String password,
    required String name,
    required String bio,
    required String homeCity,
  }) {
    return _call('signUp', () {
      dashboard = dashboard.copyWith(profile: signUpProfile);
      setAuthSession(accessToken: 'access-1', refreshToken: 'refresh-1', accessTokenExpiresAt: null);
      return sessionFor(signUpProfile);
    });
  }

  @override
  Future<AuthSession> login({required String email, required String password, String? deviceLabel}) {
    return _call('login', () {
      setAuthSession(accessToken: 'access-1', refreshToken: 'refresh-1', accessTokenExpiresAt: null);
      return sessionFor(dashboard.profile);
    });
  }

  @override
  Future<AuthSession> refreshSession() {
    return _call('refreshSession', () => sessionFor(dashboard.profile, access: 'access-2', refresh: 'refresh-2'));
  }

  @override
  Future<void> logout() => _call('logout', () {});

  @override
  Future<void> logoutAll() => _call('logoutAll', () {});

  @override
  Future<void> sendPhoneVerification() => _call('sendPhoneVerification', () {});

  @override
  Future<ReconnectProfile> confirmPhoneVerification(String code) {
    return _call('confirmPhoneVerification', () {
      dashboard = dashboard.copyWith(profile: profileAfterVerification);
      return profileAfterVerification;
    });
  }

  @override
  Future<void> sendEmailVerification() => _call('sendEmailVerification', () {});

  @override
  Future<ReconnectProfile> confirmEmailVerification(String code) {
    return _call('confirmEmailVerification', () => profileAfterVerification.copyWith(emailVerified: true));
  }

  @override
  Future<void> requestPasswordReset({required String email}) => _call('requestPasswordReset', () {});

  @override
  Future<void> confirmPasswordReset({required String email, required String code, required String newPassword}) {
    return _call('confirmPasswordReset', () {});
  }

  @override
  Future<Map<String, dynamic>> exportAccount() => _call('exportAccount', () => {'profile': dashboard.profile.toJson()});

  @override
  Future<void> deleteAccount({required String password}) {
    lastDeletePassword = password;
    return _call('deleteAccount', () {});
  }

  @override
  Future<ReconnectDashboardData> fetchDashboard({required String location}) {
    return _call('fetchDashboard', () => dashboard);
  }

  @override
  Future<ContactMatches> fetchContactMatches() => _call('fetchContactMatches', () => matches);

  @override
  Future<ReconnectDashboardData> importContacts({
    required String location,
    required List<ImportedDeviceContact> contacts,
  }) {
    return _call('importContacts', () {
      dashboard = dashboard.copyWith(contactsImported: true);
      return dashboard;
    });
  }

  @override
  Future<ReconnectDashboardData> updatePreference({
    required String contactId,
    required ReconnectPreference preference,
  }) {
    return _call('updatePreference', () => dashboard);
  }

  @override
  Future<ReconnectDashboardData> updateLocation({required String location}) {
    return _call('updateLocation', () => dashboard.copyWith(currentLocation: location));
  }

  @override
  Future<ReconnectDashboardData> updateLocationFromCoordinates({required double latitude, required double longitude}) {
    return _call('updateLocationFromCoordinates', () => dashboard);
  }

  @override
  Future<ReconnectDashboardData> updateProfile({
    String? bio,
    String? homeCity,
    String? profileImageUrl,
    bool? locationShared,
  }) {
    return _call('updateProfile', () {
      dashboard = dashboard.copyWith(
        profile: dashboard.profile.copyWith(
          bio: bio,
          homeCity: homeCity,
          profileImageUrl: profileImageUrl,
          locationShared: locationShared,
        ),
      );
      return dashboard;
    });
  }
}

const mockSeed = MockReconnectRepository();
