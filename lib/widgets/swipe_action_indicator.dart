import 'package:flutter/material.dart';

/// The four directions a swipeable card in this app can be dragged.
enum SwipeDirection { up, down, left, right }

/// What a given [SwipeDirection] does, shown to the user as they drag.
class SwipeActionSpec {
  const SwipeActionSpec({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

/// A Tinder-style stamp that fades and scales in over a swipeable card as
/// the user drags it, showing which action will fire (and in which
/// direction) if they release past the threshold — so the swipe itself
/// communicates and performs the action instead of a set of separate
/// buttons underneath the card.
class SwipeActionOverlay extends StatelessWidget {
  const SwipeActionOverlay({
    super.key,
    required this.dragOffset,
    required this.actions,
    this.threshold = 100.0,
  });

  final Offset dragOffset;
  final Map<SwipeDirection, SwipeActionSpec> actions;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final dx = dragOffset.dx;
    final dy = dragOffset.dy;
    if (dx == 0 && dy == 0) return const SizedBox.shrink();

    final SwipeDirection direction;
    final double magnitude;
    if (dy.abs() > dx.abs()) {
      direction = dy < 0 ? SwipeDirection.up : SwipeDirection.down;
      magnitude = dy.abs();
    } else {
      direction = dx < 0 ? SwipeDirection.left : SwipeDirection.right;
      magnitude = dx.abs();
    }

    final spec = actions[direction];
    if (spec == null) return const SizedBox.shrink();

    final t = (magnitude / threshold).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.7 + 0.3 * t,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: spec.color.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(spec.icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    spec.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
