class ActivitySuggestion {
  const ActivitySuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.rating,
  });

  factory ActivitySuggestion.fromJson(Map<String, dynamic> json) {
    return ActivitySuggestion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      location: json['location'] as String? ?? '',
      rating: json['rating'] as int?,
    );
  }

  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final int? rating;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'rating': rating,
    };
  }

  ActivitySuggestion copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? location,
    int? rating,
  }) {
    return ActivitySuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      rating: rating ?? this.rating,
    );
  }
}
