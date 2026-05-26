import 'package:reconnect/models/conversation_starter.dart';

class ConversationStarterService {
  static const _conversationStarters = [
    ConversationStarter(
      id: 'q1',
      prompt: "What's something new you're interested in lately?",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q2',
      prompt: "How have you been? I'd love to catch up!",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q3',
      prompt: "Remember when we...? 😊",
      type: 'icebreaker',
      category: 'nostalgic',
    ),
    ConversationStarter(
      id: 'q4',
      prompt: "What's been the highlight of your month?",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q5',
      prompt: "I was thinking about you! How's everything going?",
      type: 'icebreaker',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q6',
      prompt: "Any fun plans coming up?",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q7',
      prompt: "I just saw something that reminded me of you",
      type: 'icebreaker',
      category: 'nostalgic',
    ),
    ConversationStarter(
      id: 'q8',
      prompt: "What's something you've learned recently?",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q9',
      prompt: "How do you usually spend your free time these days?",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q10',
      prompt: "I'd love to hear what you've been up to!",
      type: 'icebreaker',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q11',
      prompt: "Any good recommendations? (movies, books, music)",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q12',
      prompt: "How did we meet again? I have such good memories! 😄",
      type: 'question',
      category: 'nostalgic',
    ),
    ConversationStarter(
      id: 'q13',
      prompt: "What's something you're proud of recently?",
      type: 'question',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q14',
      prompt: "Long time no talk! What's new with you?",
      type: 'icebreaker',
      category: 'general',
    ),
    ConversationStarter(
      id: 'q15',
      prompt: "Any upcoming travel or adventures?",
      type: 'question',
      category: 'general',
    ),
  ];

  /// Get a random conversation starter
  ConversationStarter getRandomStarter() {
    final random = (DateTime.now().microsecond % _conversationStarters.length);
    return _conversationStarters[random];
  }

  /// Get all conversation starters
  List<ConversationStarter> getAllStarters() {
    return List<ConversationStarter>.from(_conversationStarters);
  }

  /// Get starters by category
  List<ConversationStarter> getStartersByCategory(String category) {
    return _conversationStarters
        .where((s) => s.category == category)
        .toList();
  }

  /// Update rating for a starter (in real app, would persist to backend)
  ConversationStarter rateStarter(
    ConversationStarter starter,
    int rating, {
    String? feedback,
  }) {
    return starter.copyWith(rating: rating);
  }

  /// Get the most helpful starters (with highest ratings)
  List<ConversationStarter> getTopRatedStarters({int limit = 5}) {
    final rated = _conversationStarters.where((s) => s.rating != null).toList();
    rated.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return rated.take(limit).toList();
  }
}
