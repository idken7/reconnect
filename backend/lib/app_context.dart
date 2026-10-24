import 'auth/password_hasher.dart';
import 'auth/tokens.dart';
import 'config.dart';
import 'db/repository.dart';
import 'logging.dart';
import 'services/account_service.dart';
import 'services/auth_service.dart';
import 'services/dashboard_service.dart';
import 'services/matching_service.dart';
import 'services/rate_limiter.dart';
import 'services/verification_provider.dart';
import 'services/verification_service.dart';
import 'util.dart';

/// Everything the HTTP layer needs, wired once at startup. Tests build their
/// own with an in-memory repository and a recording verification provider.
class AppContext {
  AppContext._({
    required this.config,
    required this.repository,
    required this.logger,
    required this.limiter,
    required this.tasks,
    required this.verification,
    required this.auth,
    required this.matching,
    required this.dashboard,
    required this.account,
    required this.clock,
  });

  factory AppContext({
    required AppConfig config,
    required Repository repository,
    required VerificationProvider verificationProvider,
    Logger? logger,
    RateLimitConfig rateLimits = const RateLimitConfig(),
    PasswordHasher? hasher,
    Clock clock = systemClock,
  }) {
    final log = logger ?? Logger(level: Logger.parseLevel(config.logLevel));
    final hmacs = Hmacs(config.pepper);
    final tasks = BackgroundTasks();
    final limiter = RateLimiter(rateLimits, clock: clock);
    final verification = VerificationService(
      repository: repository,
      provider: verificationProvider,
      hmacs: hmacs,
      config: config,
      clock: clock,
    );
    final matching = MatchingService(repository: repository, hmacs: hmacs);
    return AppContext._(
      config: config,
      repository: repository,
      logger: log,
      limiter: limiter,
      tasks: tasks,
      verification: verification,
      auth: AuthService(
        repository: repository,
        hasher: hasher ?? PasswordHasher(),
        hmacs: hmacs,
        verification: verification,
        limiter: limiter,
        config: config,
        tasks: tasks,
        logger: log,
        clock: clock,
      ),
      matching: matching,
      dashboard: DashboardService(repository: repository, matching: matching, clock: clock),
      account: AccountService(repository: repository, clock: clock),
      clock: clock,
    );
  }

  final AppConfig config;
  final Repository repository;
  final Logger logger;
  final RateLimiter limiter;
  final BackgroundTasks tasks;
  final VerificationService verification;
  final AuthService auth;
  final MatchingService matching;
  final DashboardService dashboard;
  final AccountService account;
  final Clock clock;

  RateLimitConfig get limits => limiter.config;
}
