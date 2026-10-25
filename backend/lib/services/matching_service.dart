import '../auth/tokens.dart';
import '../db/repository.dart';
import '../errors.dart';
import '../models.dart';
import '../validation.dart';

/// An address-book contact that is also a (verified) user of the app.
class MatchedContact {
  const MatchedContact({required this.user, required this.name, required this.mutual});

  final User user;

  /// The name from the *viewer's* address book, never the other user's profile.
  final String name;
  final bool mutual;
}

class MatchResult {
  const MatchResult({required this.matched, required this.notOnApp, required this.imported});

  /// Mutual matches first, then one-way, each sorted by name.
  final List<MatchedContact> matched;
  final List<String> notOnApp;
  final bool imported;

  Iterable<MatchedContact> get mutual => matched.where((m) => m.mutual);
  Iterable<MatchedContact> get oneWay => matched.where((m) => !m.mutual);

  static const MatchResult empty = MatchResult(matched: [], notOnApp: [], imported: false);
}

const int maxImportContacts = 5000;
const int maxIdentifiersPerContact = 20;

/// Contact import and match computation. Matches are recomputed on every read,
/// so a user who verifies later shows up without any background job.
class MatchingService {
  MatchingService({required this.repository, required this.hmacs});

  final Repository repository;
  final Hmacs hmacs;

  /// Replaces the viewer's imported address book with [rawContacts].
  /// Each entry is `{name, phones: [string], emails: [string]}`; identifiers
  /// that do not normalize are skipped. Only HMACs and display names are stored.
  Future<void> importContacts(User viewer, List<Object?> rawContacts) async {
    if (rawContacts.length > maxImportContacts) {
      throw ApiException.validation('At most $maxImportContacts contacts can be imported.');
    }
    final records = <ContactRecord>[];
    final seen = <String>{};
    var entryIndex = 0;
    for (final raw in rawContacts) {
      if (raw is! Map) throw ApiException.validation('Each contact must be an object.');
      final fields = JsonFields(Map<String, Object?>.from(raw));
      final name = fields.optString('name', maxLength: 200) ?? '';
      final phones = _stringList(fields, 'phones');
      final emails = _stringList(fields, 'emails');
      if (name.isEmpty) continue;

      final hashes = <(IdentifierKind, String)>[
        for (final phone in phones)
          if (normalizePhone(phone) case final normalized?) (IdentifierKind.phone, hmacs.phone(normalized)),
        for (final email in emails)
          if (normalizeEmail(email) case final normalized?) (IdentifierKind.email, hmacs.email(normalized)),
      ];
      var added = false;
      for (final (kind, hash) in hashes) {
        if (!seen.add(hash)) continue;
        records.add(ContactRecord(entryIndex: entryIndex, name: name, kind: kind, identifierHash: hash));
        added = true;
      }
      if (added) entryIndex++;
    }
    await repository.replaceContacts(viewer.id, records);
  }

  List<String> _stringList(JsonFields fields, String key) {
    final list = fields.optList(key, maxItems: maxIdentifiersPerContact) ?? const <Object?>[];
    return [
      for (final item in list)
        if (item is String) item else throw ApiException.validation('"$key" must contain only strings.'),
    ];
  }

  Future<MatchResult> compute(User viewer) async {
    final contacts = await repository.contactsOf(viewer.id);
    if (contacts.isEmpty) return MatchResult.empty;

    final allHashes = {for (final c in contacts) c.identifierHash};
    final found = await repository.findVerifiedUsersByHashes(allHashes, excludeUserId: viewer.id);

    final ownHashes = {viewer.phoneHash, viewer.emailHash};
    final usersByHash = <String, List<User>>{};
    for (final match in found) {
      usersByHash.putIfAbsent(match.identifierHash, () => []).add(match.user);
    }

    // Group identifiers back into address-book entries.
    final entries = <int, List<ContactRecord>>{};
    for (final contact in contacts) {
      entries.putIfAbsent(contact.entryIndex, () => []).add(contact);
    }

    final nameByUser = <String, String>{};
    final userById = <String, User>{};
    final notOnApp = <String>[];
    for (final index in entries.keys.toList()..sort()) {
      final entry = entries[index]!;
      if (entry.any((c) => ownHashes.contains(c.identifierHash))) continue; // the viewer's own card
      var matchedAny = false;
      for (final contact in entry) {
        for (final user in usersByHash[contact.identifierHash] ?? const <User>[]) {
          matchedAny = true;
          userById[user.id] = user;
          nameByUser.putIfAbsent(user.id, () => contact.name);
        }
      }
      if (!matchedAny) notOnApp.add(entry.first.name);
    }

    // Mutual: the matched user has imported a verified identifier of the viewer.
    final viewerHashes = <String>{
      if (viewer.phoneVerified) viewer.phoneHash,
      if (viewer.emailVerified) viewer.emailHash,
    };
    final holders = viewerHashes.isEmpty
        ? const <String>{}
        : await repository.usersHoldingAnyHash(userById.keys.toSet(), viewerHashes);

    final matched = [
      for (final user in userById.values)
        MatchedContact(user: user, name: nameByUser[user.id]!, mutual: holders.contains(user.id)),
    ]..sort((a, b) {
        if (a.mutual != b.mutual) return a.mutual ? -1 : 1;
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.user.id.compareTo(b.user.id);
      });
    notOnApp.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return MatchResult(matched: matched, notOnApp: notOnApp, imported: true);
  }

  /// Stores the viewer's private preference about [targetUserId]. Only users
  /// that are already in the viewer's address book can be addressed, so this
  /// cannot be used to probe whether an arbitrary id exists.
  Future<void> setPreference(User viewer, String targetUserId, String preference) async {
    final result = await compute(viewer);
    if (!result.matched.any((m) => m.user.id == targetUserId)) {
      throw ApiException.notFound('Contact not found.');
    }
    await repository.setPreference(viewer.id, targetUserId, preference);
  }
}
