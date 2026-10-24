import 'package:shelf_router/shelf_router.dart';

import '../app_context.dart';
import '../middleware/auth.dart';
import '../middleware/request_context.dart';
import 'helpers.dart';

void registerAccountRoutes(Router router, AppContext ctx) {
  router.get('/v1/account/export', authenticated(ctx, (request, auth) async {
    return jsonResponse(await ctx.account.export(auth.user));
  }));

  router.delete('/v1/account', authenticated(ctx, (request, auth) async {
    final body = await readJson(request);
    final password = body.string('password', maxLength: 1024, trim: false);
    await ctx.auth.deleteAccount(auth.user, password);
    ctx.logger.info('account deleted', {'userId': auth.user.id});
    return ok();
  }));
}
