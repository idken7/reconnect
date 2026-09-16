import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/birthday_reminder_service.dart';

ReconnectContact _contact({required String name, DateTime? birthday}) {
  return ReconnectContact(
    id: name,
    name: name,
    email: '$name@example.com',
    phone: '555-0100',
    isOnApp: true,
    lastSeen: 'Last seen: recently',
    availableIn: const [],
    preference: ReconnectPreference.neutral,
    birthday: birthday,
  );
}

/// A birthday `daysFromNow` days out, expressed as a month/day (the service
/// only ever looks at month/day, reconstructing the year from "now").
DateTime _birthdayInDays(int daysFromNow) {
  final target = DateTime.now().add(Duration(days: daysFromNow));
  return DateTime(1990, target.month, target.day);
}

void main() {
  late BirthdayReminderService service;

  setUp(() {
    service = BirthdayReminderService();
  });

  group('getUpcomingBirthdays', () {
    test('includes a birthday within the window and excludes one outside it', () {
      final soon = _contact(name: 'Soon', birthday: _birthdayInDays(5));
      final far = _contact(name: 'Far', birthday: _birthdayInDays(60));
      final none = _contact(name: 'NoBirthday');

      final upcoming = service.getUpcomingBirthdays([soon, far, none], daysAhead: 30);

      expect(upcoming.map((c) => c.name), contains('Soon'));
      expect(upcoming.map((c) => c.name), isNot(contains('Far')));
      expect(upcoming.map((c) => c.name), isNot(contains('NoBirthday')));
    });

    test('sorts contacts by how soon their birthday is', () {
      final later = _contact(name: 'Later', birthday: _birthdayInDays(20));
      final sooner = _contact(name: 'Sooner', birthday: _birthdayInDays(2));

      final upcoming = service.getUpcomingBirthdays([later, sooner], daysAhead: 30);

      expect(upcoming.map((c) => c.name).toList(), ['Sooner', 'Later']);
    });
  });

  group('getBirthdaysToday / isBirthdayToday', () {
    test('recognizes a birthday that falls on today', () {
      final today = _contact(name: 'Today', birthday: _birthdayInDays(0));
      final notToday = _contact(name: 'NotToday', birthday: _birthdayInDays(3));

      expect(service.getBirthdaysToday([today, notToday]).map((c) => c.name), ['Today']);
      expect(service.isBirthdayToday(today), isTrue);
      expect(service.isBirthdayToday(notToday), isFalse);
    });

    test('a contact with no birthday is never "today"', () {
      expect(service.isBirthdayToday(_contact(name: 'NoBirthday')), isFalse);
    });
  });

  group('getDaysUntilBirthday', () {
    test('matches the requested offset exactly, regardless of time of day', () {
      expect(service.getDaysUntilBirthday(_birthdayInDays(10)), 10);
      expect(service.getDaysUntilBirthday(_birthdayInDays(1)), 1);
      expect(service.getDaysUntilBirthday(_birthdayInDays(0)), 0);
    });
  });

  group('getBirthdayString', () {
    test('formats as an abbreviated month and day', () {
      expect(service.getBirthdayString(DateTime(2024, 3, 15)), 'Mar 15');
      expect(service.getBirthdayString(DateTime(2024, 12, 1)), 'Dec 1');
    });
  });

  group('getAge', () {
    test('counts a full year once this year\'s birthday has passed', () {
      final birthday = DateTime.now().subtract(const Duration(days: 365 * 25 + 30));
      expect(service.getAge(birthday), 25);
    });

    test('does not count this year until the birthday arrives', () {
      final birthday = DateTime.now().add(const Duration(days: 30)).subtract(const Duration(days: 365 * 25));
      expect(service.getAge(birthday), 24);
    });
  });

  group('getBirthdayMessage', () {
    test('is empty when the contact has no birthday', () {
      expect(service.getBirthdayMessage(_contact(name: 'NoBirthday')), '');
    });

    test('calls out a birthday that is today', () {
      final contact = _contact(name: 'Today', birthday: _birthdayInDays(0));
      expect(service.getBirthdayMessage(contact), contains('Today'));
    });

    test('calls out a birthday that is tomorrow', () {
      final contact = _contact(name: 'Tomorrow', birthday: _birthdayInDays(1));
      expect(service.getBirthdayMessage(contact), contains('tomorrow'));
    });
  });
}
