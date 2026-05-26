import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:reconnect/services/backend/reconnect_api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  group('ReconnectApiClient', () {
    late MockHttpClient mockHttpClient;
    late ReconnectApiClient apiClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      apiClient = ReconnectApiClient(
        baseUri: Uri.parse('http://localhost:8080'),
        client: mockHttpClient,
      );
    });

    test('setAuthSession stores authentication tokens', () {
      const accessToken = 'test-access-token';
      const refreshToken = 'test-refresh-token';
      final expiresAt = DateTime.now().add(const Duration(hours: 1));

      apiClient.setAuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: expiresAt,
      );

      expect(apiClient.currentSession?.accessToken, equals(accessToken));
      expect(apiClient.currentSession?.refreshToken, equals(refreshToken));
    });

    test('isAccessTokenExpired returns true for past expiry time', () {
      final expiresAt = DateTime.now().subtract(const Duration(hours: 1));

      apiClient.setAuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        accessTokenExpiresAt: expiresAt,
      );

      expect(apiClient.isAccessTokenExpired, isTrue);
    });

    test('isAccessTokenExpired returns false for future expiry time', () {
      final expiresAt = DateTime.now().add(const Duration(hours: 1));

      apiClient.setAuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        accessTokenExpiresAt: expiresAt,
      );

      expect(apiClient.isAccessTokenExpired, isFalse);
    });

    test('setAuthSession with null values clears tokens', () {
      apiClient.setAuthSession(
        accessToken: null,
        refreshToken: null,
        accessTokenExpiresAt: null,
      );

      expect(apiClient.currentSession, isNull);
    });

    test('hasRefreshToken returns true when refresh token is set', () {
      apiClient.setAuthSession(
        accessToken: 'token',
        refreshToken: 'refresh-token',
        accessTokenExpiresAt: DateTime.now(),
      );

      expect(apiClient.hasRefreshToken, isTrue);
    });

    test('hasRefreshToken returns false when refresh token is null', () {
      apiClient.setAuthSession(
        accessToken: 'token',
        refreshToken: null,
        accessTokenExpiresAt: DateTime.now(),
      );

      expect(apiClient.hasRefreshToken, isFalse);
    });

    test('hasRefreshToken returns false when refresh token is empty', () {
      apiClient.setAuthSession(
        accessToken: 'token',
        refreshToken: '',
        accessTokenExpiresAt: DateTime.now(),
      );

      expect(apiClient.hasRefreshToken, isFalse);
    });
  });
}
