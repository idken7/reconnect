import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../errors.dart';
import '../logging.dart';
import '../util.dart';

/// Per-request mutable info shared between middleware and handlers.
class RequestInfo {
  RequestInfo(this.requestId);
  final String requestId;
  String? userId;
}

const String _infoKey = 'reconnect.requestInfo';

RequestInfo requestInfo(Request request) => request.context[_infoKey] as RequestInfo;

String requestId(Request request) => requestInfo(request).requestId;

const Map<String, String> _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response jsonResponse(Object? body, {int status = 200, Map<String, String>? headers}) {
  return Response(status, body: jsonEncode(body), headers: {..._jsonHeaders, ...?headers});
}

Response errorResponse(ApiException error, String id) {
  return jsonResponse(
    {
      'code': error.code,
      'error': error.message,
      'requestId': id,
      if (error.retryAfterSeconds != null) 'retryAfterSeconds': error.retryAfterSeconds,
    },
    status: error.statusCode,
    headers: {if (error.retryAfterSeconds != null) 'retry-after': '${error.retryAfterSeconds}'},
  );
}

/// Assigns a request id, converts every failure into the contract's error
/// shape (never leaking internals), and writes one structured log line.
Middleware requestContext(Logger logger, Clock clock) {
  return (Handler inner) {
    return (Request request) async {
      final info = RequestInfo(randomToken(9));
      final started = clock();
      final tracked = request.change(context: {_infoKey: info});

      Response response;
      Object? failure;
      StackTrace? failureStack;
      try {
        response = await inner(tracked);
      } on ApiException catch (error) {
        response = errorResponse(error, info.requestId);
      } on HijackException {
        rethrow;
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
        response = errorResponse(
          const ApiException(500, 'internal_error', 'Something went wrong. Please try again.'),
          info.requestId,
        );
      }

      // Responses produced by inner handlers (404 from the router etc.) have no
      // request id in the body; the header is always present.
      response = response.change(headers: {'x-request-id': info.requestId});

      final path = request.url.path;
      final isProbe = path == 'health' || path == 'ready';
      final fields = <String, Object?>{
        'requestId': info.requestId,
        'method': request.method,
        'path': '/$path',
        'status': response.statusCode,
        'latencyMs': clock().difference(started).inMilliseconds,
        if (info.userId != null) 'userId': info.userId,
      };
      if (failure != null) {
        logger.error('unhandled error', error: failure, stack: failureStack, fields: fields);
      } else if (!isProbe || response.statusCode >= 400) {
        logger.info('request', fields);
      }
      return response;
    };
  };
}

/// Router fallbacks in the contract's error shape.
Response notFoundHandler(Request request) =>
    throw ApiException.notFound('No such route.');
