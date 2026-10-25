import '../auth/password_hasher.dart';
import '../auth/tokens.dart';
import '../config.dart';
import '../db/repository.dart';
import '../errors.dart';
import '../logging.dart';
import '../models.dart';
import '../util.dart';
import '../validation.dart';
import 'rate_limiter.dart';
import 'verification_provider.dart';
import 'verification_service.dart';

class IssuedTokens {
  const IssuedTokens({required this.accessToken, required this.refreshToken, required this.accessExpiresAt});
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
}

class AuthResult {
  const AuthResult(this.user, this.tokens);
  final User user;
  final IssuedTokens tokens;
}

/// Who is calling: the user plus the session of the presented access token.
class AuthContext {
  const AuthContext({required this.user, required this.sessionId});
  final User user;
  final String sessionId;
}

class AuthService {
  AuthService({
    required this.repository,
    required this.hasher,
    required this.hmacs,
    required this.verification,
    required this.limiter,
    required this.config,
    required this.tasks,
    required this.logger,
    Clock clock = systemClock,
  }) : _clock = clock;

  final Repository repository;
  final PasswordHasher hasher;
  final Hmacs hmacs;
  final VerificationService verification;
  final RateLimiter limiter;
  final AppConfig config;
  final BackgroundTasks tasks;
  final Logger logger;
  final Clock _clock;

  /// Hash verified for unknown accounts so they cost the same as a wrong password.
  Future<String>? _dummyHash;

  static const Duration _failureWindow = Duration(hours: 1);
  static const Duration _lastActiveGranularity = Duration(minutes: 5);

  // ---- signup / login ----

