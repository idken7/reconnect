import 'package:flutter/material.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/conversation_starter_service.dart';
import 'package:reconnect/widgets/rating_widget.dart';

class ConversationStarterScreen extends StatefulWidget {
  final ReconnectContact contact;
  final Function(ConversationStarter) onSuggestionRated;

  const ConversationStarterScreen({
    Key? key,
    required this.contact,
    required this.onSuggestionRated,
  }) : super(key: key);

  @override
  State<ConversationStarterScreen> createState() => _ConversationStarterScreenState();
}

class _ConversationStarterScreenState extends State<ConversationStarterScreen> {
  late List<ConversationStarter> _starters;
  int _currentIndex = 0;
  final _service = ConversationStarterService();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _starters = List.generate(5, (_) => _service.getRandomStarter());
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _rateStarter(int rating) {
    final rated = _service.rateStarter(_starters[_currentIndex], rating);
    widget.onSuggestionRated(rated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rating == 5 ? 'Great! 👍' : 'Got it, we\'ll improve suggestions'),
        duration: const Duration(seconds: 1),
      ),
    );

    // Move to next starter
    if (_currentIndex < _starters.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Load more starters
      setState(() {
        _starters.addAll(List.generate(5, (_) => _service.getRandomStarter()));
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation Starters'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${_starters.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Contact info
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: widget.contact.preference.color.withOpacity(0.2),
                    child: Text(
                      widget.contact.preference.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contact.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.contact.availableIn.isNotEmpty)
                          Text(
                            widget.contact.availableIn.first,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Swipeable starters
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: _starters.length,
              itemBuilder: (context, index) {
                final starter = _starters[index];
                return _StarterCard(
                  starter: starter,
                  contact: widget.contact,
                  onRated: _rateStarter,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({
    required this.starter,
    required this.contact,
    required this.onRated,
  });

  final ConversationStarter starter;
  final ReconnectContact contact;
  final Function(int) onRated;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Try this conversation starter:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Prompt card
          Card(
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    starter.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  if (starter.category != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        starter.category!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Rating widget
          RatingWidget(
            prompt: 'Is this helpful?',
            onRated: onRated,
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening contact interface...')),
                    );
                    // TODO: Open contact interface to send message
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Swipe left or right to see more starters →',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
