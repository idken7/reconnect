import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/activity_suggestion_service.dart';
import '../services/conversation_starter_service.dart';
import '../theme/reconnect_theme.dart';
import 'message_preview_sheet.dart';
import 'rating_widget.dart';
import 'swipe_action_indicator.dart';

enum DeckKind { activity, convo }

/// Opens the swipeable "deck" bottom sheet — conversation starters or
/// activity ideas for [contact] — matching the mockup's `openDeck(kind)`.
Future<void> showSuggestionDeckSheet(
  BuildContext context, {
  required ReconnectContact contact,
  required DeckKind kind,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SuggestionDeckSheet(contact: contact, kind: kind),
  );
}

class _DeckCard {
  const _DeckCard({required this.title, required this.text, required this.category});

  final String? title;
  final String text;
  final String category;
}

class SuggestionDeckSheet extends StatefulWidget {
  const SuggestionDeckSheet({super.key, required this.contact, required this.kind});

  final ReconnectContact contact;
  final DeckKind kind;

  @override
  State<SuggestionDeckSheet> createState() => _SuggestionDeckSheetState();
}

class _SuggestionDeckSheetState extends State<SuggestionDeckSheet> with TickerProviderStateMixin {
  final _starterService = ConversationStarterService();
  final _activityService = ActivitySuggestionService();

  late List<_DeckCard> _cards;
  late final List<Object> _rawCards;
  int _currentIndex = 0;
  late AnimationController _enterController;
  late AnimationController _exitController;
  late AnimationController _snapBackController;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  Offset _exitDirection = Offset.zero;
  bool _showRating = false;
  String? _toast;
  Timer? _toastTimer;

  bool get _isActivity => widget.kind == DeckKind.activity;

  @override
  void initState() {
    super.initState();
    _rawCards = List.generate(5, (_) => _generate());
    _cards = _rawCards.map(_present).toList();
    _enterController = AnimationController(duration: const Duration(milliseconds: 280), vsync: this)..value = 1.0;
    _exitController = AnimationController(duration: const Duration(milliseconds: 260), vsync: this);
    _snapBackController = AnimationController(duration: const Duration(milliseconds: 220), vsync: this);
  }

  @override
  void dispose() {
    _enterController.dispose();
    _exitController.dispose();
    _snapBackController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  Object _generate() => _isActivity
      ? _activityService.getRandomActivity(location: widget.contact.availableIn.isEmpty ? null : widget.contact.availableIn.first)
      : _starterService.getRandomStarter();

  _DeckCard _present(Object raw) {
    if (raw is ActivitySuggestion) {
      return _DeckCard(title: raw.title, text: raw.description.isEmpty ? raw.title : raw.description, category: raw.category);
    }
    final starter = raw as ConversationStarter;
    return _DeckCard(title: null, text: starter.prompt, category: starter.category ?? 'general');
  }

  void _flashToast(String message) {
    setState(() => _toast = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _exitThenRun(VoidCallback onExited, {Offset direction = Offset.zero}) {
    setState(() => _exitDirection = direction);
    _exitController.forward(from: 0.0).then((_) {
      _exitController.reset();
      onExited();
    });
  }

  void _moveToNextCard() {
    setState(() {
      _showRating = false;
      if (_currentIndex >= _rawCards.length - 1) {
        _rawCards.addAll(List.generate(5, (_) => _generate()));
        _cards = _rawCards.map(_present).toList();
      }
      _currentIndex++;
      _dragOffset = Offset.zero;
    });
    _enterController.forward(from: 0.0);
  }

  void _recordRating(int rating) {
    final raw = _rawCards[_currentIndex];
    if (raw is ActivitySuggestion) {
      _activityService.rateActivity(raw, rating);
    } else {
      _starterService.rateStarter(raw as ConversationStarter, rating);
    }
  }

  void _onStarRated(int rating) {
    _exitThenRun(() {
      _recordRating(rating);
      _flashToast(rating == 5 ? 'Great! 👍' : "Got it, we'll improve suggestions");
      _moveToNextCard();
    });
  }

  void _dismissCard() {
    final direction = Offset(_dragOffset.dx == 0 ? -1.0 : _dragOffset.dx.sign, 0);
    _exitThenRun(_moveToNextCard, direction: direction);
  }

  void _revealRating() {
    _exitThenRun(() {
      setState(() => _showRating = true);
      _enterController.forward(from: 0.0);
    }, direction: const Offset(0, 1));
  }

  void _resetCard() {
    if (_dragOffset == Offset.zero) return;
    final animation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOut),
    );
    void tick() {
      if (!mounted) return;
      setState(() => _dragOffset = animation.value);
    }

    animation.addListener(tick);
    _snapBackController.forward(from: 0.0).whenComplete(() => animation.removeListener(tick));
  }

  void _beginSend() {
    _resetCard();
    unawaited(_showSendPreview());
  }

  Future<void> _showSendPreview() async {
    final card = _cards[_currentIndex];
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => MessagePreviewSheet(
        title: _isActivity ? 'Plan this activity' : 'Send conversation starter',
        recipientName: widget.contact.name,
        initialMessage: card.title == null ? card.text : '${card.title}\n${card.text}',
        confirmLabel: _isActivity ? 'Plan' : 'Send',
        confirmIcon: _isActivity ? Icons.calendar_today_rounded : Icons.send_rounded,
      ),
    );
    if (!mounted || message == null) return;

    _exitThenRun(() {
      _recordRating(5);
      _flashToast(_isActivity ? 'Added to your plan!' : 'Sent!');
      _moveToNextCard();
    }, direction: const Offset(0, -1));
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    const distanceThreshold = 70.0;
    const velocityThreshold = 500.0;
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;

    if (dy.abs() > dx.abs()) {
      if (dy < -distanceThreshold || velocity.dy < -velocityThreshold) {
        _beginSend();
        return;
      }
      if (dy > distanceThreshold || velocity.dy > velocityThreshold) {
        _revealRating();
        return;
      }
    } else if (dx.abs() > distanceThreshold || velocity.dx.abs() > velocityThreshold) {
      _dismissCard();
      return;
    }
    _resetCard();
  }

