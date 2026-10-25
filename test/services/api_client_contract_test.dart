import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/backend/reconnect_api_client.dart';

http.Response jsonResponse(int status, Object body, {Map<String, String> headers = const {}}) {
  return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});
}

Map<String, dynamic> errorBody(String code, {int? retryAfter}) => {
      'code': code,
      'error': 'Message for $code',
      'requestId': 'req-123',
      'retryAfterSeconds': ?retryAfter,
    };

final dashboardJson = {
  'profile': {'name': 'A', 'email': 'a@example.com', 'phone': '+14155550124', 'homeCity': 'Brooklyn', 'bio': ''},
  'supportedLocations': ['Brooklyn', 'Other'],
  'currentLocation': 'Brooklyn',
  'contactsImported': false,
  'contacts': <dynamic>[],
  'suggestions': <dynamic>[],
};

final refreshJson = {
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'accessTokenExpiresAt': '2099-01-01T00:00:00Z',
  'token': 'new-access',
};

ReconnectApiClient clientFor(MockClient mock) {
  final client = ReconnectApiClient(baseUri: Uri.parse('https://api.test'), client: mock, timeout: const Duration(seconds: 2));
  client.setAuthSession(
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
    accessTokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  return client;
}

void main() {
  group('error envelope', () {
    test('parses code, requestId and retryAfterSeconds from a 429', () async {
      final client = clientFor(MockClient((_) async => jsonResponse(429, errorBody('rate_limited', retryAfter: 42))));

      final error = await client.fetchDashboard(location: 'Brooklyn').then<ReconnectApiException?>((_) => null).catchError(
            (Object e) => e as ReconnectApiException,
          );

      expect(error, isNotNull);
      expect(error!.statusCode, 429);
      expect(error.code, 'rate_limited');
      expect(error.requestId, 'req-123');
      expect(error.retryAfterSeconds, 42);
      expect(error.isRateLimited, isTrue);
      expect(error.friendlyMessage, contains('42 seconds'));
    });

    test('falls back to the Retry-After header', () async {
      final client = clientFor(
        MockClient((_) async => jsonResponse(429, {'code': 'rate_limited', 'error': 'slow down'}, headers: {'retry-after': '120'})),
      );
      await expectLater(
        client.fetchDashboard(location: 'x'),
        throwsA(isA<ReconnectApiException>().having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 120)),
      );
    });

    test('403 verification_required has a friendly message and does not sign out', () async {
      final client = clientFor(MockClient((_) async => jsonResponse(403, errorBody('verification_required'))));
      await expectLater(
        client.fetchDashboard(location: 'x'),
        throwsA(
          isA<ReconnectApiException>()
              .having((e) => e.isVerificationRequired, 'isVerificationRequired', isTrue)
              .having((e) => e.shouldSignOut, 'shouldSignOut', isFalse)
              .having((e) => e.friendlyMessage, 'friendlyMessage', contains('verify your phone')),
        ),
      );
    });

    test('5xx friendly message includes the request id', () async {
      final client = clientFor(MockClient((_) async => jsonResponse(500, errorBody('internal_error'))));
      await expectLater(
        client.fetchDashboard(location: 'x'),
        throwsA(isA<ReconnectApiException>().having((e) => e.friendlyMessage, 'friendlyMessage', contains('req-123'))),
      );
    });

    test('a non-JSON error body does not crash the parser', () async {
      final client = clientFor(MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)));
      await expectLater(
        client.fetchDashboard(location: 'x'),
        throwsA(isA<ReconnectApiException>().having((e) => e.statusCode, 'statusCode', 502)),
      );
    });

    test('transport failures become network errors', () async {
      final client = clientFor(MockClient((_) async => throw http.ClientException('Connection refused')));
      await expectLater(
        client.fetchDashboard(location: 'x'),
        throwsA(isA<ReconnectApiException>().having((e) => e.isNetworkError, 'isNetworkError', isTrue)),
      );
    });

    test('timeouts become network errors', () async {
      final client = ReconnectApiClient(
        baseUri: Uri.parse('https://api.test'),
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        client.fetchDashboard(location: 'x'),
        throwsA(isA<ReconnectApiException>().having((e) => e.isNetworkError, 'isNetworkError', isTrue)),
      );
    });
  });

  group('refresh handling', () {
    test('token_expired triggers exactly one refresh and one retry with the new token', () async {
      final seen = <String>[];
      final client = clientFor(
        MockClient((request) async {
          seen.add('${request.method} ${request.url.path} ${request.headers['Authorization'] ?? '-'}');
          if (request.url.path == '/v1/auth/refresh') {
            expect(jsonDecode(request.body), {'refreshToken': 'old-refresh'});
            return jsonResponse(200, refreshJson);
          }
          if (request.headers['Authorization'] == 'Bearer old-access') {
            return jsonResponse(401, errorBody('token_expired'));
          }
          return jsonResponse(200, dashboardJson);
        }),
      );
      AuthSession? persisted;
      client.onSessionRefreshed = (session) => persisted = session;

      final dashboard = await client.fetchDashboard(location: 'Brooklyn');

      expect(dashboard.profile.name, 'A');
      expect(seen, [
        'GET /v1/dashboard Bearer old-access',
        'POST /v1/auth/refresh -',
        'GET /v1/dashboard Bearer new-access',
      ]);
      expect(persisted?.refreshToken, 'new-refresh');
      expect(client.currentSession?.refreshToken, 'new-refresh');
    });

    test('the rotated refresh token is persisted before the request is retried', () async {
      var persisted = false;
      var persistedBeforeRetry = false;
      final client = clientFor(
        MockClient((request) async {
          if (request.url.path == '/v1/auth/refresh') return jsonResponse(200, refreshJson);
          if (request.headers['Authorization'] == 'Bearer old-access') {
            return jsonResponse(401, errorBody('token_expired'));
          }
          persistedBeforeRetry = persisted;
          return jsonResponse(200, dashboardJson);
        }),
      );
      client.onSessionRefreshed = (session) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        persisted = true;
      };

      await client.fetchDashboard(location: 'x');

      expect(persistedBeforeRetry, isTrue);
    });

    test('a second 401 after refreshing is not retried again', () async {
      var dashboardCalls = 0;
      final client = clientFor(
        MockClient((request) async {
          if (request.url.path == '/v1/auth/refresh') return jsonResponse(200, refreshJson);
          dashboardCalls++;
          return jsonResponse(401, errorBody('token_expired'));
        }),
      );

      await expectLater(client.fetchDashboard(location: 'x'), throwsA(isA<ReconnectApiException>()));
      expect(dashboardCalls, 2);
    });

    for (final code in ['invalid_refresh_token', 'refresh_token_reused', 'refresh_token_expired']) {
      test('$code during refresh surfaces as a sign-out error', () async {
        final client = clientFor(
          MockClient((request) async {
            if (request.url.path == '/v1/auth/refresh') return jsonResponse(401, errorBody(code));
            return jsonResponse(401, errorBody('token_expired'));
          }),
        );

        await expectLater(
          client.fetchDashboard(location: 'x'),
          throwsA(
            isA<ReconnectApiException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.shouldSignOut, 'shouldSignOut', isTrue),
          ),
        );
      });
    }

    test('invalid_credentials never triggers a refresh or a sign-out', () async {
      var refreshed = false;
      final client = clientFor(
        MockClient((request) async {
          if (request.url.path == '/v1/auth/refresh') refreshed = true;
          return jsonResponse(401, errorBody('invalid_credentials'));
        }),
      );

      await expectLater(
        client.deleteAccount(password: 'wrong'),
        throwsA(isA<ReconnectApiException>().having((e) => e.shouldSignOut, 'shouldSignOut', isFalse)),
      );
      expect(refreshed, isFalse);
    });

    test('concurrent expired requests share a single refresh', () async {
      var refreshCalls = 0;
      final client = clientFor(
        MockClient((request) async {
          if (request.url.path == '/v1/auth/refresh') {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return jsonResponse(200, refreshJson);
          }
          if (request.headers['Authorization'] == 'Bearer old-access') {
            return jsonResponse(401, errorBody('token_expired'));
          }
          return jsonResponse(200, dashboardJson);
        }),
      );

      await Future.wait([client.fetchDashboard(location: 'a'), client.fetchDashboard(location: 'b')]);
      expect(refreshCalls, 1);
    });
  });

  group('contract routes', () {
    test('logout, logout-all and verification sends are authenticated POSTs', () async {
      final seen = <String>[];
      final client = clientFor(
        MockClient((request) async {
          seen.add('${request.method} ${request.url.path} ${request.headers['Authorization']}');
          return jsonResponse(200, {'ok': true});
        }),
      );

      await client.logout();
      await client.logoutAll();
      await client.sendPhoneVerification();
      await client.sendEmailVerification();

      expect(seen, [
        'POST /v1/auth/logout Bearer old-access',
        'POST /v1/auth/logout-all Bearer old-access',
        'POST /v1/auth/verify/phone/send Bearer old-access',
        'POST /v1/auth/verify/email/send Bearer old-access',
      ]);
    });

    test('verification confirm sends the code and returns the profile', () async {
      final client = clientFor(
        MockClient((request) async {
          expect(request.url.path, '/v1/auth/verify/phone/confirm');
          expect(jsonDecode(request.body), {'code': '123456'});
          return jsonResponse(200, {
            'profile': {...(dashboardJson['profile'] as Map<String, dynamic>), 'phoneVerified': true},
          });
        }),
      );
      final profile = await client.confirmPhoneVerification('123456');
      expect(profile.phoneVerified, isTrue);
    });

    test('password reset routes need no auth', () async {
      final seen = <http.Request>[];
      final client = ReconnectApiClient(
        baseUri: Uri.parse('https://api.test'),
        client: MockClient((request) async {
          seen.add(request);
          return jsonResponse(200, {'ok': true});
        }),
      );

      await client.requestPasswordReset(email: 'a@example.com');
      await client.confirmPasswordReset(email: 'a@example.com', code: '654321', newPassword: 'correct horse');

      expect(seen[0].url.path, '/v1/auth/password-reset/request');
      expect(jsonDecode(seen[0].body), {'email': 'a@example.com'});
      expect(seen[1].url.path, '/v1/auth/password-reset/confirm');
      expect(jsonDecode(seen[1].body), {'email': 'a@example.com', 'code': '654321', 'newPassword': 'correct horse'});
      expect(seen.every((r) => !r.headers.containsKey('Authorization')), isTrue);
    });

    test('deleteAccount sends DELETE /v1/account with the password', () async {
      late http.Request captured;
      final client = clientFor(
        MockClient((request) async {
          captured = request;
          return jsonResponse(200, {'ok': true});
        }),
      );
      await client.deleteAccount(password: 'hunter2hunter2');
      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/v1/account');
      expect(jsonDecode(captured.body), {'password': 'hunter2hunter2'});
    });

    test('exportAccount returns the JSON document', () async {
      final client = clientFor(MockClient((_) async => jsonResponse(200, {'profile': {}, 'contacts': <dynamic>[]})));
      final data = await client.exportAccount();
      expect(data.keys, containsAll(['profile', 'contacts']));
    });

    test('updateProfile sends only the supplied fields, including locationShared', () async {
      late Map<String, dynamic> body;
      final client = clientFor(
        MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/v1/profile');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse(200, dashboardJson);
        }),
      );
      await client.updateProfile(locationShared: true);
      expect(body, {'locationShared': true});
    });

    test('login sends the optional deviceLabel and adopts the session', () async {
      late Map<String, dynamic> body;
      final client = ReconnectApiClient(
        baseUri: Uri.parse('https://api.test'),
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse(200, {
            ...refreshJson,
            'profile': {
              ...(dashboardJson['profile'] as Map<String, dynamic>),
              'phoneVerified': true,
              'locationShared': false,
              'emailVerified': false,
            },
          });
        }),
      );
      final session = await client.login(email: 'a@example.com', password: 'pw', deviceLabel: 'iPhone');
      expect(body['deviceLabel'], 'iPhone');
      expect(session.profile.phoneVerified, isTrue);
      expect(client.currentSession?.accessToken, 'new-access');
    });

    test('dashboard parses ContactObject lastSeenAt', () async {
      final json = {
        ...dashboardJson,
        'contacts': [
          {
            'id': 'u1',
            'name': 'Jordan',
            'isOnApp': true,
            'mutual': true,
            'lastSeenAt': null,
            'availableIn': ['Brooklyn'],
            'preference': 'neutral',
          },
        ],
      };
      final client = clientFor(MockClient((_) async => jsonResponse(200, json)));
      final dashboard = await client.fetchDashboard(location: 'Brooklyn');
      expect(dashboard.contacts.single.lastSeenLabel, 'Unknown');
    });
  });
}
