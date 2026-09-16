import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/reconnect_theme.dart';

class ReconnectNavDestination {
  const ReconnectNavDestination({required this.emoji, required this.label});

  final String emoji;
  final String label;
}

const _destinations = [
  ReconnectNavDestination(emoji: '👥', label: 'Contacts'),
  ReconnectNavDestination(emoji: '📍', label: 'Nearby'),
  ReconnectNavDestination(emoji: '🤝', label: 'Matches'),
  ReconnectNavDestination(emoji: '🙂', label: 'Profile'),
];

/// The app's bottom navigation: 4 flat tab destinations plus a raised
/// circular center button that opens the Spin the wheel page, matching the
/// mockup's `navItemsLeft` / center FAB / `navItemsRight` layout.
class ReconnectNavBar extends StatelessWidget {
  const ReconnectNavBar({
    super.key,
    required this.currentIndex,
    required this.spinActive,
    required this.onDestinationSelected,
    required this.onSpinTap,
  });

  final int currentIndex;
  final bool spinActive;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSpinTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // The blurred bar surface and the raised FAB are separate layers: the
    // bar needs its own ClipRect (so BackdropFilter only blurs the strip
    // behind it), but that same ClipRect would silently clip anything
    // positioned above the bar's own bounds — including the FAB, which is
    // meant to float above it. Keeping the FAB in an unclipped sibling
    // layer lets it overlap the bar without being cut off.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ReconnectColors.surface.withValues(alpha: 0.92),
                border: const Border(top: BorderSide(color: ReconnectColors.hairline)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomInset),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 2; i++)
                      _NavItem(
                        destination: _destinations[i],
                        selected: !spinActive && currentIndex == i,
                        onTap: () => onDestinationSelected(i),
                      ),
                    // Reserves the FAB's width so the two side groups stay
                    // evenly split, even though the FAB itself is drawn in
                    // the unclipped layer above.
                    const SizedBox(width: 58),
                    for (var i = 2; i < 4; i++)
                      _NavItem(
                        destination: _destinations[i],
                        selected: !spinActive && currentIndex == i,
                        onTap: () => onDestinationSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -30,
          child: _SpinFab(active: spinActive, onTap: onSpinTap),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final ReconnectNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.elasticOut,
              child: AnimatedOpacity(
                opacity: selected ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Text(destination.emoji, style: const TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: selected ? ReconnectColors.ink : ReconnectColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpinFab extends StatelessWidget {
  const _SpinFab({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ReconnectColors.accent,
          border: active ? Border.all(color: ReconnectColors.ink, width: 3) : null,
          boxShadow: [
            BoxShadow(
              color: ReconnectColors.accent.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}
