import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reconnect_backend/app.dart';
import 'package:reconnect_backend/auth/tokens.dart';
import 'package:reconnect_backend/config.dart';
import 'package:reconnect_backend/db/memory_repository.dart';
import 'package:reconnect_backend/errors.dart';
import 'package:reconnect_backend/models.dart';
import 'package:reconnect_backend/services/verification_provider.dart';
import 'package:reconnect_backend/services/verification_service.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  group('VerificationService with a local provider', () {
    late MemoryRepository repo;
    late FakeClock clock;
    late RecordingProvider provider;
    late VerificationService service;

    setUp(() {
      repo = MemoryRepository();
      clock = FakeClock();
      provider = RecordingProvider();
      service = VerificationService(
        repository: repo,
        provider: provider,
        hmacs: Hmacs(testPepper),
        config: testConfig(),
        clock: clock.call,
      );
    });

    test('issues 6 digit codes, stores only an HMAC, expires after 10 minutes', () async {
      await service.send(VerificationPurpose.phoneVerify, '+14155550100');
      final code = provider.sent.single.code;
      expect(code, matches(RegExp(r'^\d{6}$')));
      expect(provider.sent.single.channel, VerificationChannel.sms);

      final stored = (await repo.findVerificationCode(VerificationPurpose.phoneVerify, '+14155550100'))!;
      expect(stored.codeHash, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(stored.codeHash, isNot(contains(code)));
      expect(stored.expiresAt, clock.now.add(const Duration(minutes: 10)));

      clock.advance(const Duration(minutes: 9, seconds: 59));
      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', code), isTrue);
    });

    test('codes are single use and tied to purpose and target', () async {
      await service.send(VerificationPurpose.emailVerify, 'a@example.test');
      final code = provider.sent.single.code;
      expect(provider.sent.single.channel, VerificationChannel.email);
      expect(await service.check(VerificationPurpose.passwordReset, 'a@example.test', code), isFalse);
      expect(await service.check(VerificationPurpose.emailVerify, 'b@example.test', code), isFalse);
      expect(await service.check(VerificationPurpose.emailVerify, 'a@example.test', code), isTrue);
      expect(await service.check(VerificationPurpose.emailVerify, 'a@example.test', code), isFalse, reason: 'consumed');
    });

    test('a new code replaces the old one', () async {
      await service.send(VerificationPurpose.phoneVerify, '+14155550100');
      final first = provider.sent.last.code;
      await service.send(VerificationPurpose.phoneVerify, '+14155550100');
      final second = provider.sent.last.code;
      if (first != second) {
        expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', first), isFalse);
      }
      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', second), isTrue);
    });

    test('expires after the TTL', () async {
      await service.send(VerificationPurpose.phoneVerify, '+14155550100');
      clock.advance(const Duration(minutes: 10, seconds: 1));
      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', provider.sent.single.code), isFalse);
    });

    test('limits wrong guesses per code', () async {
      await service.send(VerificationPurpose.phoneVerify, '+14155550100');
      final real = provider.sent.single.code;
      final wrong = real == '135790' ? '246801' : '135790';
      for (var i = 0; i < 5; i++) {
        expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', wrong), isFalse);
      }
      expect(
        () => service.check(VerificationPurpose.phoneVerify, '+14155550100', real),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'validation_error')),
      );
    });

    test('000000 is accepted outside production without a stored code', () async {
      expect(service.allowTestCode, isTrue);
      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', '000000'), isTrue);
    });

    test('000000 is refused in production', () async {
      final prod = VerificationService(
        repository: repo,
        provider: provider,
        hmacs: Hmacs(testPepper),
        config: testConfig(env: AppEnv.production),
        clock: clock.call,
      );
      expect(prod.allowTestCode, isFalse);
      await prod.send(VerificationPurpose.phoneVerify, '+14155550100');
      expect(await prod.check(VerificationPurpose.phoneVerify, '+14155550100', '000000'), isFalse);
      expect(await prod.check(VerificationPurpose.phoneVerify, '+14155550101', '000000'), isFalse);
    });
  });

  group('TwilioVerifyProvider with a fake HTTP client', () {
    final requests = <http.Request>[];

    TwilioVerifyProvider providerFor(http.Response Function(http.Request) respond) {
      requests.clear();
      return TwilioVerifyProvider(
        accountSid: 'ACtest',
        authToken: 'secret-token',
        serviceSid: 'VAtest',
        client: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      );
    }

    test('send posts To/Channel to the Verifications endpoint with basic auth', () async {
      final provider = providerFor((_) => http.Response('{"status":"pending"}', 201));
      await provider.send(channel: VerificationChannel.sms, to: '+14155550100', code: 'ignored');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://verify.twilio.com/v2/Services/VAtest/Verifications');
      expect(request.bodyFields, {'To': '+14155550100', 'Channel': 'sms'});
      expect(request.headers['authorization'], 'Basic ${base64.encode(utf8.encode('ACtest:secret-token'))}');
      expect(request.body, isNot(contains('ignored')), reason: 'Twilio generates its own code');
    });

    test('email uses the email channel', () async {
      final provider = providerFor((_) => http.Response('{}', 201));
      await provider.send(channel: VerificationChannel.email, to: 'a@example.test', code: 'x');
      expect(requests.single.bodyFields, {'To': 'a@example.test', 'Channel': 'email'});
    });

    test('check returns true only for approved', () async {
      var body = '{"status":"approved"}';
      final provider = providerFor((_) => http.Response(body, 200));
      expect(await provider.check(channel: VerificationChannel.sms, to: '+14155550100', code: '123456'), isTrue);
      expect(requests.single.url.path, '/v2/Services/VAtest/VerificationCheck');
      expect(requests.single.bodyFields, {'To': '+14155550100', 'Code': '123456'});
      body = '{"status":"pending"}';
      expect(await provider.check(channel: VerificationChannel.sms, to: '+14155550100', code: '123456'), isFalse);
    });

    test('a 404 from Twilio means no pending verification', () async {
      final provider = providerFor((_) => http.Response('{"code":20404}', 404));
      expect(await provider.check(channel: VerificationChannel.sms, to: '+14155550100', code: '123456'), isFalse);
    });

    test('server errors and network failures surface as delivery exceptions', () async {
      final failing = providerFor((_) => http.Response('oops', 500));
      await expectLater(
        failing.send(channel: VerificationChannel.sms, to: '+14155550100', code: 'x'),
        throwsA(isA<VerificationDeliveryException>()),
      );
      await expectLater(
        failing.check(channel: VerificationChannel.sms, to: '+14155550100', code: '123456'),
        throwsA(isA<VerificationDeliveryException>()),
      );
      final offline = TwilioVerifyProvider(
        accountSid: 'AC',
        authToken: 't',
        serviceSid: 'VA',
        client: MockClient((_) async => throw http.ClientException('connection refused')),
      );
      await expectLater(
        offline.send(channel: VerificationChannel.sms, to: '+14155550100', code: 'x'),
        throwsA(isA<VerificationDeliveryException>()),
      );
      final garbage = providerFor((_) => http.Response('<html>', 200));
      await expectLater(
        garbage.check(channel: VerificationChannel.sms, to: '+14155550100', code: '123456'),
        throwsA(isA<VerificationDeliveryException>()),
      );
    });

    test('VerificationService delegates code checking to a hosted provider', () async {
      final repo = MemoryRepository();
      final clock = FakeClock();
      final twilio = providerFor((request) {
        if (request.url.path.endsWith('Verifications')) return http.Response('{"status":"pending"}', 201);
        final ok = request.bodyFields['Code'] == '424242';
        return http.Response(jsonEncode({'status': ok ? 'approved' : 'pending'}), 200);
      });
      final service = VerificationService(
        repository: repo,
        provider: twilio,
        hmacs: Hmacs(testPepper),
        config: testConfig(provider: VerificationProviderKind.twilio),
        clock: clock.call,
      );
      expect(service.allowTestCode, isFalse);
      await service.send(VerificationPurpose.phoneVerify, '+14155550100');
      final stored = (await repo.findVerificationCode(VerificationPurpose.phoneVerify, '+14155550100'))!;
      expect(stored.codeHash, isNull, reason: 'Twilio holds the code');

      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', '000000'), isFalse);
      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', '111111'), isFalse);
      expect(await service.check(VerificationPurpose.phoneVerify, '+14155550100', '424242'), isTrue);
    });

    test('route-level: a delivery outage on send becomes a 503, not a 500', () async {
      final broken = TestApp(MemoryRepository(), providerOverride: _FailingProvider());
      final user = await broken.signUp(1); // signup still succeeds: delivery is best effort
      final r = await broken.post('/v1/auth/verify/phone/send', {}, token: user.access);
      expect(r.status, 503);
      expect(r.code, 'delivery_unavailable');
      final reset = await broken.post('/v1/auth/password-reset/request', {'email': user.email});
      expect(reset.status, 200, reason: 'reset request never reveals delivery problems');
      expect(broken.logs.join('\n'), contains('verification delivery failed'));
    });
  });

  test('buildVerificationProvider wires the configured provider', () {
    final client = MockClient((_) async => http.Response('{}', 200));
    expect(buildVerificationProvider(testConfig(), client), isA<ConsoleVerificationProvider>());
    final twilio = AppConfig(
      pepper: testPepper,
      verificationProvider: VerificationProviderKind.twilio,
      twilio: const TwilioConfig(accountSid: 'AC', authToken: 't', verifyServiceSid: 'VA'),
    );
    expect(buildVerificationProvider(twilio, client), isA<TwilioVerifyProvider>());
  });
}

class _FailingProvider extends ConsoleVerificationProvider {
  _FailingProvider() : super(sink: (_) {});

  @override
  Future<void> send({required VerificationChannel channel, required String to, required String code}) async {
    throw VerificationDeliveryException('down');
  }
}
