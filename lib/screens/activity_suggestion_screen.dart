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
  late ActivitySuggestion _currentSuggestion;
  final _service = ActivitySuggestionService();
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _currentSuggestion = _service.getRandomActivity(location: widget.userLocation);
  }

  void _getNewSuggestion() {
    setState(() {
      _currentSuggestion = _service.getRandomActivity(location: widget.userLocation);
      _hasRated = false;
    });
  }

  void _rateSuggestion(int rating) {
    final rated = _service.rateActivity(_currentSuggestion, rating);
    widget.onSuggestionRated(rated);

    setState(() => _hasRated = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(rating == 5 ? 'Great suggestion! 👍' : 'We\'ll get better at suggesting activities'),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), _getNewSuggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan an Activity'),
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
                                'In ${widget.contact.availableIn.first}',
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
              // Suggestion header
              const Text(
                'Here\'s something fun you could do:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              // Activity card
              Card(
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentSuggestion.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _currentSuggestion.category,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentSuggestion.description,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_currentSuggestion.location.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentSuggestion.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Rating widget
              if (!_hasRated)
                RatingWidget(
                  prompt: 'Would you like to do this?',
                  onRated: _rateSuggestion,
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
                        'Thanks! We\'ll learn your preferences',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _getNewSuggestion,
                        child: const Text('See Another Activity'),
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
                          const SnackBar(content: Text('Added to calendar')),
                        );
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Schedule'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Inviting...')),
                        );
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Invite'),
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
