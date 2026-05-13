import 'dart:convert';
import 'dart:io';

import '../bin/server.dart' as backend;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late HttpServer server;
  late Uri baseUri;

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> payload, {
    String? accessToken,
  }) async {
    final client = HttpClient();
    final request = await client.postUrl(baseUri.resolve(path));
    request.headers.contentType = ContentType.json;
    if (accessToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    client.close();
    return {
      'statusCode': response.statusCode,
      'body': body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>,
    };
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
  }) async {
    final client = HttpClient();
    final request = await client.getUrl(baseUri.resolve(path));
    if (accessToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    client.close();
    return {
      'statusCode': response.statusCode,
      'body': body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>,
    };
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> payload, {
    String? accessToken,
  }) async {
    final client = HttpClient();
    final request = await client.openUrl('PATCH', baseUri.resolve(path));
    request.headers.contentType = ContentType.json;
    if (accessToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    client.close();
    return {
      'statusCode': response.statusCode,
      'body': body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>,
    };
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reconnect_backend_test_');
    final storePath = '${tempDir.path}/store.json';
    server = await backend.startBackendServer(
      storePath: storePath,
      port: 0,
      accessTokenTtl: const Duration(milliseconds: 200),
      refreshTokenTtl: const Duration(minutes: 10),
    );
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    await server.close(force: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('signup returns access/refresh tokens and profile', () async {
    final result = await postJson('/v1/auth/signup', {
      'email': 'newuser@example.com',
      'phone': '+1 (201) 555-0100',
      'password': 'password123',
      'name': 'New User',
      'homeCity': 'Austin',
      'bio': 'Hello',
    });

    expect(result['statusCode'], 200);
    final body = result['body'] as Map<String, dynamic>;
    expect((body['accessToken'] as String).isNotEmpty, true);
    expect((body['refreshToken'] as String).isNotEmpty, true);
    expect((body['profile'] as Map<String, dynamic>)['email'], 'newuser@example.com');
  });

  test('login returns fresh tokens for seed user', () async {
    final result = await postJson('/v1/auth/login', {
      'email': 'avery@example.com',
      'password': 'password123',
    });

    expect(result['statusCode'], 200);
    final body = result['body'] as Map<String, dynamic>;
    expect((body['accessToken'] as String).isNotEmpty, true);
    expect((body['refreshToken'] as String).isNotEmpty, true);
  });

  test('import, location, and matches work with valid token', () async {
    final login = await postJson('/v1/auth/login', {
      'email': 'avery@example.com',
      'password': 'password123',
    });
    final accessToken = (login['body'] as Map<String, dynamic>)['accessToken'] as String;

    final importResult = await postJson(
      '/v1/contacts/import',
      {
        'location': 'Brooklyn',
        'contacts': [
          {
            'name': 'Jordan',
            'emails': ['jordan@example.com'],
            'phones': ['+1 (212) 555-0180'],
          },
          {
            'name': 'Someone Else',
            'emails': ['nobody@none.com'],
            'phones': ['+1 (999) 000-0000'],
          },
        ],
      },
      accessToken: accessToken,
    );

    expect(importResult['statusCode'], 200);
    final importedBody = importResult['body'] as Map<String, dynamic>;
    expect(importedBody['contactsImported'], true);

    final locationResult = await patchJson(
      '/v1/location',
      {
        'latitude': 40.72,
        'longitude': -73.98,
      },
      accessToken: accessToken,
    );

    expect(locationResult['statusCode'], 200);
    final locationBody = locationResult['body'] as Map<String, dynamic>;
    expect((locationBody['currentLocation'] as String).isNotEmpty, true);

    final matches = await getJson('/v1/contacts/matches', accessToken: accessToken);
    expect(matches['statusCode'], 200);
    final matchesBody = matches['body'] as Map<String, dynamic>;
    expect(matchesBody.containsKey('mutual'), true);
    expect(matchesBody.containsKey('oneWay'), true);
    expect(matchesBody.containsKey('notOnApp'), true);
  });

  test('expired access token can refresh and continue', () async {
    final login = await postJson('/v1/auth/login', {
      'email': 'avery@example.com',
      'password': 'password123',
    });

    final body = login['body'] as Map<String, dynamic>;
    final accessToken = body['accessToken'] as String;
    final refreshToken = body['refreshToken'] as String;

    await Future<void>.delayed(const Duration(milliseconds: 250));

    final expiredDashboard = await getJson('/v1/dashboard?location=Brooklyn', accessToken: accessToken);
    expect(expiredDashboard['statusCode'], 401);
    expect((expiredDashboard['body'] as Map<String, dynamic>)['code'], 'token_expired');

    final refresh = await postJson('/v1/auth/refresh', {
      'refreshToken': refreshToken,
    });

    expect(refresh['statusCode'], 200);
    final refreshedAccess = (refresh['body'] as Map<String, dynamic>)['accessToken'] as String;

    final dashboard = await getJson('/v1/dashboard?location=Brooklyn', accessToken: refreshedAccess);
    expect(dashboard['statusCode'], 200);
    final dashBody = dashboard['body'] as Map<String, dynamic>;
    expect(dashBody.containsKey('profile'), true);
  });
}
