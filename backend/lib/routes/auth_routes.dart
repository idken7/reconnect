import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../app_context.dart';
import '../middleware/auth.dart';
import '../middleware/request_context.dart';
import '../models.dart';
import '../services/dashboard_service.dart';
import '../validation.dart';
import 'helpers.dart';

const Duration _hour = Duration(hours: 1);

void registerAuthRoutes(Router router, AppContext ctx) {
  router.post('/v1/auth/signup', (Request request) async {
    ctx.limiter.enforce('signup-ip', ipOf(ctx, request), limit: ctx.limits.signupPerIpPerHour, window: _hour);
    final body = await readJson(request);
    final result = await ctx.auth.signUp(
      email: body.string('email', maxLength: 254),
      phone: body.string('phone', maxLength: 40),
      password: body.string('password', maxLength: 1024, trim: false),
      name: body.optString('name', maxLength: 100) ?? '',
      homeCity: body.optString('homeCity', maxLength: 80) ?? '',
      bio: body.optString('bio', maxLength: 500) ?? '',
    );
    return jsonResponse(sessionBody(result, profileJson(result.user)));
  });

  router.post('/v1/auth/login', (Request request) async {
    ctx.limiter.enforce('login-ip', ipOf(ctx, request), limit: ctx.limits.loginPerIpPerMinute, window: const Duration(minutes: 1));
    final body = await readJson(request);
    final result = await ctx.auth.login(
      email: body.string('email', maxLength: 254),
      password: body.string('password', maxLength: 1024, trim: false),
      deviceLabel: body.optString('deviceLabel', maxLength: 100) ?? '',
    );
    return jsonResponse(sessionBody(result, profileJson(result.user)));
  });

  router.post('/v1/auth/refresh', (Request request) async {
    final body = await readJson(request);
    final tokens = await ctx.auth.refresh(body.string('refreshToken', maxLength: 512));
    return jsonResponse(tokenBody(tokens));
  });

  router.post('/v1/auth/logout', authenticated(ctx, (request, auth) async {
    await ctx.auth.logout(auth);
    return ok();
  }));

  router.post('/v1/auth/logout-all', authenticated(ctx, (request, auth) async {
    await ctx.auth.logoutAll(auth);
    return ok();
  }));

  for (final kind in IdentifierKind.values) {
    router.post('/v1/auth/verify/${kind.name}/send', authenticated(ctx, (request, auth) async {
      final target = kind == IdentifierKind.phone ? auth.user.phone : auth.user.email;
      _enforceCodeSendLimits(ctx, request, target);
      await ctx.auth.sendVerification(auth.user, kind);
      return ok();
    }));

    router.post('/v1/auth/verify/${kind.name}/confirm', authenticated(ctx, (request, auth) async {
      final body = await readJson(request);
      final code = validateCode(body.optString('code', maxLength: 32));
      final user = await ctx.auth.confirmVerification(auth.user, kind, code);
      return jsonResponse({'profile': profileJson(user)});
    }));
  }

  router.post('/v1/auth/password-reset/request', (Request request) async {
    final body = await readJson(request);
    final email = body.string('email', maxLength: 254);
    _enforceCodeSendLimits(ctx, request, normalizeEmail(email) ?? email.toLowerCase());
    await ctx.auth.requestPasswordReset(email);
    return ok();
  });

  router.post('/v1/auth/password-reset/confirm', (Request request) async {
    ctx.limiter.enforce('reset-confirm-ip', ipOf(ctx, request), limit: ctx.limits.otpPerIpPerHour, window: _hour);
    final body = await readJson(request);
    await ctx.auth.confirmPasswordReset(
      email: body.string('email', maxLength: 254),
      code: validateCode(body.optString('code', maxLength: 32)),
      newPassword: body.string('newPassword', maxLength: 1024, trim: false),
    );
    return ok();
  });
}

/// OTP sends are limited per destination (3/hour) and per IP.
void _enforceCodeSendLimits(AppContext ctx, Request request, String target) {
  ctx.limiter.enforce('otp-target', target, limit: ctx.limits.otpPerTargetPerHour, window: _hour);
  ctx.limiter.enforce('otp-ip', ipOf(ctx, request), limit: ctx.limits.otpPerIpPerHour, window: _hour);
}
