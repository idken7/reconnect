import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/environment.dart';
import '../../models.dart';
import '../contacts/contact_import_service.dart';

/// An error from the Reconnect API (the `{code, error, requestId}` envelope),
/// or a transport failure (`statusCode == 0`, `code == 'network_error'`).
class ReconnectApiException implements Exception {
  const ReconnectApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.requestId,
    this.retryAfterSeconds,
  });

  const ReconnectApiException.network([String message = 'Unable to reach the Reconnect server.'])
      : this(statusCode: 0, code: networkErrorCode, message: message);

  static const networkErrorCode = 'network_error';

  /// 401 codes meaning the refresh token is no longer usable.
  static const signOutCodes = {'invalid_refresh_token', 'refresh_token_expired', 'refresh_token_reused'};

  final int statusCode;
  final String message;
  final String? code;
  final String? requestId;
  final int? retryAfterSeconds;

  bool get isNetworkError => code == networkErrorCode;
  bool get isRateLimited => statusCode == 429;
  bool get isVerificationRequired => statusCode == 403 && code == 'verification_required';
  bool get isTokenExpired => code == 'token_expired';
  bool get isAuthFailure => statusCode == 401;

  /// The session can no longer be used and the user must log in again.
  /// A bad password (`invalid_credentials`) is not a dead session.
  bool get shouldSignOut => statusCode == 401 && code != 'invalid_credentials';

  /// Copy suitable for showing to the user.
  String get friendlyMessage {
    if (isNetworkError) {
      return 'Unable to reach Reconnect. Check your connection and try again.';
    }
    if (isRateLimited) {
      final seconds = retryAfterSeconds;
      if (seconds == null || seconds <= 0) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      if (seconds < 90) {
        return 'Too many attempts. Please try again in $seconds seconds.';
      }
      return 'Too many attempts. Please try again in ${(seconds / 60).ceil()} minutes.';
    }
    if (isVerificationRequired) {
      return 'Please verify your phone number to continue.';
    }
    switch (code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'account_exists':
        return 'An account with that email or phone number already exists. Try logging in instead.';
      case 'invalid_refresh_token':
      case 'refresh_token_expired':
      case 'refresh_token_reused':
        return 'Your session has ended. Please log in again.';
      case 'payload_too_large':
        return 'That is too much data to send at once.';
    }
    if (statusCode >= 500) {
      final reference = requestId == null ? '' : ' (reference $requestId)';
      return 'Something went wrong on our end. Please try again.$reference';
    }
    if (statusCode == 401) {
      return 'Your session has ended. Please log in again.';
    }
    return message.isEmpty ? 'Something went wrong. Please try again.' : message;
  }

  @override
  String toString() =>
      'Reconnect API error ($statusCode${code != null ? '/$code' : ''}): $message${requestId != null ? ' [request $requestId]' : ''}';
}

