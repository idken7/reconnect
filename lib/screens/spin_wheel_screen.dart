import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/random_contact_service.dart';
import 'package:reconnect/theme/reconnect_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _SpinScope { nearby, anywhere }

class WheelSlicePainter extends CustomPainter {
  final List<ReconnectContact> contacts;
  final double rotation;
  final Color emptyColor;
  final Color sliceBorderColor;

  WheelSlicePainter({
    required this.contacts,
    required this.rotation,
    required this.emptyColor,
    required this.sliceBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (contacts.isEmpty) {
      // Draw a default circle if no contacts
      final paint = Paint()
        ..color = emptyColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2,
        paint,
      );
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = 2 * math.pi / contacts.length;

    // Draw each slice
    for (int i = 0; i < contacts.length; i++) {
      final contact = contacts[i];
      final startAngle = rotation + (i * sliceAngle);
      final endAngle = startAngle + sliceAngle;

      // Draw slice background
      final paint = Paint()
        ..color = contact.preference.color
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + radius * math.cos(startAngle),
        center.dy + radius * math.sin(startAngle),
      );
      path.arcToPoint(
        Offset(
          center.dx + radius * math.cos(endAngle),
          center.dy + radius * math.sin(endAngle),
        ),
        radius: Radius.circular(radius),
        clockwise: true,
      );
      path.close();

      canvas.drawPath(path, paint);

      // Draw slice border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawPath(path, borderPaint);

      // Draw contact info (initials or name first letter), skipping labels
      // entirely once there are too many slices to render legibly.
      if (contacts.length <= 24) {
        final midAngle = startAngle + (sliceAngle / 2);
        final textRadius = radius * 0.65;
        final textX = center.dx + textRadius * math.cos(midAngle);
        final textY = center.dy + textRadius * math.sin(midAngle);

        final fontSize = (sliceAngle * radius * 0.55).clamp(9.0, 20.0);

        final textPainter = TextPainter(
          text: TextSpan(
            text: contact.name[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(textX - textPainter.width / 2, textY - textPainter.height / 2),
        );
      }
    }

    // Draw center circle (for visual appeal)
    final centerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.15, centerCirclePaint);

    // Draw center circle border
    final centerBorderPaint = Paint()
      ..color = sliceBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius * 0.15, centerBorderPaint);
  }

  @override
  bool shouldRepaint(WheelSlicePainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.contacts.length != contacts.length;
  }
}

class SpinWheelScreen extends StatefulWidget {
  final List<ReconnectContact> contacts;
  final List<NearbySuggestion> nearbySuggestions;
  final Function(ReconnectContact) onContactSpun;

  const SpinWheelScreen({
    super.key,
    required this.contacts,
    required this.onContactSpun,
    this.nearbySuggestions = const <NearbySuggestion>[],
  });

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> with TickerProviderStateMixin {
  late AnimationController _wheelController;
  late AnimationController _pulseController;
  late AnimationController _cardController;
  // Drives the wheel's rotation for the current spin; recreated each time
  // _spinWheel() runs so its end value can be aimed at the pre-selected
  // contact's slice. Starts and ends where the previous spin left off so
  // consecutive spins don't visually snap.
  Animation<double> _rotationAnimation = const AlwaysStoppedAnimation<double>(0.0);
  double _wheelAngle = 0.0;
  // Snapshot of the eligible-contacts list the wheel is currently painted
  // with. Only refreshed from the live filters while not spinning, so a
  // slice the wheel is animating toward can't shift under it mid-spin.
  List<ReconnectContact> _eligibleContacts = const [];
  ReconnectContact? _selectedContact;
  final _randomService = RandomContactService();
  int _daysThreshold = 30;
  _SpinScope _scope = _SpinScope.nearby;
  bool _isSpinning = false;
  // Guards against the delayed auto-navigate firing a second time after the
  // "View profile" button already navigated for this spin.
  bool _hasNavigatedForSpin = false;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(duration: const Duration(milliseconds: 4200), vsync: this);
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _cardController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedScope = prefs.getString('spin_wheel_scope');
    if (!mounted) return;
    setState(() {
      _scope = savedScope == 'anywhere' ? _SpinScope.anywhere : _SpinScope.nearby;
    });
  }

