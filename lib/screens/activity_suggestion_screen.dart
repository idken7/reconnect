import 'package:flutter/material.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/activity_suggestion_service.dart';
import 'package:reconnect/widgets/rating_widget.dart';

class ActivitySuggestionScreen extends StatefulWidget {
  final ReconnectContact contact;
  final String? userLocation;
  final Function(ActivitySuggestion) onSuggestionRated;

  const ActivitySuggestionScreen({
    Key? key,
    required this.contact,
    required this.onSuggestionRated,
    this.userLocation,
  }) : super(key: key);

  @override
  State<ActivitySuggestionScreen> createState() => _ActivitySuggestionScreenState();
}

class _ActivitySuggestionScreenState extends State<ActivitySuggestionScreen> {
  late List<ActivitySuggestion> _suggestions;
  int _currentIndex = 0;
  final _service = ActivitySuggestionService();
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _suggestions = List.generate(
      5,
      (_) => _service.getRandomActivity(location: widget.userLocation),
    );
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _rateSuggestion(int rating) {
    final rated = _service.rateActivity(_suggestions[_currentIndex], rating);
    widget.onSuggestionRated(rated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rating == 5 ? 'Great suggestion! 👍' : 'We\'ll get better at suggesting activities'),
        duration: const Duration(seconds: 1),
      ),
    );

    // Move to next suggestion
    if (_currentIndex < _suggestions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Load more suggestions
      setState(() {
        _suggestions.addAll(
          List.generate(
            5,
            (_) => _service.getRandomActivity(location: widget.userLocation),
          ),
        );
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
        title: const Text('Activity Suggestions'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${_suggestions.length}',
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
                            'In ${widget.contact.availableIn.first}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Swipeable suggestions
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return _SuggestionCard(
                  suggestion: suggestion,
                  contact: widget.contact,
                  onRated: _rateSuggestion,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.contact,
    required this.onRated,
  });

  final ActivitySuggestion suggestion;
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
            'Try this activity:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Activity card
          Card(
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange[50]!, Colors.orange[100]!],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  if (suggestion.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      suggestion.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (suggestion.category != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        suggestion.category!,
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
          // Location recommendations template
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended locations',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // TODO: Populate with actual location recommendations
                  Chip(
                    label: const Text('Location 1 - (coming soon)'),
                    avatar: const Icon(Icons.location_on, size: 16),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: const Text('Location 2 - (coming soon)'),
                    avatar: const Icon(Icons.location_on, size: 16),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: const Text('Location 3 - (coming soon)'),
                    avatar: const Icon(Icons.location_on, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
                    // TODO: Open contact interface to plan activity
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Swipe left or right to see more activities →',
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
