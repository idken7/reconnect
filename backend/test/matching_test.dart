import 'package:reconnect_backend/auth/tokens.dart';
import 'package:reconnect_backend/db/memory_repository.dart';
import 'package:reconnect_backend/errors.dart';
import 'package:reconnect_backend/models.dart';
import 'package:reconnect_backend/services/matching_service.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late MemoryRepository repo;
  late MatchingService matching;
  final hmacs = Hmacs(testPepper);
  var counter = 0;

  Future<User> addUser(
    String name, {
    required String phone,
    required String email,
    bool phoneVerified = true,
    bool emailVerified = false,
  }) async {
    final user = User(
      id: 'u_${name.toLowerCase()}${counter++}',
      email: email,
      emailHash: hmacs.email(email),
      emailVerifiedAt: emailVerified ? DateTime.utc(2026) : null,
      phone: phone,
      phoneHash: hmacs.phone(phone),
      phoneVerifiedAt: phoneVerified ? DateTime.utc(2026) : null,
      passwordHash: 'x',
      name: name,
      createdAt: DateTime.utc(2026),
    );
    await repo.createUser(user);
    return user;
  }

  setUp(() {
    repo = MemoryRepository();
    matching = MatchingService(repository: repo, hmacs: hmacs);
  });

  Map<String, Object?> entry(String name, {List<Object?> phones = const [], List<Object?> emails = const []}) =>
      {'name': name, 'phones': phones, 'emails': emails};

  test('different phone formats of the same number all match the same user', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    final target = await addUser('Target', phone: '+14155550111', email: 't@example.test');
    for (final format in ['415-555-0111', '(415) 555-0111', '+1 415 555 0111', '1.415.555.0111', '4155550111']) {
      await matching.importContacts(me, [entry('Someone', phones: [format])]);
      final result = await matching.compute(me);
      expect(result.matched.map((m) => m.user.id), [target.id], reason: format);
      expect(result.notOnApp, isEmpty, reason: format);
    }
  });

  test('email matching is case-insensitive and trims whitespace', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    final target = await addUser('Target', phone: '+14155550111', email: 'target@example.test', emailVerified: true);
    await matching.importContacts(me, [entry('T', emails: ['  TARGET@Example.Test '])]);
    expect((await matching.compute(me)).matched.single.user.id, target.id);
  });

  test('an entry matching two different users yields both, named from the address book', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    final one = await addUser('One', phone: '+14155550111', email: 'one@example.test');
    final two = await addUser('Two', phone: '+14155550122', email: 'two@example.test');
    await matching.importContacts(me, [entry('Combined card', phones: ['+14155550111', '+14155550122'])]);
    final result = await matching.compute(me);
    expect(result.matched.map((m) => m.user.id).toSet(), {one.id, two.id});
    expect(result.matched.map((m) => m.name), ['Combined card', 'Combined card']);
  });

  test('the same user reached via phone and email appears once', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    await addUser('Target', phone: '+14155550111', email: 'target@example.test', emailVerified: true);
    await matching.importContacts(me, [
      entry('Work', emails: ['target@example.test']),
      entry('Mobile', phones: ['415-555-0111']),
    ]);
    final result = await matching.compute(me);
    expect(result.matched, hasLength(1));
    expect(result.matched.single.name, 'Work', reason: 'first address-book entry wins');
  });

  test('unmatchable data is dropped instead of failing the import', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    await matching.importContacts(me, [
      entry('Junk numbers', phones: ['12', 'abc', '555-1234'], emails: ['nope']),
      entry('', phones: ['+14155550999']),
      entry('Real', phones: ['+14155550998']),
    ]);
    final stored = await repo.contactsOf(me.id);
    expect(stored.map((c) => c.name).toSet(), {'Real'});
    expect((await matching.compute(me)).notOnApp, ['Real']);
  });

  test('the viewer own card never shows up, even though their number is verified', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    await matching.importContacts(me, [entry('Myself', phones: ['+14155550100'])]);
    final result = await matching.compute(me);
    expect(result.matched, isEmpty);
    expect(result.notOnApp, isEmpty);
  });

  test('mutual / oneWay classification and ordering', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    final zed = await addUser('Zed', phone: '+14155550111', email: 'z@example.test');
    final amy = await addUser('Amy', phone: '+14155550122', email: 'a@example.test');
    final bob = await addUser('Bob', phone: '+14155550133', email: 'b@example.test');
    await matching.importContacts(me, [
      entry('Zed', phones: [zed.phone]),
      entry('amy', phones: [amy.phone]),
      entry('Bob', phones: [bob.phone]),
    ]);
    await matching.importContacts(zed, [entry('Me', phones: [me.phone])]);
    await matching.importContacts(bob, [entry('Me', phones: [me.phone])]);
    // Amy has someone else, not me.
    await matching.importContacts(amy, [entry('Other', phones: ['+14155550777'])]);

    final result = await matching.compute(me);
    expect(result.mutual.map((m) => m.name), ['Bob', 'Zed']);
    expect(result.oneWay.map((m) => m.name), ['amy']);
  });

  test('mutual requires the other side to have a VERIFIED identifier of the viewer', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test', phoneVerified: false);
    final them = await addUser('Them', phone: '+14155550111', email: 't@example.test');
    await matching.importContacts(me, [entry('Them', phones: [them.phone])]);
    await matching.importContacts(them, [entry('Me', phones: [me.phone])]);
    final result = await matching.compute(me);
    expect(result.mutual, isEmpty, reason: 'my phone is unverified, so being in their book proves nothing');
    expect(result.oneWay, hasLength(1));
  });

  test('a user with no verified identifier is never matchable', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    final ghost = await addUser('Ghost', phone: '+14155550111', email: 'g@example.test', phoneVerified: false);
    await matching.importContacts(me, [entry('Ghost', phones: [ghost.phone], emails: [ghost.email])]);
    final result = await matching.compute(me);
    expect(result.matched, isEmpty);
    expect(result.notOnApp, ['Ghost']);
  });

  test('preferences can only be set for contacts in the viewer address book', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    final friend = await addUser('Friend', phone: '+14155550111', email: 'f@example.test');
    final stranger = await addUser('Stranger', phone: '+14155550122', email: 's@example.test');
    await matching.importContacts(me, [entry('Friend', phones: [friend.phone])]);
    await matching.setPreference(me, friend.id, 'loveToSee');
    expect(await repo.preferencesOf(me.id), {friend.id: 'loveToSee'});
    await expectLater(
      matching.setPreference(me, stranger.id, 'loveToSee'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    expect(await repo.preferencesOf(me.id), {friend.id: 'loveToSee'});
  });

  test('import rejects bad shapes and too many contacts', () async {
    final me = await addUser('Me', phone: '+14155550100', email: 'me@example.test');
    Future<void> expectBad(List<Object?> contacts) => expectLater(
          matching.importContacts(me, contacts),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
        );
    await expectBad(['string']);
    await expectBad([
      {'name': 'x', 'phones': 'nope'},
    ]);
    await expectBad([
      {'name': 'x', 'emails': [1]},
    ]);
    await expectBad([
      {'name': 'x', 'phones': List.filled(21, '+14155550111')},
    ]);
    await expectBad(List.generate(maxImportContacts + 1, (i) => {'name': 'n$i'}));
  });
}
