import 'package:reconnect/models.dart';

class RandomContactService {
  RandomContactService();

  /// Select a random contact who hasn't been contacted in the specified days
  /// Returns null if no contacts match the criteria
  ReconnectContact? getRandomContact(
    List<ReconnectContact> contacts, {
    int daysThreshold = 90,
  }) {
    if (contacts.isEmpty) return null;

    final now = DateTime.now();
    final thresholdDate = now.subtract(Duration(days: daysThreshold));

    final eligible = contacts.where((contact) {
      if (contact.lastContacted == null) return true;
      return contact.lastContacted!.isBefore(thresholdDate);
    }).toList();

    if (eligible.isEmpty) return null;

    final random = (eligible.length * (DateTime.now().millisecond / 1000)).toInt();
    return eligible[random % eligible.length];
  }

  /// Get contacts sorted by how long it's been since last contact
  List<ReconnectContact> getContactsByLastContacted(
    List<ReconnectContact> contacts,
  ) {
    final sorted = List<ReconnectContact>.from(contacts);
    sorted.sort((a, b) {
      final aTime = a.lastContacted ?? DateTime(1970);
      final bTime = b.lastContacted ?? DateTime(1970);
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  /// Get the time since last contact as a human-readable string
  String getTimeSinceLastContact(ReconnectContact contact) {
    if (contact.lastContacted == null) {
      return "Never contacted";
    }

    final now = DateTime.now();
    final difference = now.difference(contact.lastContacted!);

    if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return "$weeks ${weeks == 1 ? 'week' : 'weeks'} ago";
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return "$months ${months == 1 ? 'month' : 'months'} ago";
    } else {
      final years = (difference.inDays / 365).floor();
      return "$years ${years == 1 ? 'year' : 'years'} ago";
    }
  }
}
