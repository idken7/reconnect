import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

class BackendHttpException implements Exception {
  const BackendHttpException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;
}

class PersistentStore {
  PersistentStore(this.file);

  final File file;

  Map<String, dynamic> load() {
    if (!file.existsSync()) {
      final seed = _seedState();
      save(seed);
      return seed;
    }

    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) {
      final seed = _seedState();
      save(seed);
      return seed;
    }

    final state = jsonDecode(raw) as Map<String, dynamic>;
    var changed = false;

    if (!state.containsKey('accessSessions') && state.containsKey('sessions')) {
      state['accessSessions'] = state['sessions'];
      state.remove('sessions');
      changed = true;
    }

    if (!state.containsKey('accessSessions')) {
      state['accessSessions'] = <Map<String, dynamic>>[];
      changed = true;
    }

    if (!state.containsKey('refreshSessions')) {
      state['refreshSessions'] = <Map<String, dynamic>>[];
      changed = true;
    }

    if (!state.containsKey('users')) {
      state['users'] = <Map<String, dynamic>>[];
      changed = true;
    }

    if (!state.containsKey('userStates')) {
      state['userStates'] = <String, dynamic>{};
      changed = true;
    }

    if (changed) {
      save(state);
    }

    return state;
  }

  void save(Map<String, dynamic> state) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(state),
      flush: true,
    );
  }

  Map<String, dynamic> _seedState() {
    return {
      'users': <Map<String, dynamic>>[
        {
          'id': 'seed-user-1',
          'email': 'avery@example.com',
          'phone': '+14155550124',
          'passwordHash': _hash('password123'),
          'name': 'Avery Stone',
          'homeCity': 'Brooklyn',
          'bio': 'Trying to reconnect with the people who made earlier chapters worth remembering.',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      ],
      'accessSessions': <Map<String, dynamic>>[],
      'refreshSessions': <Map<String, dynamic>>[],
      'userStates': <String, dynamic>{
        'seed-user-1': {
          'currentLocation': 'Brooklyn',
          'contactsImported': false,
          'contacts': <Map<String, dynamic>>[],
          'matches': {
            'mutual': <Map<String, dynamic>>[],
            'oneWay': <Map<String, dynamic>>[],
            'notOnApp': <Map<String, dynamic>>[],
          },
        },
      },
    };
  }
}

class BackendState {
  BackendState(
    this.store, {
    this.accessTokenTtl = const Duration(minutes: 15),
    this.refreshTokenTtl = const Duration(days: 30),
  }) : _state = store.load();

  final PersistentStore store;
  final Duration accessTokenTtl;
  final Duration refreshTokenTtl;
  Map<String, dynamic> _state;

  static const List<String> supportedLocations = <String>[
    'Brooklyn',
    'Manhattan',
    'Austin',
    'Chicago',
  ];

  static const List<Map<String, dynamic>> directoryContacts = <Map<String, dynamic>>[
    {
      'id': 'directory-1',
      'name': 'Jordan Patel',
      'email': 'jordan@example.com',
      'phone': '+12125550180',
      'isOnApp': true,
      'lastSeen': '2 weeks ago',
      'availableIn': ['Brooklyn', 'Manhattan'],
      'preference': 'loveToSee',
      'mutual': true,
    },
    {
      'id': 'directory-2',
      'name': 'Maya Chen',
      'email': 'maya@example.com',
      'phone': '+16465550148',
      'isOnApp': true,
      'lastSeen': '3 years ago',
      'availableIn': ['Brooklyn', 'Chicago'],
      'preference': 'loveToSee',
      'mutual': true,
    },
    {
      'id': 'directory-3',
      'name': 'Sam Rivera',
      'email': 'sam@example.com',
      'phone': '+15125550199',
      'isOnApp': true,
      'lastSeen': '8 months ago',
      'availableIn': ['Austin'],
      'preference': 'neutral',
      'mutual': false,
    },
    {
      'id': 'directory-4',
      'name': 'Nina Brooks',
      'email': 'nina@example.com',
      'phone': '+13125550116',
      'isOnApp': false,
      'lastSeen': 'Unknown',
      'availableIn': ['Chicago'],
      'preference': 'neutral',
      'mutual': false,
    },
    {
      'id': 'directory-5',
      'name': 'Leo Morgan',
      'email': 'leo@example.com',
      'phone': '+13475550172',
      'isOnApp': true,
      'lastSeen': '1 month ago',
      'availableIn': ['Manhattan'],
      'preference': 'ratherAvoid',
      'mutual': false,
    },
  ];

