class SuggestionRating {
  const SuggestionRating({
    required this.id,
    required this.suggestionId,
    required this.suggestionType,
    required this.contactId,
    required this.rating,
    this.feedback,
    this.ratedAt,
  });

  factory SuggestionRating.fromJson(Map<String, dynamic> json) {
    return SuggestionRating(
      id: json['id'] as String? ?? '',
      suggestionId: json['suggestionId'] as String? ?? '',
      suggestionType: json['suggestionType'] as String? ?? 'question',
      contactId: json['contactId'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      feedback: json['feedback'] as String?,
      ratedAt: json['ratedAt'] != null ? DateTime.tryParse(json['ratedAt'] as String) : null,
    );
  }

  final String id;
  final String suggestionId;
  final String suggestionType;
  final String contactId;
  final int rating;
  final String? feedback;
  final DateTime? ratedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'suggestionId': suggestionId,
      'suggestionType': suggestionType,
      'contactId': contactId,
      'rating': rating,
      'feedback': feedback,
      'ratedAt': ratedAt?.toIso8601String(),
    };
  }

  SuggestionRating copyWith({
    String? id,
    String? suggestionId,
    String? suggestionType,
    String? contactId,
    int? rating,
    String? feedback,
    DateTime? ratedAt,
  }) {
    return SuggestionRating(
      id: id ?? this.id,
      suggestionId: suggestionId ?? this.suggestionId,
      suggestionType: suggestionType ?? this.suggestionType,
      contactId: contactId ?? this.contactId,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }
}