  @override
  Widget build(BuildContext context) {
    final card = _cards[_currentIndex % _cards.length];
    final cardGradientColors = _isActivity ? const [Color(0xFFFFE3CF), Color(0xFFFFC9A3)] : const [Color(0xFFF7ECD2), Color(0xFFF0DBA0)];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: ReconnectColors.hairline, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: ReconnectColors.accent, shape: BoxShape.circle),
                      child: Text(
                        _initialOf(widget.contact.name),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_isActivity ? 'Activity ideas' : 'Conversation starters', style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          'for ${widget.contact.name} · ${(_currentIndex % _cards.length) + 1} / ${_cards.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ReconnectColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('✕', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: ReconnectColors.mutedText)),
                  ),
                ],
              ),
              if (_showRating)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: StarRatingWidget(
                    prompt: _isActivity ? 'Rate this activity suggestion' : 'Rate this conversation starter',
                    onRated: _onStarRated,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _isActivity ? '↑ plan · ↓ rate · ← → skip' : '↑ send · ↓ rate · ← → skip',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ReconnectColors.mutedText),
                  ),
                ),
                SizedBox(
                  height: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final offset in [16.0, 8.0])
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(0, offset),
                            child: Transform.scale(
                              scale: 1 - offset / 200,
                              child: Opacity(
                                opacity: offset == 16.0 ? 0.45 : 0.7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: cardGradientColors),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      SwipeActionOverlay(
                        dragOffset: _isDragging ? _dragOffset : Offset.zero,
                        threshold: 70,
                        actions: {
                          SwipeDirection.up: SwipeActionSpec(
                            icon: _isActivity ? Icons.calendar_today_rounded : Icons.send_rounded,
                            label: _isActivity ? 'Plan' : 'Send',
                            color: const Color(0xFF2E9E5B),
                          ),
                          SwipeDirection.down: const SwipeActionSpec(icon: Icons.star_rounded, label: 'Rate', color: Color(0xFFE0A600)),
                          SwipeDirection.left: const SwipeActionSpec(icon: Icons.arrow_back_rounded, label: 'Skip', color: Color(0xFF8A7C6B)),
                          SwipeDirection.right: const SwipeActionSpec(icon: Icons.arrow_forward_rounded, label: 'Skip', color: Color(0xFF8A7C6B)),
                        },
                      ),
                      _DeckSwipeCard(
                        card: card,
                        gradientColors: cardGradientColors,
                        dragOffset: _dragOffset,
                        enterController: _enterController,
                        exitController: _exitController,
                        exitDirection: _exitDirection,
                        isDragging: _isDragging,
                        onDragStart: (_) {
                          _snapBackController.stop();
                          setState(() => _isDragging = true);
                        },
                        onDragUpdate: (details) => setState(() => _dragOffset = _dragOffset + details.delta),
                        onDragEnd: _onPanEnd,
                      ),
                    ],
                  ),
                ),
              ],
              if (_toast != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: ReconnectColors.ink, borderRadius: BorderRadius.circular(12)),
                    child: Text(_toast!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckSwipeCard extends StatelessWidget {
  const _DeckSwipeCard({
    required this.card,
    required this.gradientColors,
    required this.dragOffset,
    required this.enterController,
    required this.exitController,
    required this.exitDirection,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final _DeckCard card;
  final List<Color> gradientColors;
  final Offset dragOffset;
  final AnimationController enterController;
  final AnimationController exitController;
  final Offset exitDirection;
  final bool isDragging;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([enterController, exitController]),
      builder: (context, _) {
        final screenSize = MediaQuery.of(context).size;
        final enterT = Curves.easeOut.transform(enterController.value.clamp(0.0, 1.0));
        final exitT = Curves.easeIn.transform(exitController.value.clamp(0.0, 1.0));

        final exitTranslate = Offset(exitDirection.dx * exitT * screenSize.width, exitDirection.dy * exitT * screenSize.height);
        final dragFraction = isDragging ? Offset(dragOffset.dx / 200, dragOffset.dy / 200) : Offset.zero;
        final rotation = (dragFraction.dx * 0.1).clamp(-0.1, 0.1);
        final dragOpacity = 1.0 - (math.max(dragFraction.dx.abs(), dragFraction.dy.abs()) / 3).clamp(0, 1);
        final opacity = ((dragOpacity * 0.5 + 0.5) * (1 - exitT) * enterT).clamp(0.0, 1.0);
        final scale = (0.92 + 0.08 * enterT) * (1 - 0.05 * exitT);

        return GestureDetector(
          onPanStart: onDragStart,
          onPanUpdate: onDragUpdate,
          onPanEnd: onDragEnd,
          child: Transform.translate(
            offset: exitTranslate + dragOffset,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 12))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (card.title != null) ...[
                          Text(card.title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: ReconnectColors.ink)),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          card.text,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: ReconnectColors.ink, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(card.category, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: ReconnectColors.ink)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _initialOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts.last[0] : '';
  return (first + second).toUpperCase();
}
