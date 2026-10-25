import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'app_context.dart';
import 'config.dart';
import 'db/memory_repository.dart';
import 'db/postgres_repository.dart';
import 'db/repository.dart';
import 'logging.dart';
import 'middleware/body_limit.dart';
import 'middleware/cors.dart';
import 'middleware/rate_limit.dart';
import 'middleware/request_context.dart';
import 'middleware/security.dart';
import 'routes/account_routes.dart';
import 'routes/auth_routes.dart';
import 'routes/contact_routes.dart';
import 'routes/ops_routes.dart';
import 'services/verification_provider.dart';

/// The full middleware pipeline plus routes for [ctx].
Handler buildHandler(AppContext ctx) {
  final router = Router(notFoundHandler: notFoundHandler);
  registerOpsRoutes(router, ctx);
  registerAuthRoutes(router, ctx);
  registerAccountRoutes(router, ctx);
  registerContactRoutes(router, ctx);

  return const Pipeline()
      .addMiddleware(securityHeaders())
      .addMiddleware(requestContext(ctx.logger, ctx.clock))
      .addMiddleware(requireHttps(ctx.config))
      .addMiddleware(cors(ctx.config.allowedOrigins))
      .addMiddleware(ipRateLimit(ctx.limiter, trustProxy: ctx.config.trustProxy))
      .addMiddleware(bodyLimit())
      .addHandler(router.call);
}

VerificationProvider buildVerificationProvider(AppConfig config, http.Client client) {
  switch (config.verificationProvider) {
    case VerificationProviderKind.console:
      return ConsoleVerificationProvider();
    case VerificationProviderKind.twilio:
      final twilio = config.twilio!;
      return TwilioVerifyProvider(
        accountSid: twilio.accountSid,
        authToken: twilio.authToken,
        serviceSid: twilio.verifyServiceSid,
        client: client,
      );
  }
}

/// A running server and the resources that must be released on shutdown.
class RunningServer {
  RunningServer._(this.server, this.context, this._maintenance, this._client);

  final HttpServer server;
  final AppContext context;
  final Timer _maintenance;
  final http.Client _client;

  int get port => server.port;

  /// Stops accepting connections, waits briefly for in-flight requests, then
  /// releases the database pool and timers.
  Future<void> shutdown({Duration grace = const Duration(seconds: 10)}) async {
    _maintenance.cancel();
    final closing = server.close();
    try {
      await closing.timeout(grace);
    } on TimeoutException {
      await server.close(force: true);
    }
    await context.tasks.drain();
    _client.close();
    await context.repository.close();
  }
}

/// Builds dependencies from [config], runs migrations, and starts listening.
Future<RunningServer> startServer(AppConfig config, {Logger? logger, Repository? repository}) async {
  final log = logger ?? Logger(level: Logger.parseLevel(config.logLevel));
  final Repository repo;
  if (repository != null) {
    repo = repository;
  } else if (config.databaseUrl != null) {
    repo = PostgresRepository(config.databaseUrl!, migrationsDir: config.migrationsDir, logger: log);
  } else {
    log.warn('DATABASE_URL is not set: using the in-memory store. All data is lost on restart.');
    repo = MemoryRepository();
  }
  await repo.init();

  final client = http.Client();
  final ctx = AppContext(
    config: config,
    repository: repo,
    verificationProvider: buildVerificationProvider(config, client),
    logger: log,
  );

  Future<void> purge() async {
    try {
      // Keep expired rows for a week so clients still get `token_expired` / `refresh_token_expired`.
      final removed = await repo.purgeExpired(ctx.clock().subtract(const Duration(days: 7)));
      if (removed > 0) log.info('purged expired rows', {'removed': removed});
    } catch (error) {
      log.error('purge failed', error: error);
    }
  }

  unawaited(purge());
  final maintenance = Timer.periodic(const Duration(hours: 1), (_) => unawaited(purge()));

  final listener = await shelf_io.serve(buildHandler(ctx), config.host, config.port, poweredByHeader: null);
  listener.idleTimeout = const Duration(seconds: 30);
  log.info('listening', {
    'host': listener.address.host,
    'port': listener.port,
    'env': config.env.name,
    'storage': config.databaseUrl != null ? 'postgres' : 'memory',
    'verificationProvider': config.verificationProvider.name,
  });
  return RunningServer._(listener, ctx, maintenance, client);
}
