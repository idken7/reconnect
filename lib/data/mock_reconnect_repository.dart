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

  List<ReconnectContact> get importedContacts => const [
        ReconnectContact(
          id: '1',
          name: 'Jordan Patel',
          email: 'jordan@example.com',
          phone: '+1 (212) 555-0180',
          isOnApp: true,
          lastSeen: '2 weeks ago',
          availableIn: ['Brooklyn', 'Manhattan'],
          preference: ReconnectPreference.loveToSee,
        ),
        ReconnectContact(
          id: '2',
          name: 'Maya Chen',
          email: 'maya@example.com',
          phone: '+1 (646) 555-0148',
          isOnApp: true,
          lastSeen: '3 years ago',
          availableIn: ['Brooklyn', 'Chicago'],
          preference: ReconnectPreference.loveToSee,
        ),
        ReconnectContact(
          id: '3',
          name: 'Sam Rivera',
          email: 'sam@example.com',
          phone: '+1 (512) 555-0199',
          isOnApp: true,
          lastSeen: '8 months ago',
          availableIn: ['Austin'],
          preference: ReconnectPreference.neutral,
        ),
        ReconnectContact(
          id: '4',
          name: 'Nina Brooks',
          email: 'nina@example.com',
          phone: '+1 (312) 555-0116',
          isOnApp: false,
          lastSeen: 'Unknown',
          availableIn: ['Chicago'],
          preference: ReconnectPreference.neutral,
        ),
        ReconnectContact(
          id: '5',
          name: 'Leo Morgan',
          email: 'leo@example.com',
          phone: '+1 (347) 555-0172',
          isOnApp: true,
          lastSeen: '1 month ago',
          availableIn: ['Manhattan'],
          preference: ReconnectPreference.ratherAvoid,
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
      final reason = contact.preference == ReconnectPreference.loveToSee
          ? 'Both of you are active in $location and you flagged this person as a top reconnect.'
          : 'You and this contact overlap in $location right now.';

      return NearbySuggestion(
        contact: contact,
        reason: reason,
        distanceLabel: location == 'Brooklyn' ? 'Under 3 miles away' : 'Nearby',
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
