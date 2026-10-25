const List<String> supportedLocations = <String>['Brooklyn', 'Manhattan', 'Austin', 'Chicago', 'Other'];
const String otherLocation = 'Other';

const List<String> preferenceValues = <String>['loveToSee', 'like', 'neutral', 'dislike', 'ratherAvoid'];

class User {
  const User({
    required this.id,
    required this.email,
    required this.emailHash,
    this.emailVerifiedAt,
    required this.phone,
    required this.phoneHash,
    this.phoneVerifiedAt,
    required this.passwordHash,
    this.name = '',
    this.homeCity = '',
    this.bio = '',
    this.profileImageUrl = '',
    this.currentLocation = otherLocation,
    this.locationShared = false,
    this.lastActiveAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String emailHash;
  final DateTime? emailVerifiedAt;
  final String phone;
  final String phoneHash;
  final DateTime? phoneVerifiedAt;
  final String passwordHash;
  final String name;
  final String homeCity;
  final String bio;
  final String profileImageUrl;
  final String currentLocation;
  final bool locationShared;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  bool get emailVerified => emailVerifiedAt != null;
  bool get phoneVerified => phoneVerifiedAt != null;

  User copyWith({
    String? passwordHash,
    String? name,
    String? homeCity,
    String? bio,
    String? profileImageUrl,
    String? currentLocation,
    bool? locationShared,
    DateTime? lastActiveAt,
    DateTime? emailVerifiedAt,
    DateTime? phoneVerifiedAt,
  }) {
    return User(
      id: id,
      email: email,
      emailHash: emailHash,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phone: phone,
      phoneHash: phoneHash,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      homeCity: homeCity ?? this.homeCity,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currentLocation: currentLocation ?? this.currentLocation,
      locationShared: locationShared ?? this.locationShared,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt,
    );
  }
}

/// One login on one device. Holds the whole refresh-token "family".
class AuthSession {
  const AuthSession({
    required this.id,
    required this.userId,
    required this.deviceLabel,
    required this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String userId;
  final String deviceLabel;
  final DateTime createdAt;
  final DateTime? revokedAt;
}

enum TokenKind { access, refresh }

/// Only hashes are ever stored; the raw token exists solely in the response.
class SessionToken {
  const SessionToken({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.tokenHash,
    required this.expiresAt,
    this.rotatedAt,
  });

  final String id;
  final String sessionId;
  final TokenKind kind;
  final String tokenHash;
  final DateTime expiresAt;

  /// Set when a refresh token has been exchanged for a new one.
  final DateTime? rotatedAt;
}

class AccessLookup {
  const AccessLookup({required this.token, required this.session, required this.user});
  final SessionToken token;
  final AuthSession session;
  final User user;
}

class RefreshLookup {
  const RefreshLookup({required this.token, required this.session});
  final SessionToken token;
  final AuthSession session;
}

enum VerificationPurpose {
  phoneVerify('phone_verify'),
  emailVerify('email_verify'),
  passwordReset('password_reset');

  const VerificationPurpose(this.wire);
  final String wire;

  static VerificationPurpose fromWire(String value) => values.firstWhere((p) => p.wire == value);
}

class VerificationCode {
  const VerificationCode({
    required this.id,
    required this.purpose,
    required this.target,
    this.userId,
    this.codeHash,
    this.attempts = 0,
    required this.expiresAt,
    this.consumedAt,
    required this.createdAt,
  });

  final String id;
  final VerificationPurpose purpose;
  final String target;
  final String? userId;

  /// Null when the provider (Twilio Verify) holds the code itself.
  final String? codeHash;
  final int attempts;
  final DateTime expiresAt;
  final DateTime? consumedAt;
  final DateTime createdAt;
}

enum IdentifierKind { phone, email }

/// One imported address-book identifier: only its HMAC and the display name.
class ContactRecord {
  const ContactRecord({
    required this.entryIndex,
    required this.name,
    required this.kind,
    required this.identifierHash,
  });

  /// Position of the address-book entry (groups an entry's phones and emails).
  final int entryIndex;
  final String name;
  final IdentifierKind kind;
  final String identifierHash;
}

/// A user whose verified identifier equals an imported identifier hash.
class IdentifierMatch {
  const IdentifierMatch({required this.identifierHash, required this.user});
  final String identifierHash;
  final User user;
}

class DuplicateUserException implements Exception {
  const DuplicateUserException();
}
