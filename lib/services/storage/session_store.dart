import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The auth tokens persisted between launches.
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? accessTokenExpiresAt;
}

/// Where auth tokens live. Production uses [SecureSessionStore]
/// (Keychain / Android Keystore); tests use [InMemorySessionStore].
abstract class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const accessTokenKey = 'reconnect_auth_token';
  static const refreshTokenKey = 'reconnect_refresh_token';
  static const expiryKey = 'reconnect_auth_token_expiry';

  @override
  Future<StoredSession?> read() async {
    try {
      final accessToken = await _storage.read(key: accessTokenKey);
      if (accessToken == null || accessToken.isEmpty) {
        return null;
      }
      final refreshToken = await _storage.read(key: refreshTokenKey);
      final expiryRaw = await _storage.read(key: expiryKey);
      return StoredSession(
        accessToken: accessToken,
        refreshToken: refreshToken ?? '',
        accessTokenExpiresAt: expiryRaw == null ? null : DateTime.tryParse(expiryRaw)?.toUtc(),
      );
    } catch (error) {
      // An unreadable keystore (e.g. after a restore to another device) must
      // not crash startup; the user simply signs in again.
      debugPrint('Secure storage read failed: ${error.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) async {
    await _storage.write(key: accessTokenKey, value: session.accessToken);
    await _storage.write(key: refreshTokenKey, value: session.refreshToken);
    final expiry = session.accessTokenExpiresAt;
    if (expiry != null) {
      await _storage.write(key: expiryKey, value: expiry.toUtc().toIso8601String());
    } else {
      await _storage.delete(key: expiryKey);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (error) {
      debugPrint('Secure storage clear failed: ${error.runtimeType}');
    }
  }
}

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

/// One-time move of tokens from SharedPreferences to a [SessionStore].
class LegacyTokenMigration {
  const LegacyTokenMigration._();

  static const _legacyKeys = [
    SecureSessionStore.accessTokenKey,
    SecureSessionStore.refreshTokenKey,
    SecureSessionStore.expiryKey,
  ];

  /// Marks that the secure store has been initialised for this install.
  static const initializedKey = 'reconnect_secure_storage_initialized';

  /// Copies tokens still sitting in [prefs] into [store] and deletes the old
  /// keys. Also runs on first launch of a fresh install: iOS Keychain items
  /// survive an uninstall, so stale tokens left by a previous install are
  /// wiped instead of silently logging the user in.
  static Future<void> run(SharedPreferences prefs, SessionStore store) async {
    final legacyAccess = prefs.getString(SecureSessionStore.accessTokenKey);
    final legacyRefresh = prefs.getString(SecureSessionStore.refreshTokenKey);
    final legacyExpiry = prefs.getString(SecureSessionStore.expiryKey);

    if (legacyAccess != null && legacyAccess.isNotEmpty) {
      await store.write(
        StoredSession(
          accessToken: legacyAccess,
          refreshToken: legacyRefresh ?? '',
          accessTokenExpiresAt: legacyExpiry == null ? null : DateTime.tryParse(legacyExpiry)?.toUtc(),
        ),
      );
    } else if (!(prefs.getBool(initializedKey) ?? false)) {
      await store.clear();
    }

    // Mark initialised before deleting the old keys, so a crash in between
    // can never look like a fresh install and wipe a migrated session.
    await prefs.setBool(initializedKey, true);
    for (final key in _legacyKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }
}
