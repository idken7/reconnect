import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/services/activity_suggestion_service.dart';

void main() {
  late ActivitySuggestionService service;

  setUp(() {
    service = ActivitySuggestionService();
  });

  group('getRandomActivity', () {
    test('returns an activity from the full catalog when no location is given', () {
      final activity = service.getRandomActivity();
      expect(service.getAllActivities().map((a) => a.id), contains(activity.id));
    });

    test('only returns activities available in the given location', () {
      final activity = service.getRandomActivity(location: 'urban');
      expect(activity.location == 'any' || activity.location == 'urban', isTrue);
    });
  });

  group('getAllActivities', () {
    test('returns every catalog entry and is safe to mutate', () {
      final activities = service.getAllActivities();
      expect(activities, isNotEmpty);

      activities.clear();

      expect(service.getAllActivities(), isNotEmpty);
    });
  });

  group('getActivitiesByCategory', () {
    test('only returns activities in the requested category', () {
      final activities = service.getActivitiesByCategory('food');
      expect(activities, isNotEmpty);
      expect(activities.every((a) => a.category == 'food'), isTrue);
    });

    test('returns an empty list for an unknown category', () {
      expect(service.getActivitiesByCategory('nonexistent'), isEmpty);
    });
  });

  group('getActivitiesByLocation', () {
    test('includes location-agnostic and location-specific activities', () {
      final activities = service.getActivitiesByLocation('rural');
      expect(activities, isNotEmpty);
      expect(activities.every((a) => a.location == 'any' || a.location == 'rural'), isTrue);
      expect(activities.any((a) => a.location == 'rural'), isTrue);
    });
  });

  group('getCategories', () {
    test('returns the distinct set of categories across all activities', () {
      final categories = service.getCategories();
      expect(categories, isNotEmpty);
      expect(categories, contains('food'));
      expect(categories, contains('outdoor'));
    });
  });

  group('rateActivity', () {
    test('returns a copy carrying the new rating without mutating the catalog', () {
      final original = service.getAllActivities().first;
      final rated = service.rateActivity(original, 5);

      expect(rated.rating, 5);
      expect(rated.id, original.id);
      expect(service.getAllActivities().first.rating, isNull);
    });
  });

  group('getTopRatedActivities', () {
    test('is empty since rateActivity never persists back to the catalog', () {
      service.rateActivity(service.getAllActivities().first, 5);
      expect(service.getTopRatedActivities(), isEmpty);
    });
  });
}
