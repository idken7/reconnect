import 'package:flutter/material.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/services/birthday_reminder_service.dart';

class BirthdayReminderCard extends StatelessWidget {
  final List<ReconnectContact> contacts;
  final Function(ReconnectContact)? onBirthdayTapped;

  const BirthdayReminderCard({
    Key? key,
    required this.contacts,
    this.onBirthdayTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = BirthdayReminderService();
    final upcomingBirthdays = service.getUpcomingBirthdays(contacts, daysAhead: 30);

    if (upcomingBirthdays.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cake, color: Colors.pink, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Upcoming Birthdays',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...upcomingBirthdays.take(3).map(
              (contact) {
                final message = service.getBirthdayMessage(contact);
                return BirthdayTile(
                  contact: contact,
                  message: message,
                  onTap: onBirthdayTapped != null ? () => onBirthdayTapped!(contact) : null,
                );
              },
            ),
            if (upcomingBirthdays.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${upcomingBirthdays.length - 3} more',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BirthdayTile extends StatelessWidget {
  final ReconnectContact contact;
  final String message;
  final VoidCallback? onTap;

  const BirthdayTile({
    Key? key,
    required this.contact,
    required this.message,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.pink[100],
            child: Text(
              contact.name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.pink[300],
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Wish',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
