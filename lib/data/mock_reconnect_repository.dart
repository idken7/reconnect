import '../models.dart';

class MockReconnectRepository {
  const MockReconnectRepository();

  ReconnectProfile get profile => const ReconnectProfile(
        name: 'Avery Stone',
        email: 'avery@example.com',
        phone: '+1 (415) 555-0124',
        homeCity: 'Brooklyn',
        bio: 'Trying to reconnect with the people who made earlier chapters worth remembering.',
      );

  List<String> get supportedLocations => const [
        'Brooklyn',
        'Manhattan',
        'Austin',
        'Chicago',
      ];

  /// A point in the past, used to seed [ReconnectContact.lastContacted] so
  /// the spin wheel's "haven't talked in X days" slider has a real spread of
  /// eligible contacts to filter instead of an all-null pool.
  static DateTime? _daysAgo(int? days) => days == null ? null : DateTime.now().subtract(Duration(days: days));

  /// A birthday landing [daysFromNow] days out (year is a placeholder — only
  /// month/day matter to [BirthdayReminderService]).
  static DateTime? _birthdayIn(int? daysFromNow) {
    if (daysFromNow == null) return null;
    final target = DateTime.now().add(Duration(days: daysFromNow));
    return DateTime(1990, target.month, target.day);
  }

