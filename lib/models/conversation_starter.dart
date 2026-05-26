class ConversationStarter {
  const ConversationStarter({
    required this.id,
    required this.prompt,
    required this.type,
    this.category,
    this.rating,
  });

  factory ConversationStarter.fromJson(Map<String, dynamic> json) {
    return ConversationStarter(
      id: json['id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      type: json['type'] as String? ?? 'question',
      category: json['category'] as String?,
      rating: json['rating'] as int?,
    );
  }

  final String id;
  final String prompt;
  final String type;
  final String? category;
  final int? rating;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prompt': prompt,
      'type': type,
      'category': category,
      'rating': rating,
    };
  }

  ConversationStarter copyWith({
    String? id,
    String? prompt,
    String? type,
    String? category,
    int? rating,
  }) {
    return ConversationStarter(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      type: type ?? this.type,
      category: category ?? this.category,
      rating: rating ?? this.rating,
    );
  }
}
