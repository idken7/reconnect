import 'dart:convert';

import 'package:reconnect_backend/logging.dart';
import 'package:reconnect_backend/util.dart';
import 'package:test/test.dart';

void main() {
  test('emits one JSON object per line with level, message and timestamp', () {
    final lines = <String>[];
    Logger(sink: lines.add).info('hello', {'requestId': 'abc', 'status': 200});
    final entry = jsonDecode(lines.single) as Map<String, dynamic>;
    expect(entry['level'], 'info');
    expect(entry['msg'], 'hello');
    expect(entry['requestId'], 'abc');
    expect(entry['status'], 200);
    expect(DateTime.parse(entry['ts'] as String).isUtc, isTrue);
  });

  test('redacts sensitive keys, nested and in lists', () {
    final lines = <String>[];
    Logger(sink: lines.add).info('x', {
      'password': 'hunter2',
      'accessToken': 'abc',
      'authorization': 'Bearer abc',
      'email': 'a@b.com',
      'phone': '+14155550100',
      'code': '123456',
      'nested': {'refreshToken': 'r', 'safe': 'ok'},
      'list': [
        {'newPassword': 'p'},
      ],
    });
    final out = lines.single;
    for (final secret in ['hunter2', 'abc', 'a@b.com', '+14155550100', '123456', '"r"', '"p"']) {
      expect(out, isNot(contains(secret)), reason: secret);
    }
    expect(out, contains('"safe":"ok"'));
    expect(out, contains('[REDACTED]'));
  });

  test('scrubs emails, phone numbers and bearer tokens out of free text', () {
    final lines = <String>[];
    Logger(sink: lines.add).error(
      'failed for jane@example.com',
      error: Exception('duplicate key (email)=(jane@example.com) phone +1 415 555 0100 Authorization: Bearer abc.def-ghi'),
    );
    final out = lines.single;
    expect(out, isNot(contains('jane@example.com')));
    expect(out, isNot(contains('415 555 0100')));
    expect(out, isNot(contains('abc.def-ghi')));
    expect(out, contains('[email]'));
    expect(out, contains('errorType'));
  });

  test('respects the minimum level and survives a failing sink', () {
    final lines = <String>[];
    Logger(level: LogLevel.warn, sink: lines.add)
      ..info('hidden')
      ..warn('shown');
    expect(lines, hasLength(1));
    Logger(sink: (_) => throw StateError('disk full')).info('does not throw');
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals('abc', 'abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
    expect(constantTimeEquals('abc', 'abcd'), isFalse);
    expect(constantTimeEquals('', ''), isTrue);
  });

  test('timeSince', () {
    final now = DateTime.utc(2026, 6, 1);
    expect(timeSince(null, now), 'Unknown');
    expect(timeSince(now.subtract(const Duration(seconds: 5)), now), 'Just now');
    expect(timeSince(now.subtract(const Duration(minutes: 5)), now), '5 minutes ago');
    expect(timeSince(now.subtract(const Duration(hours: 1)), now), '1 hour ago');
    expect(timeSince(now.subtract(const Duration(days: 3)), now), '3 days ago');
    expect(timeSince(now.subtract(const Duration(days: 15)), now), '2 weeks ago');
    expect(timeSince(now.subtract(const Duration(days: 90)), now), '3 months ago');
    expect(timeSince(now.subtract(const Duration(days: 800)), now), '2 years ago');
  });
}