  List<ReconnectContact> get importedContacts => [
        ReconnectContact(
          id: '1',
          name: 'Jordan Patel',
          email: 'jordan@example.com',
          phone: '+1 (212) 555-0180',
          isOnApp: true,
          lastSeen: '2 weeks ago',
          availableIn: const ['Brooklyn', 'Manhattan'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(12),
          birthday: _birthdayIn(5),
        ),
        ReconnectContact(
          id: '2',
          name: 'Maya Chen',
          email: 'maya@example.com',
          phone: '+1 (646) 555-0148',
          isOnApp: true,
          lastSeen: '3 years ago',
          availableIn: const ['Brooklyn', 'Chicago'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(null),
          birthday: _birthdayIn(18),
        ),
        ReconnectContact(
          id: '3',
          name: 'Sam Rivera',
          email: 'sam@example.com',
          phone: '+1 (512) 555-0199',
          isOnApp: true,
          lastSeen: '8 months ago',
          availableIn: const ['Austin'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(210),
        ),
        ReconnectContact(
          id: '4',
          name: 'Nina Brooks',
          email: 'nina@example.com',
          phone: '+1 (312) 555-0116',
          isOnApp: false,
          lastSeen: 'Unknown',
          availableIn: const ['Chicago'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(40),
        ),
        ReconnectContact(
          id: '5',
          name: 'Leo Morgan',
          email: 'leo@example.com',
          phone: '+1 (347) 555-0172',
          isOnApp: true,
          lastSeen: '1 month ago',
          availableIn: const ['Manhattan'],
          preference: ReconnectPreference.ratherAvoid,
          lastContacted: _daysAgo(400),
        ),
        // Additional test contacts for connection testing
        ReconnectContact(
          id: '6',
          name: 'Alex Thompson',
          email: 'alex@example.com',
          phone: '+1 (415) 555-0140',
          isOnApp: true,
          lastSeen: '2 months ago',
          availableIn: const ['Brooklyn', 'Manhattan', 'Austin'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(8),
        ),
        ReconnectContact(
          id: '7',
          name: 'Jordan Lee',
          email: 'jlee@example.com',
          phone: '+1 (206) 555-0134',
          isOnApp: true,
          lastSeen: '6 months ago',
          availableIn: const ['Austin'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(95),
          birthday: _birthdayIn(27),
        ),
        ReconnectContact(
          id: '8',
          name: 'Casey Williams',
          email: 'casey@example.com',
          phone: '+1 (510) 555-0123',
          isOnApp: true,
          lastSeen: '4 months ago',
          availableIn: const ['Manhattan', 'Chicago'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(30),
        ),
        ReconnectContact(
          id: '9',
          name: 'Taylor Martinez',
          email: 'taylor@example.com',
          phone: '+1 (612) 555-0167',
          isOnApp: true,
          lastSeen: '5 years ago',
          availableIn: const ['Brooklyn'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(150),
        ),
        ReconnectContact(
          id: '10',
          name: 'Morgan Davis',
          email: 'morgan@example.com',
          phone: '+1 (214) 555-0156',
          isOnApp: true,
          lastSeen: '3 weeks ago',
          availableIn: const ['Austin', 'Chicago'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(21),
        ),
        ReconnectContact(
          id: '11',
          name: 'Riley Anderson',
          email: 'riley@example.com',
          phone: '+1 (303) 555-0141',
          isOnApp: true,
          lastSeen: '1 year ago',
          availableIn: const ['Brooklyn', 'Austin'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(365),
          birthday: _birthdayIn(2),
        ),
        ReconnectContact(
          id: '12',
          name: 'Casey Johnson',
          email: 'cjohnson@example.com',
          phone: '+1 (415) 555-0150',
          isOnApp: true,
          lastSeen: '7 months ago',
          availableIn: const ['Manhattan'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(210),
        ),
        ReconnectContact(
          id: '13',
          name: 'Jamie White',
          email: 'jamie@example.com',
          phone: '+1 (202) 555-0143',
          isOnApp: false,
          lastSeen: 'Unknown',
          availableIn: const ['Chicago'],
          preference: ReconnectPreference.ratherAvoid,
          lastContacted: _daysAgo(null),
        ),
        ReconnectContact(
          id: '14',
          name: 'Alex Brown',
          email: 'abrown@example.com',
          phone: '+1 (713) 555-0157',
          isOnApp: true,
          lastSeen: '3 months ago',
          availableIn: const ['Austin', 'Manhattan'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(90),
        ),
        ReconnectContact(
          id: '15',
          name: 'Sam Taylor',
          email: 'staylor@example.com',
          phone: '+1 (408) 555-0164',
          isOnApp: true,
          lastSeen: '9 months ago',
          availableIn: const ['Brooklyn'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(270),
        ),
        ReconnectContact(
          id: '16',
          name: 'Morgan Garcia',
          email: 'mgarcia@example.com',
          phone: '+1 (503) 555-0145',
          isOnApp: true,
          lastSeen: '2 years ago',
          availableIn: const ['Chicago', 'Austin'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(730),
        ),
        ReconnectContact(
          id: '17',
          name: 'Jordan Robinson',
          email: 'jrobinson@example.com',
          phone: '+1 (541) 555-0168',
          isOnApp: true,
          lastSeen: '4 months ago',
          availableIn: const ['Brooklyn', 'Manhattan'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(120),
        ),
        ReconnectContact(
          id: '18',
          name: 'Taylor Harris',
          email: 'tharris@example.com',
          phone: '+1 (702) 555-0151',
          isOnApp: true,
          lastSeen: '6 years ago',
          availableIn: const ['Austin'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(2190),
        ),
        ReconnectContact(
          id: '19',
          name: 'Casey Martin',
          email: 'cmartin@example.com',
          phone: '+1 (559) 555-0144',
          isOnApp: true,
          lastSeen: '5 months ago',
          availableIn: const ['Manhattan', 'Chicago'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(150),
        ),
        ReconnectContact(
          id: '20',
          name: 'Riley Thompson',
          email: 'rthompson@example.com',
          phone: '+1 (949) 555-0162',
          isOnApp: true,
          lastSeen: '11 months ago',
          availableIn: const ['Brooklyn'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(330),
        ),
        ReconnectContact(
          id: '21',
          name: 'Morgan Clark',
          email: 'mclark@example.com',
          phone: '+1 (858) 555-0149',
          isOnApp: true,
          lastSeen: '7 months ago',
          availableIn: const ['Austin', 'Manhattan'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(210),
        ),
        ReconnectContact(
          id: '22',
          name: 'Alex Rodriguez',
          email: 'arodriguez@example.com',
          phone: '+1 (432) 555-0165',
          isOnApp: true,
          lastSeen: '3 years ago',
          availableIn: const ['Chicago'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(1095),
        ),
        ReconnectContact(
          id: '23',
          name: 'Jordan Lewis',
          email: 'jlewis@example.com',
          phone: '+1 (480) 555-0152',
          isOnApp: true,
          lastSeen: '2 years ago',
          availableIn: const ['Brooklyn', 'Austin'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(730),
        ),
        ReconnectContact(
          id: '24',
          name: 'Taylor Walker',
          email: 'twalker@example.com',
          phone: '+1 (623) 555-0166',
          isOnApp: false,
          lastSeen: 'Unknown',
          availableIn: const ['Manhattan'],
          preference: ReconnectPreference.ratherAvoid,
          lastContacted: _daysAgo(null),
        ),
        ReconnectContact(
          id: '25',
          name: 'Sam Hall',
          email: 'shall@example.com',
          phone: '+1 (916) 555-0147',
          isOnApp: true,
          lastSeen: '8 months ago',
          availableIn: const ['Brooklyn', 'Chicago'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(240),
        ),
        ReconnectContact(
          id: '26',
          name: 'Casey Allen',
          email: 'callen@example.com',
          phone: '+1 (702) 555-0159',
          isOnApp: true,
          lastSeen: '1 year ago',
          availableIn: const ['Austin'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(365),
        ),
        ReconnectContact(
          id: '27',
          name: 'Riley Young',
          email: 'ryoung@example.com',
          phone: '+1 (520) 555-0161',
          isOnApp: true,
          lastSeen: '4 years ago',
          availableIn: const ['Manhattan', 'Austin'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(1460),
        ),
        ReconnectContact(
          id: '28',
          name: 'Morgan Hill',
          email: 'mhill@example.com',
          phone: '+1 (225) 555-0146',
          isOnApp: true,
          lastSeen: '6 months ago',
          availableIn: const ['Brooklyn'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(180),
        ),
        ReconnectContact(
          id: '29',
          name: 'Alex Scott',
          email: 'ascott@example.com',
          phone: '+1 (601) 555-0163',
          isOnApp: true,
          lastSeen: '2 years ago',
          availableIn: const ['Chicago', 'Manhattan'],
          preference: ReconnectPreference.loveToSee,
          lastContacted: _daysAgo(730),
          birthday: _birthdayIn(0),
        ),
        ReconnectContact(
          id: '30',
          name: 'Jordan Green',
          email: 'jgreen@example.com',
          phone: '+1 (754) 555-0160',
          isOnApp: true,
          lastSeen: '5 months ago',
          availableIn: const ['Austin'],
          preference: ReconnectPreference.neutral,
          lastContacted: _daysAgo(150),
        ),
      ];

  List<NearbySuggestion> suggestionsFor({
    required String location,
    required List<ReconnectContact> contacts,
  }) {
    final suggestions = contacts
        .where((contact) =>
            contact.isOnApp &&
            contact.preference != ReconnectPreference.ratherAvoid &&
            contact.availableIn.contains(location))
        .map((contact) {
      final sharedLocations = contact.availableIn.length > 1 
          ? contact.availableIn.where((loc) => loc != location).toList()
          : <String>[];
      
      final reason = _generateReasonText(
        contact: contact,
        location: location,
        sharedLocations: sharedLocations,
      );

      return NearbySuggestion(
        contact: contact,
        reason: reason,
        distanceLabel: location == 'Brooklyn' ? '<3 miles away' : 'Nearby',
        sharedLocations: sharedLocations,
        timeSinceLastSeen: contact.lastSeen,
      );
    }).toList();

    suggestions.sort((left, right) {
      final preferenceCompare = left.contact.preference.sortWeight.compareTo(right.contact.preference.sortWeight);
      if (preferenceCompare != 0) {
        return preferenceCompare;
      }
      return left.contact.lastSeen.compareTo(right.contact.lastSeen);
    });

    return suggestions;
  }

  String _generateReasonText({
    required ReconnectContact contact,
    required String location,
    required List<String> sharedLocations,
  }) {
    if (contact.preference == ReconnectPreference.loveToSee) {
      if (contact.lastSeen == 'Unknown') {
        return '${contact.name} has been out of reach. Great time to reconnect in $location!';
      } else if (contact.lastSeen.contains('years ago')) {
        return 'It\'s been ${contact.lastSeen} since you caught up with ${contact.name}. They are nearby in $location today.';
      } else if (contact.lastSeen.contains('ago')) {
        return 'Last saw ${contact.name} ${contact.lastSeen}. Their $location plans overlap with yours.';
      } else {
        return '${contact.name} is one you want to see. Now in $location with you!';
      }
    } else {
      // Neutral preference - focus on shared locations and overlap
      if (sharedLocations.length > 1) {
        return '${contact.name} splits time between ${sharedLocations.join(', ')} and $location—familiar faces!';
      } else if (sharedLocations.isNotEmpty) {
        return '${contact.name} also hangs out in ${sharedLocations.first}. Now overlapping in $location!';
      } else if (contact.lastSeen.contains('ago')) {
        return 'Saw ${contact.name} ${contact.lastSeen}. A low-key $location catch-up could fit.';
      } else {
        return '${contact.name} is in your $location area. Worth a quick catch-up?';
      }
    }
  }

  ReconnectDashboardData seedState({
    required String location,
    required bool contactsImported,
    List<ReconnectContact>? contacts,
  }) {
    final seededContacts = contacts ?? importedContacts;
    return ReconnectDashboardData(
      profile: profile,
      supportedLocations: supportedLocations,
      currentLocation: location,
      contactsImported: contactsImported,
      contacts: seededContacts,
      suggestions: suggestionsFor(location: location, contacts: seededContacts),
    );
  }
}
