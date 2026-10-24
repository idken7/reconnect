import '../models.dart';
import 'repository.dart';

/// In-memory [Repository] for tests and throwaway local runs. Data is lost on
/// restart. Mirrors the constraints of the Postgres schema.
class MemoryRepository implements Repository {
  final Map<String, User> _users = {};
  final Map<String, AuthSession> _sessions = {};
  final Map<String, SessionToken> _tokens = {}; // by token id
  final Map<String, VerificationCode> _codes = {}; // by id
  final Map<String, List<ContactRecord>> _contacts = {}; // by user id
  final Map<String, Map<String, String>> _preferences = {}; // user -> target -> pref

  @override
  Future<void> init() async {}

  @override
  Future<bool> ping() async => true;

  @override
  Future<void> close() async {}

  @override
  Future<void> createUser(User user) async {
    final taken = _users.values.any((u) => u.email == user.email || u.phone == user.phone);
    if (taken) throw const DuplicateUserException();
    _users[user.id] = user;
  }

  @override
  Future<User?> findUserById(String id) async => _users[id];

  @override
  Future<User?> findUserByEmail(String email) async =>
      _users.values.where((u) => u.email == email).firstOrNull;

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
    final user = _users[id];
    if (user == null) throw StateError('user not found');
    final updated = user.copyWith(
      name: name,
      homeCity: homeCity,
      bio: bio,
      profileImageUrl: profileImageUrl,
      currentLocation: currentLocation,
      locationShared: locationShared,
    );
    _users[id] = updated;
    return updated;
  }

  @override
  Future<void> setPasswordHash(String userId, String passwordHash) async {
    final user = _users[userId];
    if (user != null) _users[userId] = user.copyWith(passwordHash: passwordHash);
  }

  @override
  Future<void> markVerified(String userId, IdentifierKind kind, DateTime at) async {
    final user = _users[userId];
    if (user == null) return;
    _users[userId] = kind == IdentifierKind.phone
        ? user.copyWith(phoneVerifiedAt: user.phoneVerifiedAt ?? at)
        : user.copyWith(emailVerifiedAt: user.emailVerifiedAt ?? at);
  }

  @override
  Future<void> touchLastActive(String userId, DateTime at) async {
    final user = _users[userId];
    if (user != null) _users[userId] = user.copyWith(lastActiveAt: at);
  }

  @override
  Future<void> deleteUser(String userId) async {
    _users.remove(userId);
    final sessionIds = _sessions.values.where((s) => s.userId == userId).map((s) => s.id).toSet();
    _sessions.removeWhere((_, s) => s.userId == userId);
    _tokens.removeWhere((_, t) => sessionIds.contains(t.sessionId));
    _codes.removeWhere((_, c) => c.userId == userId);
    _contacts.remove(userId);
    _preferences.remove(userId);
    for (final prefs in _preferences.values) {
      prefs.remove(userId);
    }
  }

  @override
  Future<void> createSession(AuthSession session, List<SessionToken> tokens) async {
    _sessions[session.id] = session;
    for (final token in tokens) {
      _tokens[token.id] = token;
    }
  }

  @override
  Future<AccessLookup?> findAccessToken(String tokenHash) async {
    final token = _tokens.values.where((t) => t.kind == TokenKind.access && t.tokenHash == tokenHash).firstOrNull;
    if (token == null) return null;
    final session = _sessions[token.sessionId];
    if (session == null || session.revokedAt != null) return null;
    final user = _users[session.userId];
    if (user == null) return null;
    return AccessLookup(token: token, session: session, user: user);
  }

  @override
  Future<RefreshLookup?> findRefreshToken(String tokenHash) async {
    final token = _tokens.values.where((t) => t.kind == TokenKind.refresh && t.tokenHash == tokenHash).firstOrNull;
    if (token == null) return null;
    final session = _sessions[token.sessionId];
    if (session == null) return null;
    return RefreshLookup(token: token, session: session);
  }

  @override
  Future<bool> markRefreshRotated(String tokenId, DateTime at) async {
    final token = _tokens[tokenId];
    if (token == null || token.rotatedAt != null) return false;
    _tokens[tokenId] = SessionToken(
      id: token.id,
      sessionId: token.sessionId,
      kind: token.kind,
      tokenHash: token.tokenHash,
      expiresAt: token.expiresAt,
      rotatedAt: at,
    );
    return true;
  }

  @override
  Future<void> addTokens(List<SessionToken> tokens) async {
    for (final token in tokens) {
      _tokens[token.id] = token;
    }
  }

  @override
  Future<void> revokeSession(String sessionId, DateTime at) async {
    final session = _sessions[sessionId];
    if (session == null || session.revokedAt != null) return;
    _sessions[sessionId] = AuthSession(
      id: session.id,
      userId: session.userId,
      deviceLabel: session.deviceLabel,
      createdAt: session.createdAt,
      revokedAt: at,
    );
  }

  @override
  Future<void> revokeAllSessions(String userId, DateTime at) async {
    for (final session in _sessions.values.where((s) => s.userId == userId).toList()) {
      await revokeSession(session.id, at);
    }
  }

  @override
  Future<List<AuthSession>> listSessions(String userId) async =>
      _sessions.values.where((s) => s.userId == userId && s.revokedAt == null).toList();

  @override
  Future<void> saveVerificationCode(VerificationCode code) async {
    _codes.removeWhere((_, c) => c.purpose == code.purpose && c.target == code.target);
    _codes[code.id] = code;
  }

  @override
  Future<VerificationCode?> findVerificationCode(VerificationPurpose purpose, String target) async =>
      _codes.values.where((c) => c.purpose == purpose && c.target == target).firstOrNull;

  @override
  Future<int> incrementCodeAttempts(String codeId) async {
    final code = _codes[codeId];
    if (code == null) return 0;
    final updated = VerificationCode(
      id: code.id,
      purpose: code.purpose,
      target: code.target,
      userId: code.userId,
      codeHash: code.codeHash,
      attempts: code.attempts + 1,
      expiresAt: code.expiresAt,
      consumedAt: code.consumedAt,
      createdAt: code.createdAt,
    );
    _codes[codeId] = updated;
    return updated.attempts;
  }

  @override
  Future<void> consumeCode(String codeId, DateTime at) async {
    final code = _codes[codeId];
    if (code == null) return;
    _codes[codeId] = VerificationCode(
      id: code.id,
      purpose: code.purpose,
      target: code.target,
      userId: code.userId,
      codeHash: code.codeHash,
      attempts: code.attempts,
      expiresAt: code.expiresAt,
      consumedAt: at,
      createdAt: code.createdAt,
    );
  }

  @override
  Future<void> replaceContacts(String userId, List<ContactRecord> contacts) async {
    final seen = <String>{};
    _contacts[userId] = [
      for (final contact in contacts)
        if (seen.add(contact.identifierHash)) contact,
    ];
  }

  @override
  Future<List<ContactRecord>> contactsOf(String userId) async =>
      List<ContactRecord>.of(_contacts[userId] ?? const <ContactRecord>[]);

  @override
  Future<List<IdentifierMatch>> findVerifiedUsersByHashes(
    Set<String> hashes, {
    required String excludeUserId,
  }) async {
    final matches = <IdentifierMatch>[];
    for (final user in _users.values) {
      if (user.id == excludeUserId) continue;
      if (user.phoneVerified && hashes.contains(user.phoneHash)) {
        matches.add(IdentifierMatch(identifierHash: user.phoneHash, user: user));
      }
      if (user.emailVerified && hashes.contains(user.emailHash)) {
        matches.add(IdentifierMatch(identifierHash: user.emailHash, user: user));
      }
    }
    return matches;
  }

  @override
  Future<Set<String>> usersHoldingAnyHash(Set<String> userIds, Set<String> hashes) async {
    return {
      for (final id in userIds)
        if ((_contacts[id] ?? const <ContactRecord>[]).any((c) => hashes.contains(c.identifierHash))) id,
    };
  }

  @override
  Future<Map<String, String>> preferencesOf(String userId) async =>
      Map<String, String>.of(_preferences[userId] ?? const <String, String>{});

  @override
  Future<void> setPreference(String userId, String targetUserId, String preference) async {
    (_preferences[userId] ??= {})[targetUserId] = preference;
  }

  @override
  Future<int> purgeExpired(DateTime now) async {
    var removed = 0;
    final before = _tokens.length;
    _tokens.removeWhere((_, t) => t.expiresAt.isBefore(now));
    removed += before - _tokens.length;
    final liveSessions = _tokens.values.map((t) => t.sessionId).toSet();
    final sessionsBefore = _sessions.length;
    _sessions.removeWhere((id, _) => !liveSessions.contains(id));
    removed += sessionsBefore - _sessions.length;
    final codesBefore = _codes.length;
    _codes.removeWhere((_, c) => c.expiresAt.isBefore(now));
    removed += codesBefore - _codes.length;
    return removed;
  }
}
