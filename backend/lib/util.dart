import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

/// Injectable time source so expiry logic is testable.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now().toUtc();

final Random _secureRandom = Random.secure();

/// Cryptographically random bytes, base64url without padding.
String randomToken([int bytes = 32]) {
  final value = List<int>.generate(bytes, (_) => _secureRandom.nextInt(256));
  return base64UrlEncode(value).replaceAll('=', '');
}

/// Opaque random identifier with a short type prefix.
String newId(String prefix) => '${prefix}_${randomToken(15)}';

/// Compares two strings in time that depends only on their lengths.
bool constantTimeEquals(String a, String b) {
  final left = utf8.encode(a);
  final right = utf8.encode(b);
  var diff = left.length ^ right.length;
  final length = max(left.length, right.length);
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    diff |= l ^ r;
  }
  return diff == 0;
}

/// Tracks fire-and-forget work so it can be awaited in tests and on shutdown.
class BackgroundTasks {
  final Set<Future<void>> _pending = <Future<void>>{};

  void run(Future<void> Function() task, {void Function(Object error, StackTrace stack)? onError}) {
    late final Future<void> future;
    future = Future<void>.sync(task).catchError((Object error, StackTrace stack) {
      onError?.call(error, stack);
    }).whenComplete(() => _pending.remove(future));
    _pending.add(future);
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}

/// Limits how many futures run at once (used to bound CPU/memory heavy hashing).
class Semaphore {
  Semaphore(this.maxConcurrent);

  final int maxConcurrent;
  int _running = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<T> withPermit<T>(Future<T> Function() task) async {
    if (_running >= maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    } else {
      _running++;
    }
    try {
      return await task();
    } finally {
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }
}

/// Human readable relative time such as "2 weeks ago".
String timeSince(DateTime? then, DateTime now) {
  if (then == null) return 'Unknown';
  final diff = now.difference(then);
  if (diff.inSeconds < 60) return 'Just now';
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  if (diff.inMinutes < 60) return plural(diff.inMinutes, 'minute');
  if (diff.inHours < 24) return plural(diff.inHours, 'hour');
  if (diff.inDays < 14) return plural(diff.inDays, 'day');
  if (diff.inDays < 60) return plural(diff.inDays ~/ 7, 'week');
  if (diff.inDays < 730) return plural(diff.inDays ~/ 30, 'month');
  return plural(diff.inDays ~/ 365, 'year');
}
