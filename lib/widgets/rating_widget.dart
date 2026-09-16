import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StarRatingWidget extends StatefulWidget {
  final String prompt;
  final Function(int) onRated;
  final int? initialRating;

  const StarRatingWidget({
    super.key,
    required this.prompt,
    required this.onRated,
    this.initialRating,
  });

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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    index < _rating ? CupertinoIcons.star_fill : CupertinoIcons.star,
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
