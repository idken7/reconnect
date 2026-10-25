import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 of a high-entropy random token. Fast hashing is fine here because the
/// inputs are 256 bits of randomness; this is what is stored at rest.
String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

/// Keyed hashing with the server pepper, used for contact identifiers and
/// verification codes so a database leak alone cannot be reversed or brute
/// forced.
class Hmacs {
  Hmacs(String pepper) : _key = utf8.encode(pepper);

  final List<int> _key;

  String _mac(String value) => Hmac(sha256, _key).convert(utf8.encode(value)).toString();

  /// HMAC of a normalized phone number in E.164 form.
  String phone(String e164) => _mac('phone:$e164');

  /// HMAC of a normalized (trimmed, lower-case) email address.
  String email(String normalized) => _mac('email:$normalized');

  String code(String purpose, String target, String code) => _mac('code:$purpose:$target:$code');
}
