import 'dart:collection';
import 'dart:math';

import '../errors.dart';
import '../util.dart';

/// Tunable limits. Defaults follow the production readiness plan.
class RateLimitConfig {
  const RateLimitConfig({
    this.loginPerIpPerMinute = 5,
    this.loginFailuresPerAccountPerHour = 10,
    this.lockoutThreshold = 5,
    this.lockoutBase = const Duration(seconds: 15),
    this.lockoutMax = const Duration(hours: 1),
    this.signupPerIpPerHour = 5,
    this.otpPerTargetPerHour = 3,
    this.otpPerIpPerHour = 20,
    this.apiPerUserPerMinute = 120,
    this.apiPerIpPerMinute = 600,
  });

  /// Effectively unlimited, for tests that are not about throttling.
  const RateLimitConfig.relaxed()
      : loginPerIpPerMinute = 100000,
        loginFailuresPerAccountPerHour = 100000,
        lockoutThreshold = 100000,
        lockoutBase = const Duration(seconds: 1),
        lockoutMax = const Duration(seconds: 1),
        signupPerIpPerHour = 100000,
        otpPerTargetPerHour = 100000,
        otpPerIpPerHour = 100000,
        apiPerUserPerMinute = 100000,
        apiPerIpPerMinute = 100000;

  final int loginPerIpPerMinute;
  final int loginFailuresPerAccountPerHour;
  final int lockoutThreshold;
  final Duration lockoutBase;
  final Duration lockoutMax;
  final int signupPerIpPerHour;
  final int otpPerTargetPerHour;
  final int otpPerIpPerHour;
  final int apiPerUserPerMinute;
  final int apiPerIpPerMinute;
}

class _Lockout {
  int failures = 0;
  DateTime? lockedUntil;
  DateTime lastFailure = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// In-memory sliding-window limiter. Correct for a single instance; move the
/// state to Postgres or Redis before running more than one replica.
class RateLimiter {
  RateLimiter(this.config, {Clock clock = systemClock}) : _clock = clock;

  final RateLimitConfig config;
  final Clock _clock;
  final Map<String, ListQueue<DateTime>> _hits = {};
  final Map<String, Duration> _windows = {};
  final Map<String, _Lockout> _lockouts = {};
  int _calls = 0;

  /// Records a hit and throws a 429 if the limit for [bucket]/[key] is exceeded.
  void enforce(String bucket, String key, {required int limit, required Duration window}) {
    final retry = consume(bucket, key, limit: limit, window: window);
    if (retry != null) throw ApiException.rateLimited(_seconds(retry));
  }

  /// Records a hit; returns the time to wait when over [limit], otherwise null.
  Duration? consume(String bucket, String key, {required int limit, required Duration window}) {
    _maybeSweep();
    final id = '$bucket|$key';
    final now = _clock();
    final queue = _hits.putIfAbsent(id, ListQueue.new);
    _windows[id] = window;
    _evict(queue, now, window);
    if (queue.length >= limit) {
      return queue.first.add(window).difference(now);
    }
    queue.add(now);
    return null;
  }

  /// Number of hits currently inside the window (does not record a hit).
  int count(String bucket, String key, Duration window) {
    final queue = _hits['$bucket|$key'];
    if (queue == null) return 0;
    _evict(queue, _clock(), window);
    return queue.length;
  }

  /// Adds a hit without checking the limit (used for failure counters).
  void record(String bucket, String key, Duration window) {
    final id = '$bucket|$key';
    final queue = _hits.putIfAbsent(id, ListQueue.new);
    _windows[id] = window;
    queue.add(_clock());
  }

  /// Time until [bucket]/[key] has room again if already at [limit], without recording a hit.
  Duration? peek(String bucket, String key, {required int limit, required Duration window}) {
    final queue = _hits['$bucket|$key'];
    if (queue == null) return null;
    final now = _clock();
    _evict(queue, now, window);
    if (queue.length >= limit) return queue.first.add(window).difference(now);
    return null;
  }

  void reset(String bucket, String key) {
    _hits.remove('$bucket|$key');
    _windows.remove('$bucket|$key');
  }

  // ---- login lockout with exponential backoff ----

  /// Remaining lockout for [account], or null.
  Duration? lockoutRemaining(String account) {
    final lock = _lockouts[account];
    final until = lock?.lockedUntil;
    if (until == null) return null;
    final remaining = until.difference(_clock());
    return remaining.isNegative || remaining == Duration.zero ? null : remaining;
  }

  void recordLoginFailure(String account) {
    final now = _clock();
    final lock = _lockouts.putIfAbsent(account, _Lockout.new);
    if (now.difference(lock.lastFailure) > const Duration(hours: 1)) lock.failures = 0;
    lock.failures++;
    lock.lastFailure = now;
    final over = lock.failures - config.lockoutThreshold;
    if (over >= 0) {
      final factor = pow(2, min(over, 20)).toInt();
      final delay = config.lockoutBase * factor;
      lock.lockedUntil = now.add(delay > config.lockoutMax ? config.lockoutMax : delay);
    }
  }

  void recordLoginSuccess(String account) => _lockouts.remove(account);

  // ---- housekeeping ----

  void _evict(ListQueue<DateTime> queue, DateTime now, Duration window) {
    while (queue.isNotEmpty && now.difference(queue.first) >= window) {
      queue.removeFirst();
    }
  }

  void _maybeSweep() {
    if (++_calls % 500 != 0 && _hits.length < 50000) return;
    final now = _clock();
    _hits.removeWhere((id, queue) {
      _evict(queue, now, _windows[id] ?? const Duration(hours: 1));
      return queue.isEmpty;
    });
    _windows.removeWhere((id, _) => !_hits.containsKey(id));
    _lockouts.removeWhere((_, lock) =>
        now.difference(lock.lastFailure) > const Duration(hours: 2) && (lock.lockedUntil?.isBefore(now) ?? true));
  }

  static int _seconds(Duration d) => max(1, (d.inMilliseconds / 1000).ceil());
}
