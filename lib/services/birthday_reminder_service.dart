import 'package:reconnect/models.dart';

class BirthdayReminderService {
  /// Get upcoming birthdays for contacts within specified days
  List<ReconnectContact> getUpcomingBirthdays(
    List<ReconnectContact> contacts, {
    int daysAhead = 30,
  }) {
    final now = DateTime.now();
    final upcoming = <ReconnectContact>[];

    for (final contact in contacts) {
      if (contact.birthday == null) continue;

      final birthday = contact.birthday!;
      final thisBirthday = DateTime(now.year, birthday.month, birthday.day);

      // If birthday already passed this year, check next year
      DateTime nextBirthday;
      if (thisBirthday.isBefore(now)) {
        nextBirthday = DateTime(now.year + 1, birthday.month, birthday.day);
      } else {
        nextBirthday = thisBirthday;
      }

      final daysUntil = nextBirthday.difference(now).inDays;
      if (daysUntil >= 0 && daysUntil <= daysAhead) {
        upcoming.add(contact);
      }
    }

    // Sort by days until birthday
    upcoming.sort((a, b) {
      final aDays = _getDaysUntilBirthday(a.birthday!);
      final bDays = _getDaysUntilBirthday(b.birthday!);
      return aDays.compareTo(bDays);
    });

    return upcoming;
  }

  /// Get contacts with birthdays today
  List<ReconnectContact> getBirthdaysToday(List<ReconnectContact> contacts) {
    final now = DateTime.now();
    return contacts.where((c) {
      if (c.birthday == null) return false;
      final b = c.birthday!;
      return b.month == now.month && b.day == now.day;
    }).toList();
  }

  /// Check if a contact has a birthday today
  bool isBirthdayToday(ReconnectContact contact) {
    if (contact.birthday == null) return false;
    final now = DateTime.now();
    final b = contact.birthday!;
    return b.month == now.month && b.day == now.day;
  }

  /// Get days until birthday for a contact
  int getDaysUntilBirthday(DateTime birthday) {
    return _getDaysUntilBirthday(birthday);
  }

  /// Get birthday as a formatted string
  String getBirthdayString(DateTime birthday) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[birthday.month]} ${birthday.day}';
  }

  /// Get age from birthday
  int getAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  /// Get birthday reminder message
  String getBirthdayMessage(ReconnectContact contact) {
    if (contact.birthday == null) return '';

    final daysUntil = _getDaysUntilBirthday(contact.birthday!);
    if (daysUntil == 0) {
      return "🎉 Today is ${contact.name}'s birthday!";
    } else if (daysUntil == 1) {
      return "🎂 ${contact.name}'s birthday is tomorrow!";
    } else {
      return "🎁 ${contact.name}'s birthday is in $daysUntil days";
    }
  }

  int _getDaysUntilBirthday(DateTime birthday) {
    final now = DateTime.now();
    var thisBirthday = DateTime(now.year, birthday.month, birthday.day);

    if (thisBirthday.isBefore(now)) {
      thisBirthday = DateTime(now.year + 1, birthday.month, birthday.day);
    }

    return thisBirthday.difference(now).inDays;
  }
}
