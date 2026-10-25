import '../db/repository.dart';
import '../errors.dart';
import '../models.dart';
import '../util.dart';
import 'location.dart';
import 'matching_service.dart';

Map<String, Object?> profileJson(User user) => {
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'homeCity': user.homeCity,
      'bio': user.bio,
      'profileImageUrl': user.profileImageUrl,
      'emailVerified': user.emailVerified,
      'phoneVerified': user.phoneVerified,
      'locationShared': user.locationShared,
    };

/// Builds the dashboard and applies profile/location changes.
class DashboardService {
  DashboardService({required this.repository, required this.matching, Clock clock = systemClock})
      : _clock = clock;

  final Repository repository;
  final MatchingService matching;
  final Clock _clock;

  /// `{mutual, oneWay, notOnApp}` as returned by `GET /contacts/matches`.
  Future<Map<String, Object?>> matches(User viewer) async {
    final result = await matching.compute(viewer);
    final prefs = await repository.preferencesOf(viewer.id);
    return {
      'mutual': [for (final m in result.mutual) _contactJson(m, prefs)],
      'oneWay': [for (final m in result.oneWay) _contactJson(m, prefs)],
      'notOnApp': [
        for (final name in result.notOnApp) {'name': name, 'status': 'notOnApp'},
      ],
    };
  }

  Future<Map<String, Object?>> dashboard(User viewer, {String? setLocation}) async {
    var user = viewer;
    if (setLocation != null && setLocation != viewer.currentLocation) {
      user = await repository.updateUser(viewer.id, currentLocation: setLocation);
    } else {
      user = await repository.findUserById(viewer.id) ?? viewer;
    }

    final result = await matching.compute(user);
    final prefs = await repository.preferencesOf(user.id);
    final contacts = [for (final m in result.matched) _contactJson(m, prefs)];
    final now = _clock();

    final suggestions = <Map<String, Object?>>[];
    final location = user.currentLocation;
    if (location != otherLocation) {
      final candidates = result.matched.where((m) {
        final preference = prefs[m.user.id] ?? 'neutral';
        return m.mutual &&
            m.user.locationShared &&
            m.user.currentLocation == location &&
            preference != 'ratherAvoid';
      }).toList()
        ..sort((a, b) {
          final byPreference = _weight(prefs[a.user.id]).compareTo(_weight(prefs[b.user.id]));
          return byPreference != 0 ? byPreference : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      for (final match in candidates) {
        final preference = prefs[match.user.id] ?? 'neutral';
        suggestions.add({
          'contact': _contactJson(match, prefs),
          'reason': preference == 'loveToSee'
              ? 'You wanted to see ${match.name}. They are in $location right now.'
              : '${match.name} is in $location right now. Worth a quick catch-up?',
          'distanceLabel': 'Nearby',
          'sharedLocations': [location],
          'timeSinceLastSeen': timeSince(match.user.lastActiveAt, now),
        });
      }
    }

    return {
      'profile': profileJson(user),
      'supportedLocations': supportedLocations,
      'currentLocation': location,
      'contactsImported': result.imported,
      'contacts': contacts,
      'suggestions': suggestions,
    };
  }

  Future<User> updateProfile(
    User viewer, {
    String? name,
    String? bio,
    String? homeCity,
    String? profileImageUrl,
    bool? locationShared,
  }) {
    return repository.updateUser(
      viewer.id,
      name: name,
      bio: bio,
      homeCity: homeCity,
      profileImageUrl: profileImageUrl,
      locationShared: locationShared,
    );
  }

  /// Resolves `{location}` or `{latitude, longitude}` to a supported location.
  String resolveLocation({String? location, double? latitude, double? longitude}) {
    if (location != null) {
      if (!supportedLocations.contains(location)) {
        throw ApiException.validation('"location" must be one of ${supportedLocations.join(', ')}.');
      }
      return location;
    }
    if (latitude != null && longitude != null) {
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        throw ApiException.validation('"latitude" or "longitude" is out of range.');
      }
      return locationFromCoordinates(latitude, longitude);
    }
    throw ApiException.validation('Provide "location" or both "latitude" and "longitude".');
  }

  Map<String, Object?> _contactJson(MatchedContact match, Map<String, String> prefs) {
    final user = match.user;
    return {
      'id': user.id,
      'name': match.name,
      'isOnApp': true,
      'mutual': match.mutual,
      // Activity and city are only revealed to mutual contacts, and the city
      // only if its owner opted in to sharing it.
      'lastSeenAt': match.mutual ? user.lastActiveAt?.toUtc().toIso8601String() : null,
      'availableIn': match.mutual && user.locationShared ? [user.currentLocation] : <String>[],
      'preference': prefs[user.id] ?? 'neutral',
    };
  }

  int _weight(String? preference) => switch (preference) {
        'loveToSee' => 0,
        'like' => 1,
        'dislike' => 3,
        'ratherAvoid' => 4,
        _ => 2,
      };
}
