/// An error that maps to a specific HTTP response from the API contract.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message, {this.retryAfterSeconds});

  final int statusCode;
  final String code;
  final String message;
  final int? retryAfterSeconds;

  factory ApiException.validation(String message) => ApiException(400, 'validation_error', message);

  factory ApiException.payloadTooLarge() =>
      const ApiException(413, 'payload_too_large', 'Request body is too large.');

  factory ApiException.missingBearer() =>
      const ApiException(401, 'missing_bearer_token', 'Missing bearer token.');

  factory ApiException.invalidAccessToken() =>
      const ApiException(401, 'invalid_access_token', 'Access token is invalid.');

  factory ApiException.tokenExpired() => const ApiException(401, 'token_expired', 'Access token expired.');

  factory ApiException.invalidCredentials() =>
      const ApiException(401, 'invalid_credentials', 'Invalid email or password.');

  factory ApiException.invalidRefreshToken() =>
      const ApiException(401, 'invalid_refresh_token', 'Refresh token is invalid.');

  factory ApiException.refreshTokenExpired() =>
      const ApiException(401, 'refresh_token_expired', 'Refresh token expired. Please log in again.');

  factory ApiException.refreshTokenReused() => const ApiException(
        401,
        'refresh_token_reused',
        'Refresh token was already used. The session has been revoked.',
      );

  factory ApiException.verificationRequired() => const ApiException(
        403,
        'verification_required',
        'Verify your phone number before using this feature.',
      );

  factory ApiException.accountExists() =>
      const ApiException(409, 'account_exists', 'An account already exists for this email or phone.');

  factory ApiException.rateLimited(int retryAfterSeconds) => ApiException(
        429,
        'rate_limited',
        'Too many requests. Please try again later.',
        retryAfterSeconds: retryAfterSeconds,
      );

  factory ApiException.notFound([String what = 'Not found']) => ApiException(404, 'not_found', what);

  factory ApiException.methodNotAllowed() =>
      const ApiException(405, 'method_not_allowed', 'Method not allowed.');

  factory ApiException.deliveryUnavailable() => const ApiException(
        503,
        'delivery_unavailable',
        'Could not deliver the verification code right now. Please try again shortly.',
      );

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