  Map<String, dynamic> signUp(Map<String, dynamic> payload) {
    final email = (payload['email'] as String? ?? '').trim().toLowerCase();
    final phone = _normalizePhone(payload['phone'] as String? ?? '');
    final password = payload['password'] as String? ?? '';
    if (email.isEmpty || password.length < 8 || phone.isEmpty) {
      throw const BackendHttpException(
        statusCode: 400,
        code: 'validation_error',
        message: 'email, phone, and password (min 8 chars) are required.',
      );
    }

    final users = _users;
    final exists = users.any((user) => user['email'] == email);
    if (exists) {
      throw const BackendHttpException(
        statusCode: 409,
        code: 'account_exists',
        message: 'Account already exists for this email.',
      );
    }

    final userId = _id('user');
    final user = <String, dynamic>{
      'id': userId,
      'email': email,
      'phone': phone,
      'passwordHash': _hash(password),
      'name': (payload['name'] as String? ?? '').trim().isEmpty ? 'New User' : (payload['name'] as String).trim(),
      'homeCity': (payload['homeCity'] as String? ?? 'Brooklyn').trim(),
      'bio': (payload['bio'] as String? ?? '').trim(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    users.add(user);
    _userStates[userId] = {
      'currentLocation': user['homeCity'],
      'contactsImported': false,
      'contacts': <Map<String, dynamic>>[],
      'matches': {
        'mutual': <Map<String, dynamic>>[],
        'oneWay': <Map<String, dynamic>>[],
        'notOnApp': <Map<String, dynamic>>[],
      },
    };

    final session = _createAuthSession(userId);
    _persist();
    return {
      ...session,
      'profile': _profileFor(user),
    };
  }

  Map<String, dynamic> login(Map<String, dynamic> payload) {
    final email = (payload['email'] as String? ?? '').trim().toLowerCase();
    final password = payload['password'] as String? ?? '';

    final user = _users.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['email'] == email,
          orElse: () => <String, dynamic>{},
        );

    if (user.isEmpty || user['passwordHash'] != _hash(password)) {
      throw const BackendHttpException(
        statusCode: 401,
        code: 'invalid_credentials',
        message: 'Invalid credentials.',
      );
    }

    final session = _createAuthSession(user['id'] as String);
    _persist();
    return {
      ...session,
      'profile': _profileFor(user),
    };
  }

  Map<String, dynamic> refresh(Map<String, dynamic> payload) {
    final refreshToken = (payload['refreshToken'] as String? ?? '').trim();
    if (refreshToken.isEmpty) {
      throw const BackendHttpException(
        statusCode: 400,
        code: 'validation_error',
        message: 'refreshToken is required.',
      );
    }

    final now = DateTime.now().toUtc();
    final refreshSession = _refreshSessions.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['token'] == refreshToken,
          orElse: () => <String, dynamic>{},
        );

    if (refreshSession.isEmpty) {
      throw const BackendHttpException(
        statusCode: 401,
        code: 'invalid_refresh_token',
        message: 'Refresh token is invalid.',
      );
    }

    final expiresAt = DateTime.tryParse(refreshSession['expiresAt'] as String? ?? '');
    if (expiresAt == null || expiresAt.isBefore(now)) {
      _refreshSessions.removeWhere((entry) => entry['token'] == refreshToken);
      _persist();
      throw const BackendHttpException(
        statusCode: 401,
        code: 'refresh_token_expired',
        message: 'Refresh token expired. Please log in again.',
      );
    }

    final userId = refreshSession['userId'] as String;
    _refreshSessions.removeWhere((entry) => entry['token'] == refreshToken);
    final session = _createAuthSession(userId);
    _persist();
    return session;
  }

