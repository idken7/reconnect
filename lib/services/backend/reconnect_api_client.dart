import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/environment.dart';
import '../../models.dart';
import '../contacts/contact_import_service.dart';

class ReconnectApiException implements Exception {
  const ReconnectApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String message;
  final String? code;

  bool get isAuthFailure => statusCode == 401;
  bool get isTokenExpired => code == 'token_expired';

  @override
  String toString() => 'Reconnect API error ($statusCode${code != null ? '/$code' : ''}): $message';
}

class ReconnectApiClient {
  ReconnectApiClient({Uri? baseUri, http.Client? client})
      : baseUri = baseUri ?? _defaultBaseUri(),
        _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiresAt;

  void setAuthSession({
    required String? accessToken,
    required String? refreshToken,
    required DateTime? accessTokenExpiresAt,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _accessTokenExpiresAt = accessTokenExpiresAt?.toUtc();
  }

  AuthSession? get currentSession {
    if (_accessToken == null || _accessToken!.isEmpty || _refreshToken == null || _refreshToken!.isEmpty) {
      return null;
    }

    return AuthSession(
      accessToken: _accessToken!,
      refreshToken: _refreshToken!,
      accessTokenExpiresAt: _accessTokenExpiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 15)),
      profile: const ReconnectProfile(name: '', email: '', phone: '', homeCity: '', bio: ''),
    );
  }

  bool get hasRefreshToken => _refreshToken != null && _refreshToken!.isNotEmpty;
  bool get isAccessTokenExpired {
    final expiresAt = _accessTokenExpiresAt;
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(expiresAt);
  }

  static Uri _defaultBaseUri() {
    const configured = String.fromEnvironment('RECONNECT_API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) {
      return Uri.parse(configured);
    }

    final envConfig = EnvironmentService.instance;
    return Uri.parse(envConfig.apiBaseUrl);
  }

  Future<ReconnectDashboardData> fetchDashboard({required String location}) async {
    final response = await _withAuthRetry(
      () => _client.get(
        _endpoint('/v1/dashboard', {'location': location}),
        headers: _jsonHeaders,
      ),
    );
    _ensureSuccess(response);
    return _dashboardFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthSession> signUp({
    required String email,
    required String phone,
    required String password,
    required String name,
    required String bio,
    required String homeCity,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/auth/signup'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'phone': phone,
        'password': password,
        'name': name,
        'bio': bio,
        'homeCity': homeCity,
      }),
    );
    _ensureSuccess(response);
    final session = AuthSession.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    setAuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessTokenExpiresAt: session.accessTokenExpiresAt,
    );
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    _ensureSuccess(response);
    final session = AuthSession.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    setAuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessTokenExpiresAt: session.accessTokenExpiresAt,
    );
    return session;
  }

  Future<AuthSession> refreshSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ReconnectApiException(
        statusCode: 401,
        code: 'missing_refresh_token',
        message: 'No refresh token is available.',
      );
    }

    final response = await _client.post(
      _endpoint('/v1/auth/refresh'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession.fromJson({
      ...body,
      'profile': const <String, dynamic>{
        'name': '',
        'email': '',
        'phone': '',
        'homeCity': '',
        'bio': '',
      },
    });
    setAuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessTokenExpiresAt: session.accessTokenExpiresAt,
    );
    return session;
  }

  Future<ReconnectDashboardData> importContacts({
    required String location,
    required List<ImportedDeviceContact> contacts,
  }) async {
    final response = await _withAuthRetry(
      () => _client.post(
        _endpoint('/v1/contacts/import'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'location': location,
          'contacts': contacts.map((contact) => contact.toJson()).toList(growable: false),
        }),
      ),
    );
    _ensureSuccess(response);
    return _dashboardFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ReconnectDashboardData> updatePreference({
    required String contactId,
    required ReconnectPreference preference,
  }) async {
    final response = await _withAuthRetry(
      () => _client.patch(
        _endpoint('/v1/contacts/$contactId/preference'),
        headers: _jsonHeaders,
        body: jsonEncode({'preference': preference.name}),
      ),
    );
    _ensureSuccess(response);
    return _dashboardFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ReconnectDashboardData> updateLocation({required String location}) async {
    final response = await _withAuthRetry(
      () => _client.patch(
        _endpoint('/v1/location'),
        headers: _jsonHeaders,
        body: jsonEncode({'location': location}),
      ),
    );
    _ensureSuccess(response);
    return _dashboardFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ReconnectDashboardData> updateLocationFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _withAuthRetry(
      () => _client.patch(
        _endpoint('/v1/location'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ),
    );
    _ensureSuccess(response);
    return _dashboardFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ContactMatches> fetchContactMatches() async {
    final response = await _withAuthRetry(
      () => _client.get(
        _endpoint('/v1/contacts/matches'),
        headers: _jsonHeaders,
      ),
    );
    _ensureSuccess(response);
    return ContactMatches.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Uri _endpoint(String path, [Map<String, String>? queryParameters]) {
    return baseUri.replace(path: path, queryParameters: queryParameters);
  }

  Map<String, String> get _jsonHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = response.body;
    String? code;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error'] as String? ?? response.body;
      code = body['code'] as String?;
    } catch (_) {
      message = response.body;
    }

    throw ReconnectApiException(
      statusCode: response.statusCode,
      message: message,
      code: code,
    );
  }

  ReconnectDashboardData _dashboardFromJson(Map<String, dynamic> json) {
    return ReconnectDashboardData.fromJson(json);
  }

  void close() {
    _client.close();
  }

  Future<http.Response> _withAuthRetry(Future<http.Response> Function() call) async {
    var response = await call();
    if (response.statusCode != 401) {
      return response;
    }

    String? code;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      code = body['code'] as String?;
    } catch (_) {
      code = null;
    }

    final shouldRefresh = hasRefreshToken && (code == 'token_expired' || code == 'invalid_access_token');
    if (!shouldRefresh) {
      return response;
    }

    await refreshSession();
    response = await call();
    return response;
  }
}
