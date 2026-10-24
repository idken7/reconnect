import '../models.dart';

/// Storage boundary. Implemented by [PostgresRepository] for production and
/// [MemoryRepository] for fast tests; both must pass the shared contract tests.
abstract interface class Repository {
  /// Prepares storage (runs migrations for Postgres).
  Future<void> init();

  /// True when the backing store is reachable (used by `/ready`).
  Future<bool> ping();

  Future<void> close();

  // ---- users ----

  /// Inserts [user]; throws [DuplicateUserException] if the email or phone is taken.
  Future<void> createUser(User user);

  Future<User?> findUserById(String id);
  Future<User?> findUserByEmail(String email);

  Future<User> updateUser(
    String id, {
    String? name,
    String? homeCity,
    String? bio,
    String? profileImageUrl,
    String? currentLocation,
    bool? locationShared,
  });

  Future<void> setPasswordHash(String userId, String passwordHash);
  Future<void> markVerified(String userId, IdentifierKind kind, DateTime at);
  Future<void> touchLastActive(String userId, DateTime at);

  /// Hard-deletes the user and everything that references them (sessions,
  /// tokens, codes, imported contacts, preferences set by or about them).
  Future<void> deleteUser(String userId);

  // ---- sessions and tokens ----

  Future<void> createSession(AuthSession session, List<SessionToken> tokens);
  Future<AccessLookup?> findAccessToken(String tokenHash);
  Future<RefreshLookup?> findRefreshToken(String tokenHash);

  /// Atomically marks a refresh token rotated. Returns false if it was already
  /// rotated (a lost race is treated as reuse by the caller).
  Future<bool> markRefreshRotated(String tokenId, DateTime at);

  Future<void> addTokens(List<SessionToken> tokens);
  Future<void> revokeSession(String sessionId, DateTime at);
  Future<void> revokeAllSessions(String userId, DateTime at);
  Future<List<AuthSession>> listSessions(String userId);

  // ---- verification codes ----

  /// Stores [code], replacing any earlier code for the same purpose and target.
  Future<void> saveVerificationCode(VerificationCode code);
  Future<VerificationCode?> findVerificationCode(VerificationPurpose purpose, String target);

  /// Increments and returns the failed-attempt counter.
  Future<int> incrementCodeAttempts(String codeId);
  Future<void> consumeCode(String codeId, DateTime at);

  // ---- contacts and preferences ----

  /// Replaces the user's whole imported address book.
  Future<void> replaceContacts(String userId, List<ContactRecord> contacts);
  Future<List<ContactRecord>> contactsOf(String userId);

  /// Other users whose *verified* phone or email hash is in [hashes].
  Future<List<IdentifierMatch>> findVerifiedUsersByHashes(Set<String> hashes, {required String excludeUserId});

  /// Which of [userIds] have imported at least one identifier in [hashes].
  Future<Set<String>> usersHoldingAnyHash(Set<String> userIds, Set<String> hashes);

  Future<Map<String, String>> preferencesOf(String userId);
  Future<void> setPreference(String userId, String targetUserId, String preference);

  // ---- maintenance ----

  /// Deletes expired tokens/sessions/codes; returns the number of rows removed.
  Future<int> purgeExpired(DateTime now);
}