  String authenticate(String? authorizationHeader) {
    if (authorizationHeader == null || !authorizationHeader.startsWith('Bearer ')) {
      throw const BackendHttpException(
        statusCode: 401,
        code: 'missing_bearer_token',
        message: 'Missing bearer token.',
      );
    }

    final token = authorizationHeader.substring('Bearer '.length).trim();
    final now = DateTime.now().toUtc();
    final session = _accessSessions.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['token'] == token,
          orElse: () => <String, dynamic>{},
        );

    if (session.isEmpty) {
      throw const BackendHttpException(
        statusCode: 401,
        code: 'invalid_access_token',
        message: 'Access token is invalid.',
      );
    }

    final expiresAt = DateTime.tryParse(session['expiresAt'] as String? ?? '');
    if (expiresAt == null || expiresAt.isBefore(now)) {
      _accessSessions.removeWhere((entry) => entry['token'] == token);
      _persist();
      throw const BackendHttpException(
        statusCode: 401,
        code: 'token_expired',
        message: 'Access token expired.',
      );
    }

    return session['userId'] as String;
  }

  Map<String, dynamic> dashboard(String userId, {String? location}) {
    final user = _findUser(userId);
    final state = _ensureUserState(userId);

    if (location != null && location.trim().isNotEmpty) {
      state['currentLocation'] = location.trim();
      _persist();
    }

    final contacts = (state['contacts'] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList(growable: false);
    final currentLocation = state['currentLocation'] as String;

    return {
      'profile': _profileFor(user),
      'supportedLocations': supportedLocations,
      'currentLocation': currentLocation,
      'contactsImported': state['contactsImported'] as bool? ?? false,
      'contacts': contacts,
      'suggestions': _suggestionsFor(currentLocation, contacts),
    };
  }

  Map<String, dynamic> importContacts(String userId, List<Map<String, dynamic>> deviceContacts, {String? location}) {
    final state = _ensureUserState(userId);
    if (location != null && location.trim().isNotEmpty) {
      state['currentLocation'] = location.trim();
    }

    final normalizedEmails = <String>{};
    final normalizedPhones = <String>{};

    for (final contact in deviceContacts) {
      for (final email in (contact['emails'] as List<dynamic>? ?? const <dynamic>[])) {
        final normalized = email.toString().trim().toLowerCase();
        if (normalized.isNotEmpty) {
          normalizedEmails.add(normalized);
        }
      }
      for (final phone in (contact['phones'] as List<dynamic>? ?? const <dynamic>[])) {
        final normalized = _normalizePhone(phone.toString());
        if (normalized.isNotEmpty) {
          normalizedPhones.add(normalized);
        }
      }
    }

    final appMatches = <Map<String, dynamic>>[];
    final mutual = <Map<String, dynamic>>[];
    final oneWay = <Map<String, dynamic>>[];

    for (final contact in directoryContacts) {
      final emailMatch = normalizedEmails.contains((contact['email'] as String).trim().toLowerCase());
      final phoneMatch = normalizedPhones.contains(_normalizePhone(contact['phone'] as String));
      if (!emailMatch && !phoneMatch) {
        continue;
      }

      final matched = Map<String, dynamic>.from(contact);
      appMatches.add(matched);
      if (matched['isOnApp'] == true && matched['mutual'] == true) {
        mutual.add(matched);
      } else if (matched['isOnApp'] == true) {
        oneWay.add(matched);
      }
    }

    final notOnApp = deviceContacts
        .where((deviceContact) {
          final emails = (deviceContact['emails'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim().toLowerCase())
              .toSet();
          final phones = (deviceContact['phones'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => _normalizePhone(entry.toString()))
              .toSet();

          return !directoryContacts.any((contact) {
            final emailMatch = emails.contains((contact['email'] as String).trim().toLowerCase());
            final phoneMatch = phones.contains(_normalizePhone(contact['phone'] as String));
            return emailMatch || phoneMatch;
          });
        })
        .map((contact) => <String, dynamic>{
              'name': (contact['name'] as String? ?? '').trim(),
              'status': 'notOnApp',
            })
        .toList(growable: false);

    state['contacts'] = appMatches;
    state['contactsImported'] = true;
    state['matches'] = {
      'mutual': mutual,
      'oneWay': oneWay,
      'notOnApp': notOnApp,
    };

    _persist();
    return dashboard(userId);
  }

  Map<String, dynamic> updatePreference(String userId, String contactId, String preference) {
    final state = _ensureUserState(userId);
    final contacts = (state['contacts'] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList(growable: false);

    final index = contacts.indexWhere((contact) => contact['id'] == contactId);
    if (index != -1) {
      contacts[index] = {
        ...contacts[index],
        'preference': preference,
      };
      state['contacts'] = contacts;
      _persist();
    }

    return dashboard(userId);
  }

  Map<String, dynamic> updateLocation(
    String userId, {
    String? location,
    double? latitude,
    double? longitude,
  }) {
    final state = _ensureUserState(userId);

    if (location != null && location.trim().isNotEmpty) {
      state['currentLocation'] = location.trim();
    } else if (latitude != null && longitude != null) {
      state['currentLocation'] = _locationFromCoordinates(latitude, longitude);
    }

    _persist();
    return dashboard(userId);
  }

  Map<String, dynamic> matches(String userId) {
    final state = _ensureUserState(userId);
    return Map<String, dynamic>.from(state['matches'] as Map<String, dynamic>? ?? const <String, dynamic>{
      'mutual': <Map<String, dynamic>>[],
      'oneWay': <Map<String, dynamic>>[],
      'notOnApp': <Map<String, dynamic>>[],
    });
  }

  Map<String, dynamic> _createAuthSession(String userId) {
    _accessSessions.removeWhere((entry) => entry['userId'] == userId);

    final accessToken = _token();
    final refreshToken = _token();
    final accessExpiresAt = DateTime.now().toUtc().add(accessTokenTtl);
    final refreshExpiresAt = DateTime.now().toUtc().add(refreshTokenTtl);

    _accessSessions.add({
      'token': accessToken,
      'userId': userId,
      'expiresAt': accessExpiresAt.toIso8601String(),
    });

    _refreshSessions.add({
      'token': refreshToken,
      'userId': userId,
      'expiresAt': refreshExpiresAt.toIso8601String(),
    });

    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessExpiresAt.toIso8601String(),
      'token': accessToken,
    };
  }

  Map<String, dynamic> _findUser(String userId) {
    final user = _users.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['id'] == userId,
          orElse: () => <String, dynamic>{},
        );
    if (user.isEmpty) {
      throw const BackendHttpException(
        statusCode: 404,
        code: 'user_not_found',
        message: 'User not found.',
      );
    }
    return user;
  }

  Map<String, dynamic> _profileFor(Map<String, dynamic> user) {
    return {
      'name': user['name'] as String? ?? '',
      'email': user['email'] as String? ?? '',
      'phone': user['phone'] as String? ?? '',
      'homeCity': user['homeCity'] as String? ?? 'Brooklyn',
      'bio': user['bio'] as String? ?? '',
    };
  }

  Map<String, dynamic> _ensureUserState(String userId) {
    final states = _userStates;
    final existing = states[userId];
    if (existing is Map<String, dynamic>) {
      return existing;
    }

    final created = {
      'currentLocation': 'Brooklyn',
      'contactsImported': false,
      'contacts': <Map<String, dynamic>>[],
      'matches': {
        'mutual': <Map<String, dynamic>>[],
        'oneWay': <Map<String, dynamic>>[],
        'notOnApp': <Map<String, dynamic>>[],
      },
    };
    states[userId] = created;
    return created;
  }

  List<Map<String, dynamic>> _suggestionsFor(String location, List<Map<String, dynamic>> contacts) {
    final suggestions = <Map<String, dynamic>>[];

    for (final contact in contacts) {
      final isOnApp = contact['isOnApp'] as bool? ?? false;
      final preference = contact['preference'] as String? ?? 'neutral';
      final availableIn = (contact['availableIn'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toList(growable: false);
      if (!isOnApp || preference == 'ratherAvoid' || !availableIn.contains(location)) {
        continue;
      }

      suggestions.add({
        'contact': contact,
        'reason': preference == 'loveToSee'
            ? 'Both of you are active in $location and this person is a top reconnect.'
            : 'You and this contact overlap in $location right now.',
        'distanceLabel': location == 'Brooklyn' ? 'Under 3 miles away' : 'Nearby',
      });
    }

    suggestions.sort((left, right) {
      final leftWeight = _preferenceWeight(left['contact']['preference'] as String? ?? 'neutral');
      final rightWeight = _preferenceWeight(right['contact']['preference'] as String? ?? 'neutral');
      if (leftWeight != rightWeight) {
        return leftWeight.compareTo(rightWeight);
      }
      return (left['contact']['lastSeen'] as String).compareTo(right['contact']['lastSeen'] as String);
    });

    return suggestions;
  }

  int _preferenceWeight(String preference) {
    switch (preference) {
      case 'loveToSee':
        return 0;
      case 'neutral':
        return 1;
      case 'ratherAvoid':
        return 2;
      default:
        return 1;
    }
  }

  String _locationFromCoordinates(double latitude, double longitude) {
    if (latitude > 40.68 && latitude < 40.75 && longitude > -74.05 && longitude < -73.9) {
      return 'Brooklyn';
    }
    if (latitude > 40.70 && latitude < 40.83 && longitude > -74.03 && longitude < -73.92) {
      return 'Manhattan';
    }
    if (latitude > 30.20 && latitude < 30.40 && longitude > -97.90 && longitude < -97.60) {
      return 'Austin';
    }
    if (latitude > 41.80 && latitude < 42.05 && longitude > -87.85 && longitude < -87.50) {
      return 'Chicago';
    }
    return 'Brooklyn';
  }

  String _id(String prefix) {
    final random = Random.secure();
    final value = List<int>.generate(10, (_) => random.nextInt(256));
    return '$prefix-${base64UrlEncode(value).replaceAll('=', '')}';
  }

  String _token() {
    final random = Random.secure();
    final value = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(value).replaceAll('=', '');
  }

  List<dynamic> get _users => _state['users'] as List<dynamic>;
  List<dynamic> get _accessSessions => _state['accessSessions'] as List<dynamic>;
  List<dynamic> get _refreshSessions => _state['refreshSessions'] as List<dynamic>;
  Map<String, dynamic> get _userStates => _state['userStates'] as Map<String, dynamic>;

  void _persist() {
    store.save(_state);
  }
}

Future<HttpServer> startBackendServer({
  String storePath = 'data/store.json',
  int port = 8080,
  Duration accessTokenTtl = const Duration(minutes: 15),
  Duration refreshTokenTtl = const Duration(days: 30),
}) async {
  final store = PersistentStore(File(storePath));
  final state = BackendState(
    store,
    accessTokenTtl: accessTokenTtl,
    refreshTokenTtl: refreshTokenTtl,
  );
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  server.listen((request) {
    unawaited(_handleRequest(request, state));
  });

  return server;
}

Future<void> _handleRequest(HttpRequest request, BackendState state) async {
  if (request.method == 'OPTIONS') {
    _writeJson(request.response, 200, {'ok': true});
    return;
  }

  final uri = request.uri;
  try {
    if (request.method == 'GET' && uri.path == '/health') {
      _writeJson(request.response, 200, {'status': 'ok'});
    } else if (request.method == 'POST' && uri.path == '/v1/auth/signup') {
      final payload = await _bodyAsJson(request);
      _writeJson(request.response, 200, state.signUp(payload));
    } else if (request.method == 'POST' && uri.path == '/v1/auth/login') {
      final payload = await _bodyAsJson(request);
      _writeJson(request.response, 200, state.login(payload));
    } else if (request.method == 'POST' && uri.path == '/v1/auth/refresh') {
      final payload = await _bodyAsJson(request);
      _writeJson(request.response, 200, state.refresh(payload));
    } else if (request.method == 'GET' && uri.path == '/v1/dashboard') {
      final userId = state.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
      final location = uri.queryParameters['location'];
      _writeJson(request.response, 200, state.dashboard(userId, location: location));
    } else if (request.method == 'POST' && uri.path == '/v1/contacts/import') {
      final userId = state.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
      final payload = await _bodyAsJson(request);
      final contacts = (payload['contacts'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(growable: false);
      _writeJson(
        request.response,
        200,
        state.importContacts(userId, contacts, location: payload['location'] as String?),
      );
    } else if (request.method == 'GET' && uri.path == '/v1/contacts/matches') {
      final userId = state.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
      _writeJson(request.response, 200, state.matches(userId));
    } else if (request.method == 'PATCH' && uri.path.startsWith('/v1/contacts/') && uri.path.endsWith('/preference')) {
      final userId = state.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
      final contactId = uri.pathSegments.length >= 3 ? uri.pathSegments[2] : '';
      final payload = await _bodyAsJson(request);
      _writeJson(
        request.response,
        200,
        state.updatePreference(userId, contactId, payload['preference'] as String? ?? 'neutral'),
      );
    } else if (request.method == 'PATCH' && uri.path == '/v1/location') {
      final userId = state.authenticate(request.headers.value(HttpHeaders.authorizationHeader));
      final payload = await _bodyAsJson(request);
      _writeJson(
        request.response,
        200,
        state.updateLocation(
          userId,
          location: payload['location'] as String?,
          latitude: (payload['latitude'] as num?)?.toDouble(),
          longitude: (payload['longitude'] as num?)?.toDouble(),
        ),
      );
    } else {
      _writeJson(
        request.response,
        404,
        {
          'code': 'not_found',
          'error': 'Not found',
        },
      );
    }
  } on BackendHttpException catch (error) {
    _writeJson(
      request.response,
      error.statusCode,
      {
        'code': error.code,
        'error': error.message,
      },
    );
  } catch (error) {
    _writeJson(
      request.response,
      500,
      {
        'code': 'internal_error',
        'error': error.toString(),
      },
    );
  }
}

Future<void> main(List<String> args) async {
  final storePath = args.isNotEmpty ? args.first : 'data/store.json';
  final server = await startBackendServer(storePath: storePath, port: 8080);
  stdout.writeln('Reconnect backend listening on http://${server.address.host}:${server.port}');
  stdout.writeln('Persistent store: ${File(storePath).absolute.path}');

  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
}

Future<Map<String, dynamic>> _bodyAsJson(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.trim().isEmpty) {
    return <String, dynamic>{};
  }
  return jsonDecode(raw) as Map<String, dynamic>;
}

void _writeJson(HttpResponse response, int statusCode, Map<String, dynamic> body) {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  response.headers.set(HttpHeaders.accessControlAllowHeadersHeader, 'content-type, authorization');
  response.headers.set(HttpHeaders.accessControlAllowMethodsHeader, 'GET,POST,PATCH,OPTIONS');
  response.write(jsonEncode(body));
  response.close();
}

String _normalizePhone(String input) {
  return input.replaceAll(RegExp(r'[^0-9+]'), '');
}

String _hash(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}
