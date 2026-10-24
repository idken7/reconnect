import 'package:reconnect_backend/errors.dart';
import 'package:reconnect_backend/validation.dart';
import 'package:test/test.dart';

void main() {
  group('normalizePhone', () {
    test('formats US numbers as E.164 (default region US)', () {
      const expected = '+14155550124';
      for (final input in [
        '415-555-0124',
        '(415) 555-0124',
        '415.555.0124',
        '4155550124',
        '1 415 555 0124',
        '1-415-555-0124',
        '+1 (415) 555-0124',
        '  +14155550124  ',
        '0014155550124',
      ]) {
        expect(normalizePhone(input), expected, reason: input);
      }
    });

    test('makes the same number match regardless of punctuation', () {
      expect(normalizePhone('555-1234'), isNull, reason: 'no area code: cannot be matched reliably');
      expect(normalizePhone('+1 555-1234'), isNull);
    });

    test('accepts international numbers with +', () {
      expect(normalizePhone('+44 20 7946 0958'), '+442079460958');
      expect(normalizePhone('+49 30 901820'), '+4930901820');
      expect(normalizePhone('0044 20 7946 0958'), '+442079460958');
    });

    test('rejects implausible input', () {
      for (final input in [
        '',
        '   ',
        'abc',
        '12345',
        '911',
        '+',
        '+0123456789',
        '+1234',
        '+123456789012345678',
        '+1 415 555 012', // NANP with +1 must be 11 digits
        '015551234567',
        '115-555-0124', // area code cannot start with 1
        '415-155-0124', // exchange cannot start with 1
        '415-555-0124 ext 5',
        '4155550124;4155550125',
        '+1+4155550124',
        '1' * 41,
      ]) {
        expect(normalizePhone(input), isNull, reason: input);
      }
      expect(normalizePhone(null), isNull);
    });
  });

  group('normalizeEmail', () {
    test('trims and lower-cases', () {
      expect(normalizeEmail('  Jane.Doe+tag@Example.COM '), 'jane.doe+tag@example.com');
    });

    test('rejects invalid addresses', () {
      for (final input in [
        '',
        'plain',
        'a@b',
        '@example.com',
        'a@@example.com',
        'a b@example.com',
        'a@exa mple.com',
        'a@-example.com',
        '.a@example.com',
        'a.@example.com',
        'a..b@example.com',
        'a@example..com',
        '${'x' * 65}@example.com',
        '${'x' * 250}@example.com',
      ]) {
        expect(normalizeEmail(input), isNull, reason: input);
      }
      expect(normalizeEmail(null), isNull);
    });
  });

  group('validatePassword', () {
    void rejects(String password, {String? email, String? phone}) {
      expect(
        () => validatePassword(password, email: email, phone: phone),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'validation_error')),
        reason: password,
      );
    }

    test('requires at least 8 characters and at most 128', () {
      rejects('short1!');
      rejects('x' * 129);
      validatePassword('x7#kLm9q');
      validatePassword('y' * 127 + 'z');
    });

    test('rejects common passwords, case-insensitively and with simple decoration', () {
      for (final password in [
        'password',
        'Password',
        'PASSWORD123',
        'password1!',
        'Qwerty123',
        'iloveyou',
        '12345678',
        'letmein99',
        'Welcome1',
        'Sunshine2024',
      ]) {
        rejects(password);
      }
    });

    test('rejects a single repeated character and credential look-alikes', () {
      rejects('aaaaaaaa');
      rejects('jane.doe@example.com', email: 'jane.doe@example.com');
      rejects('janedoe99', email: 'janedoe99@example.com');
      rejects('+14155550124', phone: '+14155550124');
      rejects('(415) 555-0124', phone: '+14155550124');
    });

    test('accepts long passphrases', () {
      validatePassword('correct horse battery staple');
    });
  });

  group('decodeJsonObject', () {
    test('empty body is an empty object', () {
      expect(decodeJsonObject([]), isEmpty);
      expect(decodeJsonObject(' \n'.codeUnits), isEmpty);
    });

    test('rejects malformed JSON, arrays and invalid UTF-8', () {
      for (final bytes in [
        '{'.codeUnits,
        '[]'.codeUnits,
        'null'.codeUnits,
        '1'.codeUnits,
        [0xff, 0xfe],
      ]) {
        expect(() => decodeJsonObject(bytes), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
      }
    });
  });

  group('JsonFields', () {
    test('typed accessors turn type errors into validation errors', () {
      final fields = JsonFields({'s': 1, 'b': 'x', 'n': 'y', 'l': 'z'});
      expect(() => fields.optString('s'), throwsA(isA<ApiException>()));
      expect(() => fields.optBool('b'), throwsA(isA<ApiException>()));
      expect(() => fields.optDouble('n'), throwsA(isA<ApiException>()));
      expect(() => fields.optList('l'), throwsA(isA<ApiException>()));
      expect(() => fields.string('missing'), throwsA(isA<ApiException>()));
      expect(fields.optString('missing'), isNull);
      expect(JsonFields({'a': ' hi '}).string('a'), 'hi');
      expect(JsonFields({'a': ' hi '}).string('a', trim: false), ' hi ');
      expect(() => JsonFields({'a': 'toolong'}).string('a', maxLength: 3), throwsA(isA<ApiException>()));
    });
  });

  test('validateProfileImageUrl accepts https or empty only', () {
    expect(validateProfileImageUrl(''), '');
    expect(validateProfileImageUrl('https://cdn.example.com/a.png'), 'https://cdn.example.com/a.png');
    for (final bad in ['http://a.com/x.png', 'ftp://a.com', 'data:image/png;base64,AA', 'https://', '//a.com/x']) {
      expect(() => validateProfileImageUrl(bad), throwsA(isA<ApiException>()), reason: bad);
    }
  });
}
