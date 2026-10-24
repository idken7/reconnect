import 'package:shelf/shelf.dart';

import '../config.dart';
import '../errors.dart';

/// Standard hardening headers on every response (including errors).
Middleware securityHeaders() {
  const headers = <String, String>{
    'x-content-type-options': 'nosniff',
    'x-frame-options': 'DENY',
    'referrer-policy': 'no-referrer',
    'strict-transport-security': 'max-age=63072000; includeSubDomains',
    'content-security-policy': "default-src 'none'; frame-ancestors 'none'",
    'cache-control': 'no-store',
    'cross-origin-resource-policy': 'same-site',
  };
  return (Handler inner) {
    return (Request request) async {
      final response = await inner(request);
      return response.change(headers: headers);
    };
  };
}

/// In production behind a TLS-terminating proxy, refuse plain-HTTP API calls.
/// Health probes are exempt because platforms hit them directly over HTTP.
Middleware requireHttps(AppConfig config) {
  return (Handler inner) {
    if (!config.isProduction || !config.trustProxy) return inner;
    return (Request request) {
      final path = request.url.path;
      final proto = request.headers['x-forwarded-proto'];
      if (proto != null && proto.toLowerCase() == 'http' && path != 'health' && path != 'ready') {
        throw const ApiException(400, 'https_required', 'HTTPS is required.');
      }
      return inner(request);
    };
  };
}
