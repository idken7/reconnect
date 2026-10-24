import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/mock_reconnect_repository.dart';
import 'models.dart';
import 'services/activity_suggestion_service.dart';
import 'services/backend/reconnect_api_client.dart';
import 'services/birthday_reminder_service.dart';
import 'services/contacts/contact_import_service.dart';
import 'services/conversation_starter_service.dart';
import 'services/location/live_location_service.dart';
import 'services/random_contact_service.dart';
import 'services/storage/session_store.dart';

class ReconnectAppState extends ChangeNotifier {
  ReconnectAppState({
    ReconnectApiClient? apiClient,
    ContactImportService? contactImportService,
    LiveLocationService? liveLocationService,
    MockReconnectRepository? seedRepository,
    SessionStore? sessionStore,
    bool? demoAvailable,
  })  : apiClient = apiClient ?? ReconnectApiClient(),
        contactImportService = contactImportService ?? const ContactImportService(),
        liveLocationService = liveLocationService ?? const LiveLocationService(),
        seedRepository = seedRepository ?? const MockReconnectRepository(),
        sessionStore = sessionStore ?? const SecureSessionStore(),
        // Demo data is for debug/profile builds only; it can never be
        // switched on in a release build.
        demoAvailable = demoAvailable ?? !kReleaseMode {
    _dashboard = _emptyDashboard();
    // Persist rotated refresh tokens the moment they are issued: the old one
    // is dead as soon as the server rotates it.
    this.apiClient.onSessionRefreshed = (session) {
      _authToken = session.accessToken;
      unawaited(_persistSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAt: session.accessTokenExpiresAt,
      ));
    };
    // Initialize feature services
    randomContactService = RandomContactService();
    conversationStarterService = ConversationStarterService();
    activitySuggestionService = ActivitySuggestionService();
    birthdayReminderService = BirthdayReminderService();
    unawaited(initialize());
  }

  final ReconnectApiClient apiClient;
  final ContactImportService contactImportService;
  final LiveLocationService liveLocationService;
  final MockReconnectRepository seedRepository;
  final SessionStore sessionStore;

  /// Whether the explicit "Try demo" action may be offered (never in release).
  final bool demoAvailable;

  // Feature services
  late final RandomContactService randomContactService;
  late final ConversationStarterService conversationStarterService;
  late final ActivitySuggestionService activitySuggestionService;
  late final BirthdayReminderService birthdayReminderService;

  static const _onboardingKey = 'reconnect_onboarding_complete';
  static const _defaultLocations = ['Brooklyn', 'Manhattan', 'Austin', 'Chicago', 'Other'];

  late ReconnectDashboardData _dashboard;
  ContactMatches _matches = ContactMatches.empty;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isResolvingLocation = false;
  bool _isRetrying = false;
  bool _loadFailed = false;
  bool _demoMode = false;
  String? _errorMessage;
  String? _authToken;
  bool _onboardingComplete = false;

  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  bool get isResolvingLocation => _isResolvingLocation;
  bool get isRetrying => _isRetrying;

  /// Signed in (real tokens) or in the explicit, labeled demo mode.
  bool get isAuthenticated => _demoMode || (_authToken != null && _authToken!.isNotEmpty);
  bool get isDemoMode => _demoMode;
  bool get onboardingComplete => _onboardingComplete;
  bool get requiresOnboarding => !onboardingComplete;

  /// The signed-in user's data could not be loaded (offline, server error).
  /// The UI shows an error state with retry instead of any placeholder data.
  bool get loadFailed => _loadFailed;
  String? get errorMessage => _errorMessage;

  ReconnectProfile get profile => _dashboard.profile;
  bool get contactsImported => _dashboard.contactsImported;
  String get currentLocation => _dashboard.currentLocation;
  int get currentIndex => _currentIndex;
  List<String> get supportedLocations => _dashboard.supportedLocations;
  List<ReconnectContact> get contacts => List.unmodifiable(_dashboard.contacts);
  List<NearbySuggestion> get nearbySuggestions => List.unmodifiable(_dashboard.suggestions);
  ContactMatches get matches => _matches;

  // Feature getters
  ReconnectContact? getRandomContact({int daysThreshold = 90}) {
    return randomContactService.getRandomContact(contacts, daysThreshold: daysThreshold);
  }

  ConversationStarter getConversationStarter() {
    return conversationStarterService.getRandomStarter();
  }

  ActivitySuggestion getActivitySuggestion({String location = 'any'}) {
    return activitySuggestionService.getRandomActivity(location: location);
  }

  List<ReconnectContact> getUpcomingBirthdays() {
    return birthdayReminderService.getUpcomingBirthdays(contacts);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// In-flight network calls can finish after the state is disposed.
  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  // ---------------------------------------------------------------- startup

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _loadStoredSession(prefs);
      _onboardingComplete = prefs.getBool(_onboardingKey) ?? false;

      if (isAuthenticated) {
        await _loadRemoteState();
      }
    } catch (error) {
      _loadFailed = isAuthenticated;
      _errorMessage = friendlyErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retry after a failed startup load (offline, server error).
  Future<void> retryLoad() async {
    if (_isRetrying) {
      return;
    }
    _isRetrying = true;
    notifyListeners();
    try {
      await _loadRemoteState();
    } finally {
      _isRetrying = false;
      notifyListeners();
    }
  }

  Future<void> _loadStoredSession(SharedPreferences prefs) async {
    try {
      await LegacyTokenMigration.run(prefs, sessionStore);
    } catch (error) {
      // Leave the old keys in place; the user signs in again rather than
      // losing the session to a half-finished migration.
      debugPrint('Token migration failed: ${error.runtimeType}');
    }

    final stored = await sessionStore.read();
    _authToken = stored?.accessToken;
    apiClient.setAuthSession(
      accessToken: stored?.accessToken,
      refreshToken: stored?.refreshToken,
      accessTokenExpiresAt: stored?.accessTokenExpiresAt,
    );
  }

  Future<void> _loadRemoteState() async {
    try {
      if (apiClient.isAccessTokenExpired && apiClient.hasRefreshToken) {
        final refreshed = await apiClient.refreshSession();
        _authToken = refreshed.accessToken;
        await _persistSession(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
          expiresAt: refreshed.accessTokenExpiresAt,
        );
      }

      _dashboard = await apiClient.fetchDashboard(location: _dashboard.currentLocation);
      _matches = await apiClient.fetchContactMatches();
      _loadFailed = false;
      _errorMessage = null;
    } on ReconnectApiException catch (error) {
      if (error.shouldSignOut) {
        // Token revoked, expired or reused: sign out cleanly.
        await _signOutLocally(message: error.friendlyMessage);
      } else {
        _loadFailed = true;
        _errorMessage = error.friendlyMessage;
      }
    } catch (error) {
      _loadFailed = true;
      _errorMessage = friendlyErrorMessage(error);
    }
  }

  // ------------------------------------------------------------------ auth

  Future<void> signUp({
    required String email,
    required String phone,
    required String password,
    required String name,
    required String bio,
    required String homeCity,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await apiClient.signUp(
        email: email,
        phone: phone,
        password: password,
        name: name,
        bio: bio,
        homeCity: homeCity,
      );
      await _adoptSession(session, fallbackLocation: homeCity);
    } catch (error) {
      _errorMessage = friendlyErrorMessage(error);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await apiClient.login(email: email, password: password);
      await _adoptSession(session, fallbackLocation: _dashboard.currentLocation);
    } catch (error) {
      _errorMessage = friendlyErrorMessage(error);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _adoptSession(AuthSession session, {required String fallbackLocation}) async {
    _demoMode = false;
    _loadFailed = false;
    _authToken = session.accessToken;
    _dashboard = _dashboard.copyWith(profile: session.profile, currentLocation: fallbackLocation);

    await _persistSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.accessTokenExpiresAt,
    );

    // The account exists and the session is stored; a failure to load the
    // dashboard here is retried by the normal screens, not reported as a
    // failed sign-in.
    try {
      _dashboard = await apiClient.fetchDashboard(location: fallbackLocation);
      _matches = await apiClient.fetchContactMatches();
    } on ReconnectApiException catch (error) {
      if (error.shouldSignOut) {
        await _signOutLocally(message: error.friendlyMessage);
        rethrow;
      }
    }
  }

  Future<void> markOnboardingComplete() async {
    _onboardingComplete = true;
    if (!_demoMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    }
    notifyListeners();
  }

  /// Ends this session. The server is asked to revoke it, but being offline
  /// never stops the user from signing out of this device.
  Future<void> logout() async {
    if (!_demoMode && isAuthenticated) {
      try {
        await apiClient.logout().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Best effort: the tokens are discarded locally either way.
      }
    }
    await _signOutLocally();
  }

  /// Revokes every session of the user, then signs out here. Throws if the
  /// server could not be reached so the user is not told it worked.
  Future<void> logoutEverywhere() async {
    await _guarded(apiClient.logoutAll);
    await _signOutLocally();
  }

  /// Hard-deletes the account on the server, then wipes every trace of the
  /// user from this device. A wrong password throws and changes nothing.
  Future<void> deleteAccount({required String password}) async {
    await _guarded(() => apiClient.deleteAccount(password: password));
    await _wipeLocalData();
  }

  /// A machine-readable copy of the user's data (GET /account/export).
  Future<String> exportAccountData() async {
    final data = await _guarded(apiClient.exportAccount);
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ----------------------------------------------------------- verification

  Future<void> sendPhoneVerification() => _guarded(apiClient.sendPhoneVerification);

  Future<void> confirmPhoneVerification(String code) async {
    final updated = await _guarded(() => apiClient.confirmPhoneVerification(code));
    _applyVerifiedProfile(updated);
  }

  Future<void> sendEmailVerification() => _guarded(apiClient.sendEmailVerification);

  Future<void> confirmEmailVerification(String code) async {
    final updated = await _guarded(() => apiClient.confirmEmailVerification(code));
    _applyVerifiedProfile(updated);
  }

  void _applyVerifiedProfile(ReconnectProfile updated) {
    // Verification responses carry the whole profile; keep local-only fields.
    _dashboard = _dashboard.copyWith(
      profile: _dashboard.profile.copyWith(
        phoneVerified: updated.phoneVerified,
        emailVerified: updated.emailVerified,
        phone: updated.phone.isEmpty ? null : updated.phone,
        email: updated.email.isEmpty ? null : updated.email,
      ),
    );
    notifyListeners();
  }

  // --------------------------------------------------------- password reset

  Future<void> requestPasswordReset({required String email}) {
    return apiClient.requestPasswordReset(email: email);
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return apiClient.confirmPasswordReset(email: email, code: code, newPassword: newPassword);
  }

  // --------------------------------------------------------------- demo mode

  /// Explicit, labeled demo: sample contacts on this device only, no account,
  /// no network, nothing stored. Refuses to run when [demoAvailable] is false.
  void startDemo() {
    if (!demoAvailable) {
      return;
    }
    _demoMode = true;
    _onboardingComplete = true;
    _loadFailed = false;
    _errorMessage = null;
    _dashboard = seedRepository.seedState(
      location: seedRepository.profile.homeCity,
      contactsImported: true,
      contacts: seedRepository.importedContacts,
    );
    _matches = _generateMatchesFromContacts(seedRepository.importedContacts);
    notifyListeners();
  }

  // ------------------------------------------------------------------ misc

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> importContacts() async {
    if (_isImporting) {
      return;
    }

    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_demoMode) {
        _dashboard = seedRepository.seedState(
          location: currentLocation,
          contactsImported: true,
          contacts: seedRepository.importedContacts,
        );
        _matches = _generateMatchesFromContacts(seedRepository.importedContacts);
      } else {
        final deviceContacts = await contactImportService.importContacts();
        _dashboard = await _guarded(
          () => apiClient.importContacts(
            location: currentLocation,
            contacts: deviceContacts,
          ),
        );
        _matches = await _guarded(apiClient.fetchContactMatches);
      }
    } on ContactImportException catch (error) {
      _errorMessage = error.message;
    } on ReconnectApiException catch (error) {
      _errorMessage = error.friendlyMessage;
      if (error.isVerificationRequired) {
        // The server says the phone is not verified: send the user back to
        // verification rather than failing silently.
        _dashboard = _dashboard.copyWith(profile: _dashboard.profile.copyWith(phoneVerified: false));
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(error);
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> refreshLiveLocation() async {
    if (_isResolvingLocation) {
      return;
    }

    _isResolvingLocation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_demoMode) {
        _errorMessage = 'Live location is not available in demo mode.';
      } else {
        final coordinates = await liveLocationService.getCurrentCoordinates();
        _dashboard = await _guarded(
          () => apiClient.updateLocationFromCoordinates(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          ),
        );
      }
    } on LiveLocationException catch (error) {
      _errorMessage = error.message;
    } on ReconnectApiException catch (error) {
      _errorMessage = error.friendlyMessage;
    } catch (_) {
      _errorMessage = 'Unable to refresh live location right now.';
    } finally {
      _isResolvingLocation = false;
      notifyListeners();
    }
  }

  Future<void> setLocation(String location) async {
    _errorMessage = null;
    try {
      if (_demoMode) {
        _dashboard = seedRepository.seedState(
          location: location,
          contactsImported: contactsImported,
          contacts: contacts,
        );
      } else {
        _dashboard = await _guarded(() => apiClient.updateLocation(location: location));
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(error);
    } finally {
      notifyListeners();
    }
  }

  Future<void> updatePreference(String contactId, ReconnectPreference preference) async {
    final index = _dashboard.contacts.indexWhere((contact) => contact.id == contactId);
    if (index == -1) {
      return;
    }

    _errorMessage = null;
    final previous = _dashboard;
    final updatedContacts = List<ReconnectContact>.from(_dashboard.contacts);
    updatedContacts[index] = updatedContacts[index].copyWith(preference: preference);
    _dashboard = _dashboard.copyWith(contacts: updatedContacts);
    notifyListeners();

    if (_demoMode) {
      return;
    }

    try {
      _dashboard = await _guarded(() => apiClient.updatePreference(contactId: contactId, preference: preference));
      _matches = await _guarded(apiClient.fetchContactMatches);
    } catch (error) {
      _dashboard = previous;
      _errorMessage = 'Could not save that change. ${friendlyErrorMessage(error)}';
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    required String bio,
    required String homeCity,
    String? profileImageUrl,
  }) async {
    _errorMessage = null;
    final previous = _dashboard;
    final resolvedImageUrl = profileImageUrl ?? _dashboard.profile.profileImageUrl;
    final updatedProfile = _dashboard.profile.copyWith(
      bio: bio,
      homeCity: homeCity,
      profileImageUrl: resolvedImageUrl,
    );
    _dashboard = _dashboard.copyWith(profile: updatedProfile);
    notifyListeners();

    if (_demoMode) {
      return;
    }

    try {
      _dashboard = await _guarded(
        () => apiClient.updateProfile(
          bio: bio,
          homeCity: homeCity,
          profileImageUrl: resolvedImageUrl,
        ),
      );
    } catch (error) {
      _dashboard = previous;
      _errorMessage = 'Could not update your profile. ${friendlyErrorMessage(error)}';
    }
    notifyListeners();
  }

  /// Location-sharing consent. When on, mutual matches can see which city
  /// you are in; when off, nobody can.
  Future<void> setLocationShared(bool shared) async {
    _errorMessage = null;
    final previous = _dashboard;
    _dashboard = _dashboard.copyWith(profile: _dashboard.profile.copyWith(locationShared: shared));
    notifyListeners();

    if (_demoMode) {
      return;
    }

    try {
      _dashboard = await _guarded(() => apiClient.updateProfile(locationShared: shared));
    } catch (error) {
      _dashboard = previous;
      _errorMessage = 'Could not change location sharing. ${friendlyErrorMessage(error)}';
    }
    notifyListeners();
  }

  // ----------------------------------------------------------- persistence

  Future<void> _persistSession({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) {
    return sessionStore.write(
      StoredSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: expiresAt,
      ),
    );
  }

  /// Runs an API call; if the server says the session is dead (revoked,
  /// reused or expired refresh token) the user is signed out cleanly before
  /// the error is rethrown.
  Future<T> _guarded<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ReconnectApiException catch (error) {
      if (error.shouldSignOut && !_demoMode) {
        await _signOutLocally(message: error.friendlyMessage);
      }
      rethrow;
    }
  }

  ReconnectDashboardData _emptyDashboard() {
    return const ReconnectDashboardData(
      profile: ReconnectProfile(name: '', email: '', phone: '', homeCity: '', bio: ''),
      supportedLocations: _defaultLocations,
      currentLocation: '',
      contactsImported: false,
      contacts: [],
      suggestions: [],
    );
  }

  void _resetInMemoryState() {
    _authToken = null;
    _demoMode = false;
    _onboardingComplete = false;
    _loadFailed = false;
    _currentIndex = 0;
    apiClient.setAuthSession(accessToken: null, refreshToken: null, accessTokenExpiresAt: null);
    _dashboard = _emptyDashboard();
    _matches = ContactMatches.empty;
  }

  Future<void> _signOutLocally({String? message}) async {
    _resetInMemoryState();
    _errorMessage = message;
    await sessionStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
    notifyListeners();
  }

  /// Removes tokens, preferences and cached data: used after account deletion.
  Future<void> _wipeLocalData() async {
    _resetInMemoryState();
    _errorMessage = null;
    await sessionStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  /// Demo-only: derives match lists from the sample contacts.
  /// On-app contacts split into mutual (you'd love/like to see them — a
  /// two-way interest) and oneWay/"discovered" (on-app but not a priority
  /// tier for you, i.e. they have you in their contacts without a
  /// reciprocal match yet); off-app contacts become invite candidates.
  ContactMatches _generateMatchesFromContacts(List<ReconnectContact> contacts) {
    final mutual = <MatchCandidate>[];
    final oneWay = <MatchCandidate>[];
    final notOnApp = <MatchCandidate>[];

    for (final contact in contacts) {
      if (!contact.isOnApp) {
        notOnApp.add(
          MatchCandidate(
            name: contact.name,
            status: 'Not on app',
            contact: contact,
          ),
        );
        continue;
      }

      final isMutual = contact.preference == ReconnectPreference.loveToSee || contact.preference == ReconnectPreference.like;
      if (isMutual) {
        mutual.add(MatchCandidate(name: contact.name, contact: contact));
      } else {
        oneWay.add(
          MatchCandidate(
            name: contact.name,
            status: 'Has you in their contacts',
            contact: contact,
          ),
        );
      }
    }

    return ContactMatches(
      mutual: mutual,
      oneWay: oneWay,
      notOnApp: notOnApp,
    );
  }
}
