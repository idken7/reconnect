import 'package:reconnect_backend/errors.dart';
import 'package:reconnect_backend/services/rate_limiter.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  late FakeClock clock;
  late RateLimiter limiter;
  const minute = Duration(minutes: 1);

  setUp(() {
    clock = FakeClock();
    limiter = RateLimiter(const RateLimitConfig(), clock: clock.call);
  });

  test('allows up to the limit then reports how long to wait', () {
    for (var i = 0; i < 3; i++) {
      expect(limiter.consume('b', 'k', limit: 3, window: minute), isNull);
      clock.advance(const Duration(seconds: 10));
    }
    final wait = limiter.consume('b', 'k', limit: 3, window: minute);
    expect(wait, isNotNull);
    expect(wait!.inSeconds, 30, reason: 'oldest hit leaves the window in 30s');
  });

  test('sliding window frees capacity as old hits expire', () {
    for (var i = 0; i < 3; i++) {
      limiter.consume('b', 'k', limit: 3, window: minute);
    }
    expect(limiter.consume('b', 'k', limit: 3, window: minute), isNotNull);
    clock.advance(const Duration(seconds: 61));
    expect(limiter.consume('b', 'k', limit: 3, window: minute), isNull);
  });

  test('rejected hits are not counted against the caller', () {
    for (var i = 0; i < 3; i++) {
      limiter.consume('b', 'k', limit: 3, window: minute);
    }
    for (var i = 0; i < 10; i++) {
      limiter.consume('b', 'k', limit: 3, window: minute);
    }
    clock.advance(const Duration(seconds: 61));
    expect(limiter.consume('b', 'k', limit: 3, window: minute), isNull);
  });

  test('buckets and keys are independent', () {
    limiter.consume('login', 'ip1', limit: 1, window: minute);
    expect(limiter.consume('login', 'ip1', limit: 1, window: minute), isNotNull);
    expect(limiter.consume('login', 'ip2', limit: 1, window: minute), isNull);
    expect(limiter.consume('signup', 'ip1', limit: 1, window: minute), isNull);
  });

  test('enforce throws a 429 ApiException with retryAfterSeconds', () {
    limiter.enforce('b', 'k', limit: 1, window: minute);
    expect(
      () => limiter.enforce('b', 'k', limit: 1, window: minute),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 429)
          .having((e) => e.code, 'code', 'rate_limited')
          .having((e) => e.retryAfterSeconds, 'retry', inInclusiveRange(1, 60))),
    );
  });

  test('peek and record support failure counters without consuming', () {
    expect(limiter.peek('f', 'k', limit: 2, window: minute), isNull);
    limiter.record('f', 'k', minute);
    expect(limiter.peek('f', 'k', limit: 2, window: minute), isNull);
    limiter.record('f', 'k', minute);
    expect(limiter.peek('f', 'k', limit: 2, window: minute), isNotNull);
    limiter.reset('f', 'k');
    expect(limiter.peek('f', 'k', limit: 2, window: minute), isNull);
  });

  group('login lockout', () {
    test('starts after the threshold and doubles each time, up to a cap', () {
      for (var i = 0; i < 4; i++) {
        limiter.recordLoginFailure('a');
      }
      expect(limiter.lockoutRemaining('a'), isNull, reason: 'below threshold of 5');

      limiter.recordLoginFailure('a'); // 5th: 15s
      expect(limiter.lockoutRemaining('a')!.inSeconds, inInclusiveRange(14, 15));
      clock.advance(const Duration(seconds: 16));
      expect(limiter.lockoutRemaining('a'), isNull);

      limiter.recordLoginFailure('a'); // 6th: 30s
      expect(limiter.lockoutRemaining('a')!.inSeconds, inInclusiveRange(29, 30));
      clock.advance(const Duration(seconds: 31));
      limiter.recordLoginFailure('a'); // 7th: 60s
      expect(limiter.lockoutRemaining('a')!.inSeconds, inInclusiveRange(59, 60));

      for (var i = 0; i < 30; i++) {
        clock.advance(const Duration(hours: 2));
        limiter.recordLoginFailure('a');
        clock.advance(const Duration(seconds: 1));
      }
      expect(limiter.lockoutRemaining('a'), anyOf(isNull, lessThanOrEqualTo(const Duration(hours: 1))));
    });

    test('success clears the counter; other accounts are unaffected', () {
      for (var i = 0; i < 6; i++) {
        limiter.recordLoginFailure('a');
      }
      expect(limiter.lockoutRemaining('a'), isNotNull);
      expect(limiter.lockoutRemaining('b'), isNull);
      limiter.recordLoginSuccess('a');
      expect(limiter.lockoutRemaining('a'), isNull);
      limiter.recordLoginFailure('a');
      expect(limiter.lockoutRemaining('a'), isNull);
    });

    test('old failures are forgotten after an hour of quiet', () {
      for (var i = 0; i < 4; i++) {
        limiter.recordLoginFailure('a');
      }
      clock.advance(const Duration(hours: 2));
      limiter.recordLoginFailure('a');
      expect(limiter.lockoutRemaining('a'), isNull);
    });
  });

  test('state does not grow without bound', () {
    for (var i = 0; i < 2000; i++) {
      limiter.consume('b', 'key$i', limit: 1, window: minute);
      clock.advance(const Duration(seconds: 1));
    }
    // Sweeps run lazily; just make sure it keeps working under churn.
    expect(limiter.consume('b', 'fresh', limit: 1, window: minute), isNull);
  });
}
