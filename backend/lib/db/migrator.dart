import 'dart:io';

import 'package:postgres/postgres.dart';

import '../logging.dart';

/// Applies `NNN_name.sql` files from [directory] in order, once each, inside a
/// transaction. A Postgres advisory lock serializes concurrent starters.
class Migrator {
  Migrator(this._pool, this.directory, this._logger);

  final Pool<void> _pool;
  final String directory;
  final Logger _logger;

  static const int _lockKey = 7264819; // arbitrary, unique to this app

  Future<void> run() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      throw StateError('Migrations directory not found: ${dir.absolute.path}');
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'^\d+_.*\.sql$').hasMatch(f.uri.pathSegments.last))
        .toList()
      ..sort((a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last));

    await _pool.withConnection((connection) async {
      await connection.execute(Sql.named('SELECT pg_advisory_lock(@key)'), parameters: {'key': _lockKey});
      try {
        await connection.execute(
          'CREATE TABLE IF NOT EXISTS schema_migrations ('
          'version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())',
        );
        final applied = {
          for (final row in await connection.execute('SELECT version FROM schema_migrations')) row[0] as String,
        };
        for (final file in files) {
          final version = file.uri.pathSegments.last;
          if (applied.contains(version)) continue;
          _logger.info('applying migration', {'version': version});
          final sql = await file.readAsString();
          await connection.runTx((tx) async {
            await tx.execute(sql, queryMode: QueryMode.simple);
            await tx.execute(
              Sql.named('INSERT INTO schema_migrations (version) VALUES (@v)'),
              parameters: {'v': version},
            );
          });
        }
      } finally {
        await connection.execute(Sql.named('SELECT pg_advisory_unlock(@key)'), parameters: {'key': _lockKey});
      }
    });
  }
}
