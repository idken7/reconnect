import 'package:postgres/postgres.dart';

import '../logging.dart';
import '../models.dart';
import 'migrator.dart';
import 'repository.dart';

/// Postgres-backed [Repository] using a connection pool.
class PostgresRepository implements Repository {
  PostgresRepository(
    String databaseUrl, {
    required this.migrationsDir,
    Logger? logger,
  })  : _pool = Pool.withUrl(databaseUrl),
        _logger = logger ?? Logger();

  final Pool<void> _pool;
  final String migrationsDir;
  final Logger _logger;

  @override
  Future<void> init() async {
    await Migrator(_pool, migrationsDir, _logger).run();
  }

  @override
  Future<bool> ping() async {
    try {
      await _pool.execute('SELECT 1').timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() => _pool.close();

  /// Test helper: wipes every table (keeps the schema).
  Future<void> truncateAll() async {
    await _pool.execute(
      'TRUNCATE users, refresh_sessions, session_tokens, verification_codes, user_contacts, '
      'contact_preferences CASCADE',
    );
  }

  // ---- users ----

  @override
  Future<void> createUser(User user) async {
    try {
      await _pool.execute(
        Sql.named('''
          INSERT INTO users (id, email, email_hash, email_verified_at, phone_e164, phone_hash, phone_verified_at,
            password_hash, name, home_city, bio, profile_image_url, current_location, location_shared,
            last_active_at, created_at)
          VALUES (@id, @email, @email_hash, @email_verified_at:timestamptz, @phone, @phone_hash,
            @phone_verified_at:timestamptz, @password_hash, @name, @home_city, @bio, @image, @location,
            @shared, @last_active:timestamptz, @created:timestamptz)
        '''),
        parameters: {
          'id': user.id,
          'email': user.email,
          'email_hash': user.emailHash,
          'email_verified_at': user.emailVerifiedAt,
          'phone': user.phone,
          'phone_hash': user.phoneHash,
          'phone_verified_at': user.phoneVerifiedAt,
          'password_hash': user.passwordHash,
          'name': user.name,
          'home_city': user.homeCity,
          'bio': user.bio,
          'image': user.profileImageUrl,
          'location': user.currentLocation,
          'shared': user.locationShared,
          'last_active': user.lastActiveAt,
          'created': user.createdAt,
        },
      );
    } on UniqueViolationException {
      throw const DuplicateUserException();
    }
  }

  @override
  Future<User?> findUserById(String id) async {
    final result = await _pool.execute(Sql.named('SELECT * FROM users WHERE id = @id'), parameters: {'id': id});
    return result.isEmpty ? null : _user(result.first);
  }

  @override
  Future<User?> findUserByEmail(String email) async {
    final result =
        await _pool.execute(Sql.named('SELECT * FROM users WHERE email = @email'), parameters: {'email': email});
    return result.isEmpty ? null : _user(result.first);
  }

  @override
  Future<User> updateUser(
    String id, {
    String? name,
    String? homeCity,
    String? bio,
    String? profileImageUrl,
    String? currentLocation,
    bool? locationShared,
  }) async {
    final result = await _pool.execute(
      Sql.named('''
        UPDATE users SET
          name = COALESCE(@name:text, name),
          home_city = COALESCE(@home_city:text, home_city),
          bio = COALESCE(@bio:text, bio),
          profile_image_url = COALESCE(@image:text, profile_image_url),
          current_location = COALESCE(@location:text, current_location),
          location_shared = COALESCE(@shared:boolean, location_shared)
        WHERE id = @id
        RETURNING *
      '''),
      parameters: {
        'id': id,
        'name': name,
        'home_city': homeCity,
        'bio': bio,
        'image': profileImageUrl,
        'location': currentLocation,
        'shared': locationShared,
      },
    );
    if (result.isEmpty) throw StateError('user not found');
    return _user(result.first);
  }

  @override
  Future<void> setPasswordHash(String userId, String passwordHash) async {
    await _pool.execute(
      Sql.named('UPDATE users SET password_hash = @hash WHERE id = @id'),
      parameters: {'id': userId, 'hash': passwordHash},
    );
  }

  @override
  Future<void> markVerified(String userId, IdentifierKind kind, DateTime at) async {
    final column = kind == IdentifierKind.phone ? 'phone_verified_at' : 'email_verified_at';
    await _pool.execute(
      Sql.named('UPDATE users SET $column = COALESCE($column, @at:timestamptz) WHERE id = @id'),
      parameters: {'id': userId, 'at': at},
    );
  }

  @override
  Future<void> touchLastActive(String userId, DateTime at) async {
    await _pool.execute(
      Sql.named('UPDATE users SET last_active_at = @at:timestamptz WHERE id = @id'),
      parameters: {'id': userId, 'at': at},
    );
  }

  @override
  Future<void> deleteUser(String userId) async {
    // Foreign keys cascade to sessions, tokens, codes, contacts and preferences.
    await _pool.execute(Sql.named('DELETE FROM users WHERE id = @id'), parameters: {'id': userId});
  }

  // ---- sessions ----

  @override
  Future<void> createSession(AuthSession session, List<SessionToken> tokens) async {
    await _pool.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO refresh_sessions (id, user_id, device_label, created_at)
          VALUES (@id, @user, @label, @created:timestamptz)
        '''),
        parameters: {
          'id': session.id,
          'user': session.userId,
          'label': session.deviceLabel,
          'created': session.createdAt,
        },
      );
      for (final token in tokens) {
        await _insertToken(tx, token);
      }
    });
  }

  Future<void> _insertToken(Session session, SessionToken token) async {
    await session.execute(
      Sql.named('''
        INSERT INTO session_tokens (id, session_id, kind, token_hash, expires_at, rotated_at)
        VALUES (@id, @session, @kind, @hash, @expires:timestamptz, @rotated:timestamptz)
      '''),
      parameters: {
        'id': token.id,
        'session': token.sessionId,
        'kind': token.kind.name,
        'hash': token.tokenHash,
        'expires': token.expiresAt,
        'rotated': token.rotatedAt,
      },
    );
  }

  @override
  Future<AccessLookup?> findAccessToken(String tokenHash) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT t.id AS t_id, t.session_id AS t_session_id, t.kind AS t_kind, t.token_hash AS t_token_hash,
               t.expires_at AS t_expires_at, t.rotated_at AS t_rotated_at,
               s.id AS s_id, s.user_id AS s_user_id, s.device_label AS s_device_label,
               s.created_at AS s_created_at, s.revoked_at AS s_revoked_at,
               u.*
        FROM session_tokens t
        JOIN refresh_sessions s ON s.id = t.session_id
        JOIN users u ON u.id = s.user_id
        WHERE t.token_hash = @hash AND t.kind = 'access' AND s.revoked_at IS NULL
      '''),
      parameters: {'hash': tokenHash},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return AccessLookup(token: _token(row, 't_'), session: _session(row, 's_'), user: _userFromMap(row));
  }

  @override
  Future<RefreshLookup?> findRefreshToken(String tokenHash) async {
    final result = await _pool.execute(
      Sql.named('''
        SELECT t.id AS t_id, t.session_id AS t_session_id, t.kind AS t_kind, t.token_hash AS t_token_hash,
               t.expires_at AS t_expires_at, t.rotated_at AS t_rotated_at,
               s.id AS s_id, s.user_id AS s_user_id, s.device_label AS s_device_label,
               s.created_at AS s_created_at, s.revoked_at AS s_revoked_at
        FROM session_tokens t
        JOIN refresh_sessions s ON s.id = t.session_id
        WHERE t.token_hash = @hash AND t.kind = 'refresh'
      '''),
      parameters: {'hash': tokenHash},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return RefreshLookup(token: _token(row, 't_'), session: _session(row, 's_'));
  }

  @override
  Future<bool> markRefreshRotated(String tokenId, DateTime at) async {
    final result = await _pool.execute(
      Sql.named('UPDATE session_tokens SET rotated_at = @at:timestamptz WHERE id = @id AND rotated_at IS NULL'),
      parameters: {'id': tokenId, 'at': at},
    );
    return result.affectedRows == 1;
  }

  @override
  Future<void> addTokens(List<SessionToken> tokens) async {
    await _pool.runTx((tx) async {
      for (final token in tokens) {
        await _insertToken(tx, token);
      }
    });
  }

  @override
  Future<void> revokeSession(String sessionId, DateTime at) async {
    await _pool.execute(
      Sql.named('UPDATE refresh_sessions SET revoked_at = @at:timestamptz WHERE id = @id AND revoked_at IS NULL'),
      parameters: {'id': sessionId, 'at': at},
    );
  }

  @override
  Future<void> revokeAllSessions(String userId, DateTime at) async {
    await _pool.execute(
      Sql.named(
        'UPDATE refresh_sessions SET revoked_at = @at:timestamptz WHERE user_id = @user AND revoked_at IS NULL',
      ),
      parameters: {'user': userId, 'at': at},
    );
  }

  @override
  Future<List<AuthSession>> listSessions(String userId) async {
    final result = await _pool.execute(
      Sql.named('SELECT * FROM refresh_sessions WHERE user_id = @user AND revoked_at IS NULL ORDER BY created_at'),
      parameters: {'user': userId},
    );
    return [for (final row in result) _session(row.toColumnMap(), '')];
  }

  // ---- verification codes ----

  @override
  Future<void> saveVerificationCode(VerificationCode code) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO verification_codes (id, purpose, target, user_id, code_hash, attempts, expires_at,
          consumed_at, created_at)
        VALUES (@id, @purpose, @target, @user, @hash, @attempts, @expires:timestamptz, @consumed:timestamptz,
          @created:timestamptz)
        ON CONFLICT (purpose, target) DO UPDATE SET
          id = EXCLUDED.id, user_id = EXCLUDED.user_id, code_hash = EXCLUDED.code_hash,
          attempts = EXCLUDED.attempts, expires_at = EXCLUDED.expires_at,
          consumed_at = EXCLUDED.consumed_at, created_at = EXCLUDED.created_at
      '''),
      parameters: {
        'id': code.id,
        'purpose': code.purpose.wire,
        'target': code.target,
        'user': code.userId,
        'hash': code.codeHash,
        'attempts': code.attempts,
        'expires': code.expiresAt,
        'consumed': code.consumedAt,
        'created': code.createdAt,
      },
    );
  }

  @override
  Future<VerificationCode?> findVerificationCode(VerificationPurpose purpose, String target) async {
    final result = await _pool.execute(
      Sql.named('SELECT * FROM verification_codes WHERE purpose = @purpose AND target = @target'),
      parameters: {'purpose': purpose.wire, 'target': target},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return VerificationCode(
      id: row['id'] as String,
      purpose: VerificationPurpose.fromWire(row['purpose'] as String),
      target: row['target'] as String,
      userId: row['user_id'] as String?,
      codeHash: row['code_hash'] as String?,
      attempts: row['attempts'] as int,
      expiresAt: row['expires_at'] as DateTime,
      consumedAt: row['consumed_at'] as DateTime?,
      createdAt: row['created_at'] as DateTime,
    );
  }

  @override
  Future<int> incrementCodeAttempts(String codeId) async {
    final result = await _pool.execute(
      Sql.named('UPDATE verification_codes SET attempts = attempts + 1 WHERE id = @id RETURNING attempts'),
      parameters: {'id': codeId},
    );
    return result.isEmpty ? 0 : result.first[0] as int;
  }

  @override
  Future<void> consumeCode(String codeId, DateTime at) async {
    await _pool.execute(
      Sql.named('UPDATE verification_codes SET consumed_at = @at:timestamptz WHERE id = @id'),
      parameters: {'id': codeId, 'at': at},
    );
  }

  // ---- contacts ----

  @override
  Future<void> replaceContacts(String userId, List<ContactRecord> contacts) async {
    await _pool.runTx((tx) async {
      await tx.execute(Sql.named('DELETE FROM user_contacts WHERE user_id = @id'), parameters: {'id': userId});
      const chunk = 2000;
      for (var start = 0; start < contacts.length; start += chunk) {
        final slice = contacts.sublist(start, start + chunk > contacts.length ? contacts.length : start + chunk);
        await tx.execute(
          Sql.named('''
            INSERT INTO user_contacts (user_id, identifier_hash, kind, entry_index, display_name)
            SELECT @user:text, h, k, e, n
            FROM unnest(@hashes:_text, @kinds:_text, @entries:_int4, @names:_text) AS t(h, k, e, n)
            ON CONFLICT (user_id, identifier_hash) DO NOTHING
          '''),
          parameters: {
            'user': userId,
            'hashes': [for (final c in slice) c.identifierHash],
            'kinds': [for (final c in slice) c.kind.name],
            'entries': [for (final c in slice) c.entryIndex],
            'names': [for (final c in slice) c.name],
          },
        );
      }
    });
  }

  @override
  Future<List<ContactRecord>> contactsOf(String userId) async {
    final result = await _pool.execute(
      Sql.named('SELECT * FROM user_contacts WHERE user_id = @id ORDER BY entry_index, kind, identifier_hash'),
      parameters: {'id': userId},
    );
    return [
      for (final row in result.map((r) => r.toColumnMap()))
        ContactRecord(
          entryIndex: row['entry_index'] as int,
          name: row['display_name'] as String,
          kind: IdentifierKind.values.byName(row['kind'] as String),
          identifierHash: row['identifier_hash'] as String,
        ),
    ];
  }

  @override
  Future<List<IdentifierMatch>> findVerifiedUsersByHashes(
    Set<String> hashes, {
    required String excludeUserId,
  }) async {
    if (hashes.isEmpty) return const [];
    final result = await _pool.execute(
      Sql.named('''
        SELECT u.*, u.phone_hash AS matched_hash FROM users u
        WHERE u.phone_hash = ANY(@hashes:_text) AND u.phone_verified_at IS NOT NULL AND u.id <> @me
        UNION ALL
        SELECT u.*, u.email_hash AS matched_hash FROM users u
        WHERE u.email_hash = ANY(@hashes:_text) AND u.email_verified_at IS NOT NULL AND u.id <> @me
      '''),
      parameters: {'hashes': hashes.toList(), 'me': excludeUserId},
    );
    return [
      for (final row in result.map((r) => r.toColumnMap()))
        IdentifierMatch(identifierHash: row['matched_hash'] as String, user: _userFromMap(row)),
    ];
  }

  @override
  Future<Set<String>> usersHoldingAnyHash(Set<String> userIds, Set<String> hashes) async {
    if (userIds.isEmpty || hashes.isEmpty) return <String>{};
    final result = await _pool.execute(
      Sql.named('''
        SELECT DISTINCT user_id FROM user_contacts
        WHERE user_id = ANY(@users:_text) AND identifier_hash = ANY(@hashes:_text)
      '''),
      parameters: {'users': userIds.toList(), 'hashes': hashes.toList()},
    );
    return {for (final row in result) row[0] as String};
  }

  @override
  Future<Map<String, String>> preferencesOf(String userId) async {
    final result = await _pool.execute(
      Sql.named('SELECT target_user_id, preference FROM contact_preferences WHERE user_id = @id'),
      parameters: {'id': userId},
    );
    return {for (final row in result) row[0] as String: row[1] as String};
  }

  @override
  Future<void> setPreference(String userId, String targetUserId, String preference) async {
    await _pool.execute(
      Sql.named('''
        INSERT INTO contact_preferences (user_id, target_user_id, preference) VALUES (@user, @target, @pref)
        ON CONFLICT (user_id, target_user_id) DO UPDATE SET preference = EXCLUDED.preference, updated_at = now()
      '''),
      parameters: {'user': userId, 'target': targetUserId, 'pref': preference},
    );
  }

  // ---- maintenance ----

  @override
  Future<int> purgeExpired(DateTime now) async {
    var removed = 0;
    removed += (await _pool.execute(
      Sql.named('DELETE FROM session_tokens WHERE expires_at < @now:timestamptz'),
      parameters: {'now': now},
    ))
        .affectedRows;
    removed += (await _pool.execute(
      'DELETE FROM refresh_sessions s WHERE NOT EXISTS (SELECT 1 FROM session_tokens t WHERE t.session_id = s.id)',
    ))
        .affectedRows;
    removed += (await _pool.execute(
      Sql.named('DELETE FROM verification_codes WHERE expires_at < @now:timestamptz'),
      parameters: {'now': now},
    ))
        .affectedRows;
    return removed;
  }

  // ---- row mapping ----

  User _user(ResultRow row) => _userFromMap(row.toColumnMap());

  User _userFromMap(Map<String, dynamic> row) => User(
        id: row['id'] as String,
        email: row['email'] as String,
        emailHash: row['email_hash'] as String,
        emailVerifiedAt: row['email_verified_at'] as DateTime?,
        phone: row['phone_e164'] as String,
        phoneHash: row['phone_hash'] as String,
        phoneVerifiedAt: row['phone_verified_at'] as DateTime?,
        passwordHash: row['password_hash'] as String,
        name: row['name'] as String,
        homeCity: row['home_city'] as String,
        bio: row['bio'] as String,
        profileImageUrl: row['profile_image_url'] as String,
        currentLocation: row['current_location'] as String,
        locationShared: row['location_shared'] as bool,
        lastActiveAt: row['last_active_at'] as DateTime?,
        createdAt: row['created_at'] as DateTime,
      );

  SessionToken _token(Map<String, dynamic> row, String p) => SessionToken(
        id: row['${p}id'] as String,
        sessionId: row['${p}session_id'] as String,
        kind: TokenKind.values.byName(row['${p}kind'] as String),
        tokenHash: row['${p}token_hash'] as String,
        expiresAt: row['${p}expires_at'] as DateTime,
        rotatedAt: row['${p}rotated_at'] as DateTime?,
      );

  AuthSession _session(Map<String, dynamic> row, String p) => AuthSession(
        id: row['${p}id'] as String,
        userId: row['${p}user_id'] as String,
        deviceLabel: row['${p}device_label'] as String,
        createdAt: row['${p}created_at'] as DateTime,
        revokedAt: row['${p}revoked_at'] as DateTime?,
      );
}
