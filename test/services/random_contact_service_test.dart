import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/random_contact_service.dart';

ReconnectContact _contact({
  required String id,
  DateTime? lastContacted,
  ReconnectPreference preference = ReconnectPreference.neutral,
}) {
  return ReconnectContact(
    id: id,
    name: 'Contact $id',
    email: '$id@example.com',
    phone: '555-0100',
    isOnApp: true,
    lastSeen: 'Last seen: recently',
    availableIn: const [],
    preference: preference,
    lastContacted: lastContacted,
  );
}

void main() {
  late RandomContactService service;

  setUp(() {
    service = RandomContactService();
  });

  group('getEligibleContacts', () {
    test('includes contacts never contacted regardless of threshold', () {
      final contact = _contact(id: 'never');
      expect(service.getEligibleContacts([contact], daysThreshold: 1), [contact]);
    });

    test('excludes contacts contacted more recently than the threshold', () {
      final recent = _contact(id: 'recent', lastContacted: DateTime.now().subtract(const Duration(days: 5)));
      expect(service.getEligibleContacts([recent], daysThreshold: 90), isEmpty);
    });

    test('includes contacts contacted before the threshold', () {
      final old = _contact(id: 'old', lastContacted: DateTime.now().subtract(const Duration(days: 100)));
      expect(service.getEligibleContacts([old], daysThreshold: 90), [old]);
    });

    test('narrows results by preference filter', () {
      final loveToSee = _contact(id: 'love', preference: ReconnectPreference.loveToSee);
      final neutral = _contact(id: 'neutral', preference: ReconnectPreference.neutral);

      final eligible = service.getEligibleContacts(
        [loveToSee, neutral],
        preferenceFilter: ReconnectPreference.loveToSee,
      );

      expect(eligible, [loveToSee]);
    });
  });

  group('getRandomContact', () {
    test('returns null for an empty contact list', () {
      expect(service.getRandomContact(const []), isNull);
    });

    test('returns null when no contact meets the threshold', () {
      final recent = _contact(id: 'recent', lastContacted: DateTime.now());
      expect(service.getRandomContact([recent], daysThreshold: 90), isNull);
    });

    test('returns a contact drawn from the eligible pool', () {
      final eligible = _contact(id: 'eligible');
      final result = service.getRandomContact([eligible]);
      expect(result, eligible);
    });
  });

  group('getContactsByLastContacted', () {
    test('sorts oldest (and never-contacted) first', () {
      final recent = _contact(id: 'recent', lastContacted: DateTime.now().subtract(const Duration(days: 1)));
      final old = _contact(id: 'old', lastContacted: DateTime.now().subtract(const Duration(days: 200)));
      final never = _contact(id: 'never');

      final sorted = service.getContactsByLastContacted([recent, old, never]);

      expect(sorted.map((c) => c.id).toList(), ['never', 'old', 'recent']);
    });

    test('does not mutate the input list', () {
      final recent = _contact(id: 'recent', lastContacted: DateTime.now().subtract(const Duration(days: 1)));
      final old = _contact(id: 'old', lastContacted: DateTime.now().subtract(const Duration(days: 200)));
      final input = [recent, old];

      service.getContactsByLastContacted(input);

      expect(input, [recent, old]);
    });
  });

  group('getTimeSinceLastContact', () {
    test('reports never-contacted contacts explicitly', () {
      expect(service.getTimeSinceLastContact(_contact(id: 'never')), 'Never contacted');
    });

    test('reports today, yesterday, and multi-day offsets', () {
      expect(
        service.getTimeSinceLastContact(_contact(id: 'a', lastContacted: DateTime.now())),
        'Today',
      );
      expect(
        service.getTimeSinceLastContact(
          _contact(id: 'b', lastContacted: DateTime.now().subtract(const Duration(days: 1))),
        ),
        'Yesterday',
      );
      expect(
        service.getTimeSinceLastContact(
          _contact(id: 'c', lastContacted: DateTime.now().subtract(const Duration(days: 3))),
        ),
        '3 days ago',
      );
    });

    test('reports weeks, months, and years for longer offsets', () {
      expect(
        service.getTimeSinceLastContact(
          _contact(id: 'd', lastContacted: DateTime.now().subtract(const Duration(days: 14))),
        ),
        '2 weeks ago',
      );
      expect(
        service.getTimeSinceLastContact(
          _contact(id: 'e', lastContacted: DateTime.now().subtract(const Duration(days: 60))),
        ),
        '2 months ago',
      );
      expect(
        service.getTimeSinceLastContact(
          _contact(id: 'f', lastContacted: DateTime.now().subtract(const Duration(days: 400))),
        ),
        '1 year ago',
      );
    });
  });
}
