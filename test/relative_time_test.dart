import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/utils/relative_time.dart';

void main() {
  final now = DateTime.utc(2026, 6, 1, 12);

  group('formatRelativeTime', () {
    test('null is Unknown', () {
      expect(formatRelativeTime(null, now: now), 'Unknown');
    });

    test('formats each range', () {
      expect(formatRelativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5 minutes ago');
      expect(formatRelativeTime(now.subtract(const Duration(hours: 1)), now: now), '1 hour ago');
      expect(formatRelativeTime(now.subtract(const Duration(days: 1)), now: now), 'Yesterday');
      expect(formatRelativeTime(now.subtract(const Duration(days: 3)), now: now), '3 days ago');
      expect(formatRelativeTime(now.subtract(const Duration(days: 14)), now: now), '2 weeks ago');
      expect(formatRelativeTime(now.subtract(const Duration(days: 90)), now: now), '3 months ago');
      expect(formatRelativeTime(now.subtract(const Duration(days: 800)), now: now), '2 years ago');
    });

    test('a timestamp slightly in the future is Just now', () {
      expect(formatRelativeTime(now.add(const Duration(minutes: 2)), now: now), 'Just now');
    });
  });

  group('ContactObject parsing', () {
    test('lastSeenAt renders as a relative label', () {
      final contact = ReconnectContact.fromJson({
        'id': 'u1',
        'name': 'Jordan',
        'isOnApp': true,
        'mutual': true,
        'lastSeenAt': DateTime.now().toUtc().subtract(const Duration(days: 15)).toIso8601String(),
        'availableIn': ['Brooklyn'],
        'preference': 'loveToSee',
      });
      expect(contact.lastSeenAt, isNotNull);
      expect(contact.mutual, isTrue);
      expect(contact.lastSeenLabel, '2 weeks ago');
    });

    test('null lastSeenAt renders as Unknown and omits other users\' contact info', () {
      final contact = ReconnectContact.fromJson({
        'id': 'u2',
        'name': 'Maya',
        'isOnApp': true,
        'lastSeenAt': null,
        'availableIn': <String>[],
        'preference': 'neutral',
      });
      expect(contact.lastSeenLabel, 'Unknown');
      expect(contact.email, isEmpty);
      expect(contact.phone, isEmpty);
    });

    test('profile reads verification and location flags', () {
      final profile = ReconnectProfile.fromJson({
        'name': 'A',
        'email': 'a@example.com',
        'phone': '+14155550124',
        'homeCity': 'Austin',
        'bio': '',
        'emailVerified': true,
        'phoneVerified': true,
        'locationShared': true,
      });
      expect(profile.emailVerified, isTrue);
      expect(profile.phoneVerified, isTrue);
      expect(profile.locationShared, isTrue);
      expect(ReconnectProfile.fromJson(const {}).phoneVerified, isFalse);
    });

    test('notOnApp matches get a friendly status', () {
      final matches = ContactMatches.fromJson({
        'mutual': <dynamic>[],
        'oneWay': <dynamic>[],
        'notOnApp': [
          {'name': 'Pat', 'status': 'notOnApp'},
        ],
      });
      expect(matches.notOnApp.single.status, 'Not on app');
    });
  });
}
