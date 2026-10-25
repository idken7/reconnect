import 'package:shelf/shelf.dart';

/// CORS limited to [allowedOrigins]. Requests without an `Origin` header
/// (native apps) are unaffected; disallowed origins get no CORS headers, so
/// browsers block them.
Middleware cors(List<String> allowedOrigins) {
  final allowed = allowedOrigins.toSet();
  return (Handler inner) {
    return (Request request) async {
      final origin = request.headers['origin'];
      final permitted = origin != null && allowed.contains(origin);

      if (request.method == 'OPTIONS') {
        return Response(
          204,
          headers: {
            'vary': 'Origin',
            if (permitted) ...{
              'access-control-allow-origin': origin,
              'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
              'access-control-allow-headers': 'authorization, content-type',
              'access-control-max-age': '600',
            },
          },
        );
      }

      final response = await inner(request);
      if (!permitted) return response;
      return response.change(headers: {'access-control-allow-origin': origin, 'vary': 'Origin'});
    };
  };
}
