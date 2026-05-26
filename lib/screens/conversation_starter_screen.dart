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
  late ConversationStarter _currentStarter;
  final _service = ConversationStarterService();
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _currentStarter = _service.getRandomStarter();
  }

  void _getNewStarter() {
    setState(() {
      _currentStarter = _service.getRandomStarter();
      _hasRated = false;
    });
  }

  void _rateStarter(int rating) {
    final rated = _service.rateStarter(_currentStarter, rating);
    widget.onSuggestionRated(rated);

    setState(() => _hasRated = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rating == 5 ? 'Great! 👍' : 'Got it, we\'ll improve suggestions'),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), _getNewStarter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start a Conversation'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        child: Text(widget.contact.name[0].toUpperCase()),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.contact.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.contact.availableIn.isNotEmpty)
                              Text(
                                widget.contact.availableIn.first,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Prompt section
              const Text(
                'Try this conversation starter:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              // Main prompt card
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
                        _currentStarter.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      if (_currentStarter.category != null) ...[
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
                            _currentStarter.category!,
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
              const SizedBox(height: 24),
              // Rating widget
              if (!_hasRated)
                RatingWidget(
                  prompt: 'Is this helpful?',
                  onRated: _rateStarter,
                )
              else
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Thanks for the feedback!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _getNewStarter,
                        child: const Text('Get Another Starter'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copy to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sending message...')),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
