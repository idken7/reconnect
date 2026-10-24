import '../db/repository.dart';
import '../models.dart';
import '../util.dart';
import 'dashboard_service.dart';

/// Data export for `GET /account/export`.
class AccountService {
  AccountService({required this.repository, Clock clock = systemClock}) : _clock = clock;

  final Repository repository;
  final Clock _clock;

  /// Everything stored about [user]. Other users appear only as the opaque id
  /// the user already holds, never with their email, phone, or profile.
  Future<Map<String, Object?>> export(User user) async {
    final contacts = await repository.contactsOf(user.id);
    final prefs = await repository.preferencesOf(user.id);
    final sessions = await repository.listSessions(user.id);

    final names = <int, String>{for (final c in contacts) c.entryIndex: c.name};
    final entryOrder = names.keys.toList()..sort();

    return {
      'exportedAt': _clock().toIso8601String(),
      'profile': {
        ...profileJson(user),
        'currentLocation': user.currentLocation,
        'createdAt': user.createdAt.toUtc().toIso8601String(),
        'lastActiveAt': user.lastActiveAt?.toUtc().toIso8601String(),
      },
      'contacts': [
        for (final index in entryOrder)
          {
            'name': names[index],
            'identifiersImported': contacts.where((c) => c.entryIndex == index).length,
          },
      ],
      'preferences': [
        for (final entry in prefs.entries) {'contactId': entry.key, 'preference': entry.value},
      ],
      'sessions': [
        for (final session in sessions)
          {
            'deviceLabel': session.deviceLabel,
            'createdAt': session.createdAt.toUtc().toIso8601String(),
          },
      ],
    };
  }
}