/// Message to show for any error thrown while talking to the backend.
String friendlyErrorMessage(Object error) {
  if (error is ReconnectApiException) {
    return error.friendlyMessage;
  }
  if (error is TimeoutException) {
    return 'Unable to reach Reconnect. Check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}

class ReconnectApiClient {
  ReconnectApiClient({Uri? baseUri, http.Client? client, Duration? timeout})
      : baseUri = baseUri ?? Uri.parse(EnvironmentService.instance.apiBaseUrl),
        _client = client ?? http.Client(),
        _timeout = timeout ?? EnvironmentService.instance.apiTimeout;

  final Uri baseUri;
  final http.Client _client;
  final Duration _timeout;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _accessTokenExpiresAt;
  Future<AuthSession>? _refreshInFlight;

  /// Called after a successful token refresh so the rotated tokens can be
  /// persisted immediately (the old refresh token is dead once rotated).
  void Function(AuthSession session)? onSessionRefreshed;

  /// 401 codes for which one `/auth/refresh` attempt is made.
  static const _refreshableCodes = {'token_expired', 'invalid_access_token', 'missing_bearer_token'};

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

  // ---------------------------------------------------------------- dashboard

  Future<ReconnectDashboardData> fetchDashboard({required String location}) async {
    final response = await _authed(
      () => _client.get(
        _endpoint('/v1/dashboard', location.isEmpty ? null : {'location': location}),
        headers: _jsonHeaders,
      ),
    );
    return _dashboardFrom(response);
  }

  // --------------------------------------------------------------------- auth

  Future<AuthSession> signUp({
    required String email,
    required String phone,
    required String password,
    required String name,
    required String bio,
    required String homeCity,
  }) async {
    final response = await _send(
      () => _client.post(
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
      ),
    );
    return _adoptSession(_decodeObject(response));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    String? deviceLabel,
  }) async {
    final response = await _send(
      () => _client.post(
        _endpoint('/v1/auth/login'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceLabel': ?deviceLabel,
        }),
      ),
    );
    return _adoptSession(_decodeObject(response));
  }

  /// Rotates the refresh token. Concurrent callers share one request because
  /// presenting an already-rotated token revokes the whole session.
  Future<AuthSession> refreshSession() {
    return _refreshInFlight ??= _refreshOnce().whenComplete(() => _refreshInFlight = null);
  }

  Future<AuthSession> _refreshOnce() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const ReconnectApiException(
        statusCode: 401,
        code: 'invalid_refresh_token',
        message: 'No refresh token is available.',
      );
    }

    final response = await _send(
      () => _client.post(
        _endpoint('/v1/auth/refresh'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );
    final session = _adoptSession(_decodeObject(response));
    onSessionRefreshed?.call(session);
    return session;
  }

  /// Revokes the current session on the server.
  Future<void> logout() async {
    await _authed(
      () => _client.post(_endpoint('/v1/auth/logout'), headers: _jsonHeaders, body: '{}'),
    );
  }

  /// Revokes every session of the user.
  Future<void> logoutAll() async {
    await _authed(
      () => _client.post(_endpoint('/v1/auth/logout-all'), headers: _jsonHeaders, body: '{}'),
    );
  }

  Future<void> sendPhoneVerification() async {
    await _authed(
      () => _client.post(_endpoint('/v1/auth/verify/phone/send'), headers: _jsonHeaders, body: '{}'),
    );
  }

  Future<ReconnectProfile> confirmPhoneVerification(String code) async {
    final response = await _authed(
      () => _client.post(
        _endpoint('/v1/auth/verify/phone/confirm'),
        headers: _jsonHeaders,
        body: jsonEncode({'code': code}),
      ),
    );
    return _profileFrom(response);
  }

  Future<void> sendEmailVerification() async {
    await _authed(
      () => _client.post(_endpoint('/v1/auth/verify/email/send'), headers: _jsonHeaders, body: '{}'),
    );
  }

  Future<ReconnectProfile> confirmEmailVerification(String code) async {
    final response = await _authed(
      () => _client.post(
        _endpoint('/v1/auth/verify/email/confirm'),
        headers: _jsonHeaders,
        body: jsonEncode({'code': code}),
      ),
    );
    return _profileFrom(response);
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _send(
      () => _client.post(
        _endpoint('/v1/auth/password-reset/request'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email}),
      ),
    );
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _send(
      () => _client.post(
        _endpoint('/v1/auth/password-reset/confirm'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'code': code, 'newPassword': newPassword}),
      ),
    );
  }

  // ------------------------------------------------------------------ account

  Future<Map<String, dynamic>> exportAccount() async {
    final response = await _authed(
      () => _client.get(_endpoint('/v1/account/export'), headers: _jsonHeaders),
    );
    return _decodeObject(response);
  }

  /// Hard-deletes the account. A wrong password is reported as
  /// `invalid_credentials` and does not end the session.
  Future<void> deleteAccount({required String password}) async {
    await _authed(
      () => _client.delete(
        _endpoint('/v1/account'),
        headers: _jsonHeaders,
        body: jsonEncode({'password': password}),
      ),
    );
  }

  // ------------------------------------------------- contacts, location, profile

  Future<ReconnectDashboardData> importContacts({
    required String location,
    required List<ImportedDeviceContact> contacts,
  }) async {
    final response = await _authed(
      () => _client.post(
        _endpoint('/v1/contacts/import'),
        headers: _jsonHeaders,
        body: jsonEncode({
          if (location.isNotEmpty) 'location': location,
          'contacts': contacts.map((contact) => contact.toJson()).toList(growable: false),
        }),
      ),
    );
    return _dashboardFrom(response);
  }

  Future<ReconnectDashboardData> updatePreference({
    required String contactId,
    required ReconnectPreference preference,
  }) async {
    final response = await _authed(
      () => _client.patch(
        _endpoint('/v1/contacts/${Uri.encodeComponent(contactId)}/preference'),
        headers: _jsonHeaders,
        body: jsonEncode({'preference': preference.name}),
      ),
    );
    return _dashboardFrom(response);
  }

  Future<ReconnectDashboardData> updateLocation({required String location}) async {
    final response = await _authed(
      () => _client.patch(
        _endpoint('/v1/location'),
        headers: _jsonHeaders,
        body: jsonEncode({'location': location}),
      ),
    );
    return _dashboardFrom(response);
  }

  Future<ReconnectDashboardData> updateLocationFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _authed(
      () => _client.patch(
        _endpoint('/v1/location'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ),
    );
    return _dashboardFrom(response);
  }

  /// Only the fields that are passed are sent.
  Future<ReconnectDashboardData> updateProfile({
    String? bio,
    String? homeCity,
    String? profileImageUrl,
    bool? locationShared,
  }) async {
    final response = await _authed(
      () => _client.patch(
        _endpoint('/v1/profile'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'bio': ?bio,
          'homeCity': ?homeCity,
          'profileImageUrl': ?profileImageUrl,
          'locationShared': ?locationShared,
        }),
      ),
    );
    return _dashboardFrom(response);
  }

  Future<ContactMatches> fetchContactMatches() async {
    final response = await _authed(
      () => _client.get(
        _endpoint('/v1/contacts/matches'),
        headers: _jsonHeaders,
      ),
    );
    return ContactMatches.fromJson(_decodeObject(response));
  }

  void close() {
    _client.close();
  }

  // ------------------------------------------------------------------ helpers

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

  AuthSession _adoptSession(Map<String, dynamic> body) {
    final session = AuthSession.fromJson(body);
    setAuthSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessTokenExpiresAt: session.accessTokenExpiresAt,
    );
    return session;
  }

  ReconnectDashboardData _dashboardFrom(http.Response response) {
    return ReconnectDashboardData.fromJson(_decodeObject(response));
  }

  ReconnectProfile _profileFrom(http.Response response) {
    final body = _decodeObject(response);
    return ReconnectProfile.fromJson(body['profile'] as Map<String, dynamic>? ?? body);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ReconnectApiException(
        statusCode: response.statusCode,
        code: 'invalid_response',
        message: 'The server sent an unexpected response.',
      );
    } on TypeError {
      throw ReconnectApiException(
        statusCode: response.statusCode,
        code: 'invalid_response',
        message: 'The server sent an unexpected response.',
      );
    }
  }

  /// Sends one request, mapping transport failures to a network error and
  /// non-2xx responses to a [ReconnectApiException].
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(_timeout);
    } on TimeoutException {
      throw const ReconnectApiException.network();
    } on http.ClientException {
      throw const ReconnectApiException.network();
    }
    _ensureSuccess(response);
    return response;
  }

  /// Like [_send] for authenticated routes: on a 401 access-token problem it
  /// calls `/auth/refresh` once and retries the request once.
  Future<http.Response> _authed(Future<http.Response> Function() call) async {
    try {
      return await _send(call);
    } on ReconnectApiException catch (error) {
      final refreshable = error.statusCode == 401 && _refreshableCodes.contains(error.code);
      if (!refreshable || !hasRefreshToken) {
        rethrow;
      }
    }

    await refreshSession();
    return _send(call);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = '';
    String? code;
    String? requestId;
    int? retryAfter;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['error'] as String? ?? '';
      code = body['code'] as String?;
      requestId = body['requestId'] as String?;
      final rawRetry = body['retryAfterSeconds'];
      retryAfter = rawRetry is num ? rawRetry.toInt() : null;
    } catch (_) {
      // Not the JSON envelope (e.g. a proxy error page): keep defaults.
    }
    retryAfter ??= int.tryParse(response.headers['retry-after'] ?? '');

    throw ReconnectApiException(
      statusCode: response.statusCode,
      message: message,
      code: code,
      requestId: requestId,
      retryAfterSeconds: retryAfter,
    );
  }
}
