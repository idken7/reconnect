import 'package:flutter/material.dart';

class RatingWidget extends StatelessWidget {
  final String prompt;
  final Function(int) onRated;
  final bool showFeedback;

  const RatingWidget({
    Key? key,
    required this.prompt,
    required this.onRated,
    this.showFeedback = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            prompt,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RatingButton(
                icon: Icons.thumb_down,
                label: 'Not helpful',
                value: 1,
                onPressed: () => onRated(1),
              ),
              const SizedBox(width: 16),
              _RatingButton(
                icon: Icons.thumb_up,
                label: 'Helpful',
                value: 5,
                onPressed: () => onRated(5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onPressed;

  const _RatingButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class StarRatingWidget extends StatefulWidget {
  final String prompt;
  final Function(int) onRated;
  final int? initialRating;

  const StarRatingWidget({
    Key? key,
    required this.prompt,
    required this.onRated,
    this.initialRating,
  }) : super(key: key);

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            widget.prompt,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() => _rating = index + 1);
                  widget.onRated(index + 1);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
