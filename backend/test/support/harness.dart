import 'dart:convert';

import 'package:reconnect_backend/app.dart';
import 'package:reconnect_backend/app_context.dart';
import 'package:reconnect_backend/auth/password_hasher.dart';
import 'package:reconnect_backend/config.dart';
import 'package:reconnect_backend/db/repository.dart';
import 'package:reconnect_backend/logging.dart';
import 'package:reconnect_backend/services/rate_limiter.dart';
import 'package:reconnect_backend/services/verification_provider.dart';
import 'package:shelf/shelf.dart';

const String testPepper = 'test-pepper-test-pepper-test-pepper-0123456789';
const String strongPassword = 'correct horse battery staple';

AppConfig testConfig({
  AppEnv env = AppEnv.test,
  List<String> allowedOrigins = const ['https://app.example.test'],
  Duration accessTokenTtl = const Duration(minutes: 15),
  Duration refreshTokenTtl = const Duration(days: 30),
  VerificationProviderKind provider = VerificationProviderKind.console,
}) {
  return AppConfig(
    env: env,
    pepper: testPepper,
    allowedOrigins: allowedOrigins,
    accessTokenTtl: accessTokenTtl,
    refreshTokenTtl: refreshTokenTtl,
    verificationProvider: provider,
    trustProxy: true,
  );
}

class FakeClock {
  FakeClock([DateTime? start]) : now = start ?? DateTime.utc(2026, 1, 1, 12);
  DateTime now;
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

/// Console provider that remembers what it "sent".
class RecordingProvider extends ConsoleVerificationProvider {
  RecordingProvider() : super(sink: (_) {});

  final List<({VerificationChannel channel, String to, String code})> sent = [];

  @override
  Future<void> send({required VerificationChannel channel, required String to, required String code}) async {
    sent.add((channel: channel, to: to, code: code));
  }

  String? lastCodeFor(String to) => sent.where((s) => s.to == to).map((s) => s.code).lastOrNull;
  int sendsTo(String to) => sent.where((s) => s.to == to).length;
}

class TestResponse {
  TestResponse(this.status, this.headers, this.raw);
  final int status;
  final Map<String, String> headers;
  final String raw;

  Map<String, dynamic> get json => raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
  String? get code => json['code'] as String?;
}

class SessionTokens {
  SessionTokens(this.access, this.refresh, this.email, this.phone, this.password);
  String access;
  String refresh;
  final String email;
  final String phone;
  final String password;
}

class TestApp {
  TestApp._(this.ctx, this.handler, this.provider, this.clock, this.logs);

  factory TestApp(
    Repository repository, {
    RateLimitConfig rateLimits = const RateLimitConfig.relaxed(),
    AppConfig? config,
    FakeClock? clock,
    PasswordHasher? hasher,
    VerificationProvider? providerOverride,
  }) {
    final fake = clock ?? FakeClock();
    final provider = RecordingProvider();
    final logs = <String>[];
    final ctx = AppContext(
      config: config ?? testConfig(),
      repository: repository,
      verificationProvider: providerOverride ?? provider,
      logger: Logger(level: LogLevel.debug, sink: logs.add),
      rateLimits: rateLimits,
      hasher: hasher ?? PasswordHasher(params: Argon2Params.fast),
      clock: fake.call,
    );
    return TestApp._(ctx, buildHandler(ctx), provider, fake, logs);
  }

  final AppContext ctx;
  final Handler handler;
  final RecordingProvider provider;
  final FakeClock clock;
  final List<String> logs;

  /// Sends a request through the full middleware pipeline.
  Future<TestResponse> call(
    String method,
    String path, {
    Object? body,
    String? rawBody,
    String? token,
    Map<String, String> headers = const {},
    String ip = '10.0.0.1',
  }) async {
    final allHeaders = <String, String>{
      'x-forwarded-for': ip,
      if (body != null || rawBody != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
      ...headers,
    };
    final request = Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: allHeaders,
      body: rawBody ?? (body == null ? null : jsonEncode(body)),
    );
    final response = await handler(request);
    final text = await response.readAsString();
    await ctx.tasks.drain();
    return TestResponse(response.statusCode, response.headers, text);
  }

  Future<TestResponse> post(String path, Object? body, {String? token, String ip = '10.0.0.1'}) =>
      call('POST', path, body: body, token: token, ip: ip);
  Future<TestResponse> get(String path, {String? token}) => call('GET', path, token: token);
  Future<TestResponse> patch(String path, Object? body, {String? token}) =>
      call('PATCH', path, body: body, token: token);

  /// Unique, valid NANP phone number for test user [n].
  static String phoneFor(int n) => '+1415555${(1000 + n).toString().padLeft(4, '0')}';
  static String emailFor(int n) => 'user$n@example.test';

  /// Creates an account (phone NOT yet verified).
  Future<SessionTokens> signUp(int n, {String? password, String name = ''}) async {
    final pw = password ?? strongPassword;
    final response = await post('/v1/auth/signup', {
      'email': emailFor(n),
      'phone': phoneFor(n),
      'password': pw,
      'name': name.isEmpty ? 'User $n' : name,
      'homeCity': 'Brooklyn',
    });
    if (response.status != 200) throw StateError('signup failed: ${response.raw}');
    return SessionTokens(
      response.json['accessToken'] as String,
      response.json['refreshToken'] as String,
      emailFor(n),
      phoneFor(n),
      pw,
    );
  }

  Future<void> verifyPhone(SessionTokens s) async {
    final code = provider.lastCodeFor(s.phone)!;
    final response = await post('/v1/auth/verify/phone/confirm', {'code': code}, token: s.access);
    if (response.status != 200) throw StateError('verify failed: ${response.raw}');
  }

  Future<void> verifyEmail(SessionTokens s) async {
    final send = await post('/v1/auth/verify/email/send', {}, token: s.access);
    if (send.status != 200) throw StateError('email send failed: ${send.raw}');
    final code = provider.lastCodeFor(s.email)!;
    final response = await post('/v1/auth/verify/email/confirm', {'code': code}, token: s.access);
    if (response.status != 200) throw StateError('verify failed: ${response.raw}');
  }

  /// Signed up with a verified phone, ready to import contacts.
  Future<SessionTokens> verifiedUser(int n) async {
    final s = await signUp(n);
    await verifyPhone(s);
    return s;
  }

  Future<TestResponse> importContacts(SessionTokens s, List<Map<String, Object?>> contacts, {String? location}) =>
      post('/v1/contacts/import', {'contacts': contacts, 'location': ?location}, token: s.access);

  static Map<String, Object?> contact(String name, {List<String> phones = const [], List<String> emails = const []}) =>
      {'name': name, 'phones': phones, 'emails': emails};
}
