import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import '../errors.dart';

const int defaultBodyLimit = 1024 * 1024;
const int importBodyLimit = 5 * 1024 * 1024;

/// Buffers request bodies up to a per-route cap and rejects larger ones with
/// 413 before they are parsed. Works for chunked uploads without a
/// Content-Length too, because the stream itself is counted.
Middleware bodyLimit({int defaultLimit = defaultBodyLimit, int importLimit = importBodyLimit}) {
  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'GET' || request.method == 'HEAD' || request.method == 'OPTIONS') {
        return inner(request);
      }
      final limit = request.url.path == 'v1/contacts/import' ? importLimit : defaultLimit;

      final declared = request.contentLength;
      if (declared != null && declared > limit) throw ApiException.payloadTooLarge();

      final builder = BytesBuilder(copy: false);
      await for (final chunk in request.read()) {
        builder.add(chunk);
        if (builder.length > limit) throw ApiException.payloadTooLarge();
      }
      return inner(request.change(body: builder.takeBytes()));
    };
  };
}
