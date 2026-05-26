import 'package:reconnect/models/activity_suggestion.dart';

class ActivitySuggestionService {
  static const _activities = [
    // Coffee & Casual
    ActivitySuggestion(
      id: 'a1',
      title: 'Coffee Catch-up',
      description: 'Meet for coffee and chat about life',
      category: 'casual',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a2',
      title: 'Lunch Date',
      description: 'Try a new restaurant or visit an old favorite',
      category: 'casual',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a3',
      title: 'Walk & Talk',
      description: 'Take a walk in a park and catch up',
      category: 'outdoor',
      location: 'any',
    ),
    // Food & Dining
    ActivitySuggestion(
      id: 'a4',
      title: 'Dinner Night',
      description: 'Enjoy a nice dinner together',
      category: 'food',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a5',
      title: 'Brunch',
      description: 'Leisurely brunch with mimosas or coffee',
      category: 'food',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a6',
      title: 'Food Truck Tour',
      description: 'Explore local food trucks together',
      category: 'food',
      location: 'urban',
    ),
    // Sports & Active
    ActivitySuggestion(
      id: 'a7',
      title: 'Hiking',
      description: 'Go for a hike on a local trail',
      category: 'outdoor',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a8',
      title: 'Sports or Fitness Class',
      description: 'Yoga, tennis, basketball, or gym session',
      category: 'active',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a9',
      title: 'Bike Ride',
      description: 'Casual bike ride through the city or countryside',
      category: 'outdoor',
      location: 'any',
    ),
    // Entertainment
    ActivitySuggestion(
      id: 'a10',
      title: 'Movie Night',
      description: 'Catch a new movie at the cinema',
      category: 'entertainment',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a11',
      title: 'Concert or Live Music',
      description: 'Enjoy live music together',
      category: 'entertainment',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a12',
      title: 'Comedy Show',
      description: 'Laugh at a stand-up comedy show',
      category: 'entertainment',
      location: 'urban',
    ),
    ActivitySuggestion(
      id: 'a13',
      title: 'Game Night',
      description: 'Board games, card games, or video games',
      category: 'entertainment',
      location: 'any',
    ),
    // Cultural
    ActivitySuggestion(
      id: 'a14',
      title: 'Museum Visit',
      description: 'Explore an art, history, or science museum',
      category: 'cultural',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a15',
      title: 'Theater',
      description: 'Enjoy a play or theatrical performance',
      category: 'cultural',
      location: 'urban',
    ),
    ActivitySuggestion(
      id: 'a16',
      title: 'Festival or Fair',
      description: 'Explore a local festival or fair',
      category: 'cultural',
      location: 'any',
    ),
    // Adventurous
    ActivitySuggestion(
      id: 'a17',
      title: 'Road Trip',
      description: 'Take a spontaneous road trip somewhere new',
      category: 'adventure',
      location: 'any',
    ),
    ActivitySuggestion(
      id: 'a18',
      title: 'Outdoor Adventure',
      description: 'Rock climbing, kayaking, or zip-lining',
      category: 'adventure',
      location: 'rural',
    ),
    // Shopping & Browsing
    ActivitySuggestion(
      id: 'a19',
      title: 'Shopping Day',
      description: 'Browse shops and try the latest trends',
      category: 'casual',
      location: 'urban',
    ),
    ActivitySuggestion(
      id: 'a20',
      title: 'Farmers Market',
      description: 'Explore local farmers market together',
      category: 'outdoor',
      location: 'any',
    ),
  ];

  /// Get a random activity suggestion
  ActivitySuggestion getRandomActivity({String? location}) {
    final activities = location != null
        ? _activities.where((a) => a.location == 'any' || a.location == location).toList()
        : _activities;

    if (activities.isEmpty) return _activities[0];

    final random = (DateTime.now().microsecond % activities.length);
    return activities[random];
  }

  /// Get all activities
  List<ActivitySuggestion> getAllActivities() {
    return List<ActivitySuggestion>.from(_activities);
  }

  /// Get activities by category
  List<ActivitySuggestion> getActivitiesByCategory(String category) {
    return _activities.where((a) => a.category == category).toList();
  }

  /// Get activities suitable for a location
  List<ActivitySuggestion> getActivitiesByLocation(String location) {
    return _activities
        .where((a) => a.location == 'any' || a.location == location)
        .toList();
  }

  /// Get activity categories
  Set<String> getCategories() {
    return _activities.map((a) => a.category).toSet();
  }

  /// Rate an activity (in real app, would persist to backend)
  ActivitySuggestion rateActivity(
    ActivitySuggestion activity,
    int rating, {
    String? feedback,
  }) {
    return activity.copyWith(rating: rating);
  }

  /// Get top-rated activities
  List<ActivitySuggestion> getTopRatedActivities({int limit = 5}) {
    final rated = _activities.where((a) => a.rating != null).toList();
    rated.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return rated.take(limit).toList();
  }
}
