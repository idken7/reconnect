import 'dart:convert';

import 'auth/common_passwords.dart';
import 'errors.dart';

const int minPasswordLength = 8;
const int maxPasswordLength = 128;

final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
);

/// Lower-cases and validates an email address. Returns null when invalid.
String? normalizeEmail(String? input) {
  if (input == null) return null;
  final email = input.trim().toLowerCase();
  if (email.isEmpty || email.length > 254) return null;
  if (!_emailPattern.hasMatch(email)) return null;
  final at = email.lastIndexOf('@');
  if (at < 1 || at > 64) return null;
  if (email.contains('..') || email.startsWith('.') || email.substring(0, at).endsWith('.')) return null;
  return email;
}

/// Parses a phone number to E.164. Numbers without a `+` or `00` prefix are
/// interpreted in the North American Numbering Plan (default region US).
/// Returns null when the number is not plausible.
String? normalizePhone(String? input) {
  if (input == null) return null;
  final raw = input.trim();
  if (raw.isEmpty || raw.length > 40) return null;
  // Allow common formatting characters and an optional extension-free number.
  if (RegExp(r'[^0-9+\s().\-]').hasMatch(raw)) return null;
  final hasPlus = raw.startsWith('+');
  if (raw.indexOf('+', hasPlus ? 1 : 0) != -1) return null;
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (!hasPlus && digits.startsWith('00')) {
    digits = digits.substring(2);
    return _validateInternational(digits);
  }
  if (hasPlus) return _validateInternational(digits);

  if (digits.length == 11 && digits.startsWith('1')) digits = digits.substring(1);
  if (digits.length == 10) {
    final area = digits.codeUnitAt(0) - 48;
    final exchange = digits.codeUnitAt(3) - 48;
    if (area < 2 || exchange < 2) return null;
    return '+1$digits';
  }
  return null;
}

String? _validateInternational(String digits) {
  if (digits.length < 8 || digits.length > 15 || digits.startsWith('0')) return null;
  if (digits.startsWith('1') && digits.length != 11) return null; // NANP is always 11 digits with the 1.
  return '+$digits';
}

/// Throws a validation error when [password] is unacceptable.
void validatePassword(String password, {String? email, String? phone}) {
  if (password.length < minPasswordLength) {
    throw ApiException.validation('Password must be at least $minPasswordLength characters.');
  }
  if (password.length > maxPasswordLength) {
    throw ApiException.validation('Password must be at most $maxPasswordLength characters.');
  }
  final lowered = password.toLowerCase();
  if (isCommonPassword(lowered)) {
    throw ApiException.validation('That password is too common. Choose a less guessable one.');
  }
  if (RegExp(r'^(.)\1+$').hasMatch(password)) {
    throw ApiException.validation('Password cannot be a single repeated character.');
  }
  if (email != null) {
    final local = email.split('@').first.toLowerCase();
    if (lowered == email.toLowerCase() || (local.length >= 6 && lowered == local)) {
      throw ApiException.validation('Password cannot be the same as your email.');
    }
  }
  if (phone != null) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final passwordDigits = password.replaceAll(RegExp(r'[^0-9]'), '');
    if (passwordDigits.length >= 7 &&
        RegExp(r'^[0-9+\s().\-]+$').hasMatch(password) &&
        digits.endsWith(passwordDigits)) {
      throw ApiException.validation('Password cannot be your phone number.');
    }
  }
}

/// Strongly typed accessors over a decoded JSON object. Every violation is a
/// 400 `validation_error`, never an uncaught cast.
class JsonFields {
  JsonFields(this.map);

  final Map<String, Object?> map;

  bool has(String key) => map.containsKey(key) && map[key] != null;

  String? optString(String key, {int maxLength = 500, bool trim = true, bool allowEmpty = true}) {
    if (!has(key)) return null;
    final value = map[key];
    if (value is! String) throw ApiException.validation('"$key" must be a string.');
    final out = trim ? value.trim() : value;
    if (out.length > maxLength) throw ApiException.validation('"$key" must be at most $maxLength characters.');
    if (!allowEmpty && out.isEmpty) throw ApiException.validation('"$key" must not be empty.');
    return out;
  }

  String string(String key, {int maxLength = 500, bool trim = true}) {
    final value = optString(key, maxLength: maxLength, trim: trim, allowEmpty: false);
    if (value == null) throw ApiException.validation('"$key" is required.');
    return value;
  }

  bool? optBool(String key) {
    if (!has(key)) return null;
    final value = map[key];
    if (value is! bool) throw ApiException.validation('"$key" must be a boolean.');
    return value;
  }

  double? optDouble(String key) {
    if (!has(key)) return null;
    final value = map[key];
    if (value is! num || !value.toDouble().isFinite) throw ApiException.validation('"$key" must be a number.');
    return value.toDouble();
  }

  List<Object?>? optList(String key, {int maxItems = 1000}) {
    if (!has(key)) return null;
    final value = map[key];
    if (value is! List) throw ApiException.validation('"$key" must be an array.');
    if (value.length > maxItems) throw ApiException.validation('"$key" may contain at most $maxItems items.');
    return value;
  }
}

/// Decodes a request body into a JSON object. An empty body is `{}`.
Map<String, Object?> decodeJsonObject(List<int> bytes) {
  if (bytes.isEmpty) return <String, Object?>{};
  final Object? decoded;
  try {
    final text = utf8.decode(bytes);
    if (text.trim().isEmpty) return <String, Object?>{};
    decoded = jsonDecode(text);
  } on FormatException {
    throw ApiException.validation('Request body must be valid JSON.');
  }
  if (decoded is! Map) throw ApiException.validation('Request body must be a JSON object.');
  return Map<String, Object?>.from(decoded);
}

final RegExp _codePattern = RegExp(r'^\d{6}$');

String validateCode(String? code) {
  if (code == null || !_codePattern.hasMatch(code)) {
    throw ApiException.validation('"code" must be a 6 digit code.');
  }
  return code;
}

/// `https://` URL or empty string.
String validateProfileImageUrl(String value) {
  if (value.isEmpty) return '';
  if (value.length > 2048) throw ApiException.validation('"profileImageUrl" is too long.');
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw ApiException.validation('"profileImageUrl" must be an https:// URL or empty.');
  }
  return value;
}
