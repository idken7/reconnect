// Runs the repository contract and the full API suite against a real Postgres.
// Skipped unless DATABASE_URL is set, e.g.
//   docker run --rm -d -p 55432:5432 -e POSTGRES_PASSWORD=pw -e POSTGRES_DB=reconnect_test postgres:16
//   DATABASE_URL=postgres://postgres:pw@localhost:55432/reconnect_test dart test test/postgres_test.dart
//
// The database is wiped between tests, so point it at a throwaway database.
import 'dart:io';

import 'package:reconnect_backend/db/postgres_repository.dart';
import 'package:reconnect_backend/db/repository.dart';
import 'package:test/test.dart';

import 'support/api_suite.dart';
import 'support/repository_contract.dart';

void main() {
  final url = Platform.environment['DATABASE_URL'];
  if (url == null || url.isEmpty) {
    test('Postgres integration (set DATABASE_URL to run)', () {}, skip: 'DATABASE_URL is not set');
    return;
  }

  late PostgresRepository shared;

  setUpAll(() async {
    shared = PostgresRepository(url, migrationsDir: 'migrations');
    await shared.init();
    await shared.init(); // migrations are idempotent
  });

  tearDownAll(() async => shared.close());

  Future<Repository> fresh() async {
    await shared.truncateAll();
    return shared;
  }

  test('migrations are recorded once', () async {
    expect(await shared.ping(), isTrue);
  });

  defineRepositoryContract('postgres', fresh);
  defineApiSuite('postgres', fresh);
}
