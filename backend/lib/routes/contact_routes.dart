import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../app_context.dart';
import '../errors.dart';
import '../middleware/auth.dart';
import '../middleware/request_context.dart';
import '../models.dart';
import '../services/matching_service.dart';
import '../validation.dart';
import 'helpers.dart';

String? _optionalLocation(String? value) {
  if (value == null || value.isEmpty) return null;
  if (!supportedLocations.contains(value)) {
    throw ApiException.validation('"location" must be one of ${supportedLocations.join(', ')}.');
  }
  return value;
}

void registerContactRoutes(Router router, AppContext ctx) {
  router.get('/v1/dashboard', authenticated(ctx, (request, auth) async {
    final location = _optionalLocation(request.url.queryParameters['location']?.trim());
    return jsonResponse(await ctx.dashboard.dashboard(auth.user, setLocation: location));
  }));

  router.post('/v1/contacts/import', authenticated(ctx, (request, auth) async {
    if (!auth.user.phoneVerified) throw ApiException.verificationRequired();
    final body = await readJson(request);
    final contacts = body.optList('contacts', maxItems: maxImportContacts);
    if (contacts == null) throw ApiException.validation('"contacts" is required.');
    final location = _optionalLocation(body.optString('location', maxLength: 80));
    await ctx.matching.importContacts(auth.user, contacts);
    return jsonResponse(await ctx.dashboard.dashboard(auth.user, setLocation: location));
  }));

  router.get('/v1/contacts/matches', authenticated(ctx, (request, auth) async {
    return jsonResponse(await ctx.dashboard.matches(auth.user));
  }));

  router.patch('/v1/contacts/<id>/preference', (Request outer, String id) {
    return authenticated(ctx, (request, auth) async {
      final body = await readJson(request);
      final preference = body.string('preference', maxLength: 32);
      if (!preferenceValues.contains(preference)) {
        throw ApiException.validation('"preference" must be one of ${preferenceValues.join(', ')}.');
      }
      await ctx.matching.setPreference(auth.user, id, preference);
      return jsonResponse(await ctx.dashboard.dashboard(auth.user));
    })(outer);
  });

  router.patch('/v1/location', authenticated(ctx, (request, auth) async {
    final body = await readJson(request);
    final resolved = ctx.dashboard.resolveLocation(
      location: body.optString('location', maxLength: 80, allowEmpty: false),
      latitude: body.optDouble('latitude'),
      longitude: body.optDouble('longitude'),
    );
    return jsonResponse(await ctx.dashboard.dashboard(auth.user, setLocation: resolved));
  }));

  router.patch('/v1/profile', authenticated(ctx, (request, auth) async {
    final body = await readJson(request);
    final image = body.optString('profileImageUrl', maxLength: 2048);
    await ctx.dashboard.updateProfile(
      auth.user,
      name: body.optString('name', maxLength: 100),
      bio: body.optString('bio', maxLength: 500),
      homeCity: body.optString('homeCity', maxLength: 80),
      profileImageUrl: image == null ? null : validateProfileImageUrl(image),
      locationShared: body.optBool('locationShared'),
    );
    return jsonResponse(await ctx.dashboard.dashboard(auth.user));
  }));
}
