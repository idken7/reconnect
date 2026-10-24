import 'dart:io';

import 'package:shelf/shelf.dart';

import '../app_context.dart';
import '../errors.dart';
import '../services/auth_service.dart';
import 'request_context.dart';

typedef AuthedHandler = Future<Response> Function(Request request, AuthContext auth);

/// Wraps [handler] so it only runs for a valid bearer access token, subject to
/// the per-user API rate limit.
Handler authenticated(AppContext ctx, AuthedHandler handler) {
  return (Request request) async {
    final header = request.headers[HttpHeaders.authorizationHeader];
    if (header == null || header.length < 8 || header.substring(0, 7).toLowerCase() != 'bearer ') {
      throw ApiException.missingBearer();
    }
    final token = header.substring(7).trim();
    if (token.isEmpty) throw ApiException.missingBearer();

    final auth = await ctx.auth.authenticate(token);
    requestInfo(request).userId = auth.user.id;
    ctx.limiter.enforce(
      'api-user',
      auth.user.id,
      limit: ctx.limits.apiPerUserPerMinute,
      window: const Duration(minutes: 1),
    );
    return handler(request, auth);
  };
}
