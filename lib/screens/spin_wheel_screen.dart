import 'package:flutter/material.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/random_contact_service.dart';

class SpinWheelScreen extends StatefulWidget {
  final List<ReconnectContact> contacts;
  final Function(ReconnectContact) onContactSpun;

  const SpinWheelScreen({
    Key? key,
    required this.contacts,
    required this.onContactSpun,
  }) : super(key: key);

  @override
  State<SpinWheelScreen> createState() => _SpinWheelScreenState();
}

class _SpinWheelScreenState extends State<SpinWheelScreen> with TickerProviderStateMixin {
  late AnimationController _wheelController;
  late AnimationController _pulseController;
  ReconnectContact? _selectedContact;
  final _randomService = RandomContactService();
  int _daysThreshold = 90;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;

    setState(() => _isSpinning = true);

    _wheelController.forward(from: 0.0).then((_) {
      final contact = _randomService.getRandomContact(
        widget.contacts,
        daysThreshold: _daysThreshold,
      );

      if (contact != null) {
        setState(() => _selectedContact = contact);
        widget.onContactSpun(contact);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No contacts match your criteria. Try adjusting the threshold.'),
          ),
        );
      }

      setState(() => _isSpinning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin the Wheel'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Threshold selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Find someone you haven\'t talked to in:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 30, label: Text('1 month')),
                          ButtonSegment(value: 90, label: Text('3 months')),
                          ButtonSegment(value: 180, label: Text('6 months')),
                          ButtonSegment(value: 365, label: Text('1 year')),
                        ],
                        selected: {_daysThreshold},
                        onSelectionChanged: (value) {
                          setState(() => _daysThreshold = value.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Spin wheel
              Center(
                child: Column(
                  children: [
                    RotationTransition(
                      turns: Tween(begin: 0.0, end: 5.0).animate(_wheelController),
                      child: ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.05).animate(
                          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                        ),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue[300]!, Colors.blue[700]!],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.people,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSpinning ? null : _spinWheel,
                      icon: const Icon(Icons.casino),
                      label: const Text('SPIN THE WHEEL'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedContact != null) ...[
                const SizedBox(height: 40),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              child: Text(_selectedContact!.name[0].toUpperCase()),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedContact!.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _randomService.getTimeSinceLastContact(_selectedContact!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Message feature coming soon')),
                                  );
                                },
                                icon: const Icon(Icons.message),
                                label: const Text('Message'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Call feature coming soon')),
                                  );
                                },
                                icon: const Icon(Icons.call),
                                label: const Text('Call'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