  Future<AuthResult> signUp({
    required String email,
    required String phone,
    required String password,
    String name = '',
    String homeCity = '',
    String bio = '',
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (normalizedEmail == null) throw ApiException.validation('Enter a valid email address.');
    final normalizedPhone = normalizePhone(phone);
    if (normalizedPhone == null) throw ApiException.validation('Enter a valid phone number.');
    validatePassword(password, email: normalizedEmail, phone: normalizedPhone);

    final now = _clock();
    final user = User(
      id: newId('u'),
      email: normalizedEmail,
      emailHash: hmacs.email(normalizedEmail),
      phone: normalizedPhone,
      phoneHash: hmacs.phone(normalizedPhone),
      passwordHash: await hasher.hash(password),
      name: name,
      homeCity: homeCity,
      bio: bio,
      currentLocation: supportedLocations.contains(homeCity) ? homeCity : otherLocation,
      lastActiveAt: now,
      createdAt: now,
    );
    try {
      await repository.createUser(user);
    } on DuplicateUserException {
      throw ApiException.accountExists();
    }

    final tokens = await _startSession(user.id, '');
    _sendInBackground(VerificationPurpose.phoneVerify, user.phone, user.id);
    return AuthResult(user, tokens);
  }

  Future<AuthResult> login({required String email, required String password, String deviceLabel = ''}) async {
    final normalized = normalizeEmail(email);
    final accountKey = normalized ?? email.trim().toLowerCase();

    final locked = limiter.lockoutRemaining(accountKey);
    if (locked != null) throw ApiException.rateLimited(locked.inSeconds + 1);
    final capped = limiter.peek(
      'login-fail',
      accountKey,
      limit: limiter.config.loginFailuresPerAccountPerHour,
      window: _failureWindow,
    );
    if (capped != null) throw ApiException.rateLimited(capped.inSeconds + 1);

    final user = normalized == null ? null : await repository.findUserByEmail(normalized);
    var valid = false;
    if (password.length <= maxPasswordLength) {
      if (user == null) {
        // Burn the same CPU as a real verification so timing does not reveal the account.
        await hasher.verify(password, await (_dummyHash ??= hasher.hash('timing-equalizer-password')));
      } else {
        valid = await hasher.verify(password, user.passwordHash);
      }
    }
    if (!valid || user == null) {
      limiter.recordLoginFailure(accountKey);
      limiter.record('login-fail', accountKey, _failureWindow);
      throw ApiException.invalidCredentials();
    }

    limiter.recordLoginSuccess(accountKey);
    limiter.reset('login-fail', accountKey);

    var current = user;
    if (hasher.needsRehash(user.passwordHash)) {
      final upgraded = await hasher.hash(password);
      await repository.setPasswordHash(user.id, upgraded);
      current = user.copyWith(passwordHash: upgraded);
    }
    final tokens = await _startSession(user.id, deviceLabel);
    return AuthResult(current, tokens);
  }

  // ---- tokens ----

  Future<IssuedTokens> refresh(String refreshToken) async {
    final lookup = await repository.findRefreshToken(hashToken(refreshToken));
    if (lookup == null) throw ApiException.invalidRefreshToken();
    final now = _clock();

    if (lookup.token.rotatedAt != null) {
      await _handleReuse(lookup.session);
      throw ApiException.refreshTokenReused();
    }
    if (lookup.session.revokedAt != null) throw ApiException.invalidRefreshToken();
    if (!lookup.token.expiresAt.isAfter(now)) throw ApiException.refreshTokenExpired();

    final won = await repository.markRefreshRotated(lookup.token.id, now);
    if (!won) {
      await _handleReuse(lookup.session);
      throw ApiException.refreshTokenReused();
    }
    return _issueTokens(lookup.session.id);
  }

  Future<void> _handleReuse(AuthSession session) async {
    await repository.revokeSession(session.id, _clock());
    logger.warn('refresh token reuse detected; session revoked', {'userId': session.userId, 'sessionId': session.id});
  }

  Future<AuthContext> authenticate(String accessToken) async {
    final lookup = await repository.findAccessToken(hashToken(accessToken));
    if (lookup == null) throw ApiException.invalidAccessToken();
    final now = _clock();
    if (!lookup.token.expiresAt.isAfter(now)) throw ApiException.tokenExpired();

    var user = lookup.user;
    final lastActive = user.lastActiveAt;
    if (lastActive == null || now.difference(lastActive) > _lastActiveGranularity) {
      await repository.touchLastActive(user.id, now);
      user = user.copyWith(lastActiveAt: now);
    }
    return AuthContext(user: user, sessionId: lookup.session.id);
  }

  Future<void> logout(AuthContext context) => repository.revokeSession(context.sessionId, _clock());

  Future<void> logoutAll(AuthContext context) => repository.revokeAllSessions(context.user.id, _clock());

  Future<IssuedTokens> _startSession(String userId, String deviceLabel) async {
    final now = _clock();
    final session = AuthSession(id: newId('s'), userId: userId, deviceLabel: deviceLabel, createdAt: now);
    final built = _buildTokens(session.id, now);
    await repository.createSession(session, built.rows);
    return built.issued;
  }

  Future<IssuedTokens> _issueTokens(String sessionId) async {
    final built = _buildTokens(sessionId, _clock());
    await repository.addTokens(built.rows);
    return built.issued;
  }

  ({IssuedTokens issued, List<SessionToken> rows}) _buildTokens(String sessionId, DateTime now) {
    final access = randomToken();
    final refresh = randomToken();
    final accessExpires = now.add(config.accessTokenTtl);
    return (
      issued: IssuedTokens(accessToken: access, refreshToken: refresh, accessExpiresAt: accessExpires),
      rows: [
        SessionToken(
          id: newId('t'),
          sessionId: sessionId,
          kind: TokenKind.access,
          tokenHash: hashToken(access),
          expiresAt: accessExpires,
        ),
        SessionToken(
          id: newId('t'),
          sessionId: sessionId,
          kind: TokenKind.refresh,
          tokenHash: hashToken(refresh),
          expiresAt: now.add(config.refreshTokenTtl),
        ),
      ],
    );
  }

  // ---- verification ----

  /// Sends a code to the user's phone or email. A no-op if already verified.
  Future<void> sendVerification(User user, IdentifierKind kind) async {
    if (kind == IdentifierKind.phone ? user.phoneVerified : user.emailVerified) return;
    final purpose = kind == IdentifierKind.phone ? VerificationPurpose.phoneVerify : VerificationPurpose.emailVerify;
    try {
      await verification.send(purpose, kind == IdentifierKind.phone ? user.phone : user.email, userId: user.id);
    } on VerificationDeliveryException catch (e) {
      logger.error('verification delivery failed', error: e);
      throw ApiException.deliveryUnavailable();
    }
  }

  Future<User> confirmVerification(User user, IdentifierKind kind, String code) async {
    final purpose = kind == IdentifierKind.phone ? VerificationPurpose.phoneVerify : VerificationPurpose.emailVerify;
    final target = kind == IdentifierKind.phone ? user.phone : user.email;
    final alreadyVerified = kind == IdentifierKind.phone ? user.phoneVerified : user.emailVerified;
    if (alreadyVerified) return user;

    final bool ok;
    try {
      ok = await verification.check(purpose, target, code);
    } on VerificationDeliveryException catch (e) {
      logger.error('verification check failed', error: e);
      throw ApiException.deliveryUnavailable();
    }
    if (!ok) throw ApiException.validation('That code is invalid or has expired.');
    await repository.markVerified(user.id, kind, _clock());
    return (await repository.findUserById(user.id)) ?? user;
  }

  // ---- password reset ----

  /// Always completes the same way whether or not [email] has an account.
  Future<void> requestPasswordReset(String email) async {
    final normalized = normalizeEmail(email);
    if (normalized == null) throw ApiException.validation('Enter a valid email address.');
    final user = await repository.findUserByEmail(normalized);
    if (user == null) return;
    // Delivery happens off the request path so response time does not reveal the account.
    _sendInBackground(VerificationPurpose.passwordReset, user.email, user.id);
  }

  Future<void> confirmPasswordReset({required String email, required String code, required String newPassword}) async {
    final normalized = normalizeEmail(email);
    if (normalized == null) throw ApiException.validation('Enter a valid email address.');
    validatePassword(newPassword, email: normalized);

    final bool ok;
    try {
      ok = await verification.check(VerificationPurpose.passwordReset, normalized, code);
    } on VerificationDeliveryException catch (e) {
      logger.error('verification check failed', error: e);
      throw ApiException.deliveryUnavailable();
    }
    final user = ok ? await repository.findUserByEmail(normalized) : null;
    if (user == null) throw ApiException.validation('That code is invalid or has expired.');

    await repository.setPasswordHash(user.id, await hasher.hash(newPassword));
    // Receiving the emailed code proves control of the address.
    await repository.markVerified(user.id, IdentifierKind.email, _clock());
    await repository.revokeAllSessions(user.id, _clock());
    limiter.recordLoginSuccess(normalized);
    limiter.reset('login-fail', normalized);
  }

  // ---- account deletion ----

  Future<void> deleteAccount(User user, String password) async {
    final locked = limiter.lockoutRemaining(user.email);
    if (locked != null) throw ApiException.rateLimited(locked.inSeconds + 1);
    final valid = password.length <= maxPasswordLength && await hasher.verify(password, user.passwordHash);
    if (!valid) {
      limiter.recordLoginFailure(user.email);
      throw ApiException.invalidCredentials();
    }
    await repository.deleteUser(user.id);
  }

  void _sendInBackground(VerificationPurpose purpose, String target, String userId) {
    tasks.run(
      () => verification.send(purpose, target, userId: userId),
      onError: (error, stack) => logger.error('verification delivery failed', error: error),
    );
  }
}
