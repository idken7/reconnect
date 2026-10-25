import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../app_context.dart';
import '../errors.dart';
import '../middleware/request_context.dart';

void registerOpsRoutes(Router router, AppContext ctx) {
  router.get('/health', (Request request) => jsonResponse({'status': 'ok'}));

  router.get('/ready', (Request request) async {
    if (!await ctx.repository.ping()) {
      throw const ApiException(503, 'not_ready', 'Database is unreachable.');
    }
    return jsonResponse({'status': 'ok'});
  });
}
