import 'package:shelf/shelf.dart';

import '../app_context.dart';
import '../middleware/rate_limit.dart';
import '../middleware/request_context.dart';
import '../services/auth_service.dart';
import '../validation.dart';

/// Reads the (already size-limited) request body as a JSON object.
Future<JsonFields> readJson(Request request) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
  }
  return JsonFields(decodeJsonObject(bytes));
}

String ipOf(AppContext ctx, Request request) => clientIp(request, trustProxy: ctx.config.trustProxy);

Response ok() => jsonResponse({'ok': true});

Map<String, Object?> sessionBody(AuthResult result, Map<String, Object?> profile) => {
      ...tokenBody(result.tokens),
      'profile': profile,
    };

Map<String, Object?> tokenBody(IssuedTokens tokens) => {
      'accessToken': tokens.accessToken,
      'refreshToken': tokens.refreshToken,
      'accessTokenExpiresAt': tokens.accessExpiresAt.toUtc().toIso8601String(),
      'token': tokens.accessToken,
    };
