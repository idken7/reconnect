class SpinHistory {
  const SpinHistory({
    required this.id,
    required this.contactId,
    required this.spunAt,
    this.action,
    this.actionTakenAt,
    this.suggestionUsed,
  });

  factory SpinHistory.fromJson(Map<String, dynamic> json) {
    return SpinHistory(
      id: json['id'] as String? ?? '',
      contactId: json['contactId'] as String? ?? '',
      spunAt: json['spunAt'] != null ? DateTime.tryParse(json['spunAt'] as String) ?? DateTime.now() : DateTime.now(),
      action: json['action'] as String?,
      actionTakenAt: json['actionTakenAt'] != null ? DateTime.tryParse(json['actionTakenAt'] as String) : null,
      suggestionUsed: json['suggestionUsed'] as String?,
    );
  }

  final String id;
  final String contactId;
  final DateTime spunAt;
  final String? action;
  final DateTime? actionTakenAt;
  final String? suggestionUsed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'spunAt': spunAt.toIso8601String(),
      'action': action,
      'actionTakenAt': actionTakenAt?.toIso8601String(),
      'suggestionUsed': suggestionUsed,
    };
  }

  SpinHistory copyWith({
    String? id,
    String? contactId,
    DateTime? spunAt,
    String? action,
    DateTime? actionTakenAt,
    String? suggestionUsed,
  }) {
    return SpinHistory(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      spunAt: spunAt ?? this.spunAt,
      action: action ?? this.action,
      actionTakenAt: actionTakenAt ?? this.actionTakenAt,
      suggestionUsed: suggestionUsed ?? this.suggestionUsed,
    );
  }
}
