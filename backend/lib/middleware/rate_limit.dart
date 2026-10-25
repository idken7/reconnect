import 'dart:io';

import 'package:shelf/shelf.dart';

import '../services/rate_limiter.dart';

/// Client IP for rate limiting. Proxy headers are honoured only when
/// [trustProxy] is set, i.e. when a proxy we control sits in front of us.
String clientIp(Request request, {required bool trustProxy}) {
  if (trustProxy) {
    final fly = request.headers['fly-client-ip']?.trim();
    if (fly != null && fly.isNotEmpty) return fly;
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.trim().isNotEmpty) {
      // The right-most entry is the one appended by our own proxy.
      return forwarded.split(',').last.trim();
    }
  }
  final connection = request.context['shelf.io.connection_info'];
  if (connection is HttpConnectionInfo) return connection.remoteAddress.address;
  return 'unknown';
}

/// Coarse per-IP limit applied to every request before routing.
Middleware ipRateLimit(RateLimiter limiter, {required bool trustProxy}) {
  return (Handler inner) {
    return (Request request) {
      final path = request.url.path;
      if (path != 'health' && path != 'ready' && request.method != 'OPTIONS') {
        limiter.enforce(
          'api-ip',
          clientIp(request, trustProxy: trustProxy),
          limit: limiter.config.apiPerIpPerMinute,
          window: const Duration(minutes: 1),
        );
      }
      return inner(request);
    };
  };
}
