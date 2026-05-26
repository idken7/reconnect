import 'dart:async';

import 'package:flutter/material.dart';
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

class ReconnectAppState extends ChangeNotifier {
  ReconnectAppState({
    ReconnectApiClient? apiClient,
    ContactImportService? contactImportService,
    LiveLocationService? liveLocationService,
    MockReconnectRepository? seedRepository,
  })  : apiClient = apiClient ?? ReconnectApiClient(),
        contactImportService = contactImportService ?? const ContactImportService(),
        liveLocationService = liveLocationService ?? const LiveLocationService(),
        seedRepository = seedRepository ?? const MockReconnectRepository() {
    _dashboard = this.seedRepository.seedState(
      location: this.seedRepository.profile.homeCity,
      contactsImported: false,
      contacts: const [],
    );
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
  
  // Feature services
  late final RandomContactService randomContactService;
  late final ConversationStarterService conversationStarterService;
  late final ActivitySuggestionService activitySuggestionService;
  late final BirthdayReminderService birthdayReminderService;

  static const _tokenKey = 'reconnect_auth_token';
  static const _refreshTokenKey = 'reconnect_refresh_token';
  static const _tokenExpiryKey = 'reconnect_auth_token_expiry';
  static const _onboardingKey = 'reconnect_onboarding_complete';

  late ReconnectDashboardData _dashboard;
  ContactMatches _matches = ContactMatches.empty;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isResolvingLocation = false;
  String? _errorMessage;
  String? _authToken;
  bool _onboardingComplete = false;

  bool get isLoading => _isLoading;
  bool get isImporting => _isImporting;
  bool get isResolvingLocation => _isResolvingLocation;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;
  bool get onboardingComplete => _onboardingComplete;
  bool get requiresOnboarding => !onboardingComplete;
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

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    final tokenExpiryRaw = prefs.getString(_tokenExpiryKey);
    final tokenExpiry = tokenExpiryRaw == null ? null : DateTime.tryParse(tokenExpiryRaw)?.toUtc();
    _onboardingComplete = prefs.getBool(_onboardingKey) ?? false;
    apiClient.setAuthSession(
      accessToken: _authToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: tokenExpiry,
    );

    if (isAuthenticated) {
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
        await _persistFromApiClient();
      } catch (_) {
        await _clearSessionStorage();
        _authToken = null;
        _onboardingComplete = false;
        apiClient.setAuthSession(accessToken: null, refreshToken: null, accessTokenExpiresAt: null);
        _errorMessage = 'Session expired. Please log in again.';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

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

      _authToken = session.accessToken;
      _dashboard = _dashboard.copyWith(profile: session.profile, currentLocation: homeCity);

      await _persistSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAt: session.accessTokenExpiresAt,
      );

      _dashboard = await apiClient.fetchDashboard(location: homeCity);
      _matches = await apiClient.fetchContactMatches();
      await _persistFromApiClient();
    } catch (error) {
      _errorMessage = error.toString();
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
      _authToken = session.accessToken;

      await _persistSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAt: session.accessTokenExpiresAt,
      );

      _dashboard = await apiClient.fetchDashboard(location: _dashboard.currentLocation);
      _matches = await apiClient.fetchContactMatches();
      await _persistFromApiClient();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> markOnboardingComplete() async {
    _onboardingComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }

  Future<void> logout() async {
    _authToken = null;
    _onboardingComplete = false;
    apiClient.setAuthSession(accessToken: null, refreshToken: null, accessTokenExpiresAt: null);
    _dashboard = seedRepository.seedState(
      location: seedRepository.profile.homeCity,
      contactsImported: false,
      contacts: const [],
    );
    _matches = ContactMatches.empty;
    await _clearSessionStorage();
    notifyListeners();
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
      final deviceContacts = await contactImportService.importContacts();
      _dashboard = await apiClient.importContacts(
        location: currentLocation,
        contacts: deviceContacts,
      );
      _matches = await apiClient.fetchContactMatches();
      await _persistFromApiClient();
    } on ContactImportException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _dashboard = seedRepository.seedState(
        location: currentLocation,
        contactsImported: true,
        contacts: seedRepository.importedContacts,
      );
      _matches = const ContactMatches(
        mutual: <MatchCandidate>[
          MatchCandidate(name: 'Jordan Patel', contact: ReconnectContact(
            id: '1',
            name: 'Jordan Patel',
            email: 'jordan@example.com',
            phone: '+1 (212) 555-0180',
            isOnApp: true,
            lastSeen: '2 weeks ago',
            availableIn: <String>['Brooklyn', 'Manhattan'],
            preference: ReconnectPreference.loveToSee,
          )),
        ],
        oneWay: <MatchCandidate>[],
        notOnApp: <MatchCandidate>[],
      );
      _errorMessage = 'Contact import synced in demo mode because the backend is unavailable.';
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
      final coordinates = await liveLocationService.getCurrentCoordinates();
      _dashboard = await apiClient.updateLocationFromCoordinates(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      await _persistFromApiClient();
    } on LiveLocationException catch (error) {
      _errorMessage = error.message;
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
      _dashboard = await apiClient.updateLocation(location: location);
      await _persistFromApiClient();
    } catch (_) {
      _dashboard = seedRepository.seedState(
        location: location,
        contactsImported: contactsImported,
        contacts: contacts,
      );
      _errorMessage = 'Fallback location selected because live geolocation is unavailable.';
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
    final updatedContacts = List<ReconnectContact>.from(_dashboard.contacts);
    updatedContacts[index] = updatedContacts[index].copyWith(preference: preference);
    _dashboard = _dashboard.copyWith(contacts: updatedContacts);
    notifyListeners();

    try {
      _dashboard = await apiClient.updatePreference(contactId: contactId, preference: preference);
      _matches = await apiClient.fetchContactMatches();
      await _persistFromApiClient();
    } catch (_) {
      _errorMessage = 'Preference saved locally because the backend is unavailable.';
      notifyListeners();
    }
  }

  Future<void> _persistFromApiClient() async {
    final session = apiClient.currentSession;
    if (session == null) {
      return;
    }

    _authToken = session.accessToken;
    await _persistSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.accessTokenExpiresAt,
    );
  }

  Future<void> _persistSession({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_tokenExpiryKey, expiresAt.toUtc().toIso8601String());
  }

  Future<void> _clearSessionStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
    await prefs.remove(_onboardingKey);
  }
}