  Future<void> _saveScope(_SpinScope scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spin_wheel_scope', scope == _SpinScope.anywhere ? 'anywhere' : 'nearby');
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _pulseController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  String _formatDaysLabel(int days) {
    if (days < 30) {
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
    if (days < 365) {
      final months = (days / 30).round();
      return '$months ${months == 1 ? 'month' : 'months'}';
    }
    final years = (days / 365).round();
    return '$years ${years == 1 ? 'year' : 'years'}';
  }

  List<ReconnectContact> _computeEligible() {
    final eligible = _randomService
        .getEligibleContacts(widget.contacts, daysThreshold: _daysThreshold)
        .where((c) => c.preference != ReconnectPreference.ratherAvoid)
        .toList();
    if (_scope == _SpinScope.nearby) {
      final nearbyIds = widget.nearbySuggestions.map((s) => s.contact.id).toSet();
      final nearbyOnly = eligible.where((c) => nearbyIds.contains(c.id)).toList();
      if (nearbyOnly.isNotEmpty) return nearbyOnly;
    }
    return eligible;
  }

  /// Points straight up (12 o'clock) in the wheel's own angle convention:
  /// [WheelSlicePainter] measures slice angles from the positive x-axis
  /// (3 o'clock) increasing clockwise, so 12 o'clock is -pi/2.
  static const double _pointerAngle = -math.pi / 2;
  static const int _extraSpins = 6;

  void _spinWheel() {
    if (_isSpinning) return;

    final eligible = _eligibleContacts;
    if (eligible.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contacts match your criteria. Try adjusting the threshold or scope.')),
      );
      return;
    }

    // Pick the winner up front, then aim the spin so the wheel's own motion
    // is what lands on them under the fixed pointer, instead of spinning for
    // a while and then swapping in an unrelated result.
    final winningIndex = math.Random().nextInt(eligible.length);
    final contact = eligible[winningIndex];
    final sliceAngle = 2 * math.pi / eligible.length;
    final targetCenterAngle = (winningIndex + 0.5) * sliceAngle;
    var remainder = (_pointerAngle - targetCenterAngle) % (2 * math.pi);
    if (remainder < 0) remainder += 2 * math.pi;
    final totalRotation = _extraSpins * 2 * math.pi + remainder;

    setState(() {
      _isSpinning = true;
      _selectedContact = null;
      _hasNavigatedForSpin = false;
    });

    _rotationAnimation = Tween<double>(
      begin: _wheelAngle,
      end: _wheelAngle + totalRotation,
    ).animate(CurvedAnimation(parent: _wheelController, curve: Curves.easeOutQuart));

    _wheelController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      _wheelAngle += totalRotation;
      setState(() {
        _isSpinning = false;
        _selectedContact = contact;
      });
      _cardController.forward(from: 0.0);

      // Give the reveal card a moment to animate in and register with the
      // user before moving on, rather than either flipping the screen the
      // instant the wheel stops or leaving the user stranded here forever.
      // The "View profile" button can still jump ahead of this.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _isSpinning || _selectedContact != contact || _hasNavigatedForSpin) {
          return;
        }
        _hasNavigatedForSpin = true;
        widget.onContactSpun(contact);
      });
    });
  }

  void _goToSelectedContact() {
    if (_hasNavigatedForSpin || _selectedContact == null) return;
    _hasNavigatedForSpin = true;
    widget.onContactSpun(_selectedContact!);
  }

  @override
  Widget build(BuildContext context) {
    // Only refresh the list the wheel is painted with while idle — see the
    // field doc on _eligibleContacts for why it must stay frozen mid-spin.
    if (!_isSpinning) {
      _eligibleContacts = _computeEligible();
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text('Spin the wheel', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: ReconnectColors.chipBackground, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  for (final scope in _SpinScope.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: _isSpinning
                            ? null
                            : () {
                                setState(() {
                                  _scope = scope;
                                  _selectedContact = null;
                                });
                                _saveScope(scope);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _scope == scope ? ReconnectColors.ink : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            scope == _SpinScope.nearby ? 'Nearby people' : 'Anywhere',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _scope == scope ? Colors.white : ReconnectColors.chipForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Haven't talked in", style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        '${_formatDaysLabel(_daysThreshold)}+',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: ReconnectColors.accent),
                      ),
                    ],
                  ),
                  Slider(
                    value: _daysThreshold.toDouble(),
                    min: 7,
                    max: 400,
                    divisions: 393,
                    onChanged: _isSpinning
                        ? null
                        : (value) => setState(() {
                              _daysThreshold = value.round();
                              _selectedContact = null;
                            }),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 week', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: ReconnectColors.mutedTextStrong)),
                      Text('1 year+', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: ReconnectColors.mutedTextStrong)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_eligibleContacts.length} people eligible',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ReconnectColors.mutedText),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_wheelController, _pulseController]),
                        builder: (context, child) {
                          final pulseT = Curves.easeInOut.transform(_pulseController.value);
                          final scale = _isSpinning ? 1.0 : 1.0 + 0.05 * pulseT;
                          return Transform.scale(
                            scale: scale,
                            child: Transform.rotate(angle: _rotationAnimation.value, child: child),
                          );
                        },
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: ReconnectColors.accent.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 5),
                            ],
                          ),
                          child: CustomPaint(
                            painter: WheelSlicePainter(
                              contacts: _eligibleContacts,
                              rotation: 0.0,
                              emptyColor: ReconnectColors.hairline,
                              sliceBorderColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -14,
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 40,
                          color: ReconnectColors.ink,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _isSpinning ? null : _spinWheel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ReconnectColors.ink,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 10))],
                      ),
                      child: Text(
                        _isSpinning ? 'Spinning…' : 'Spin the wheel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedContact != null) ...[
              const SizedBox(height: 24),
              ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOut)),
                child: FadeTransition(
                  opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOut)),
                  child: GestureDetector(
                    onTap: _goToSelectedContact,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: ReconnectColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: ReconnectColors.accent, shape: BoxShape.circle),
                            child: Text(
                              _selectedContact!.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedContact!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                Text(
                                  _randomService.getTimeSinceLastContact(_selectedContact!),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ReconnectColors.mutedText),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: ReconnectColors.mutedTextStrong),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
