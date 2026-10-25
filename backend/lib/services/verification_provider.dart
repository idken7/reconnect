import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum VerificationChannel { sms, email }

class VerificationDeliveryException implements Exception {
  VerificationDeliveryException(this.message);
  final String message;
  @override
  String toString() => 'VerificationDeliveryException: $message';
}

/// Delivers (and optionally checks) one-time codes.
///
/// Local providers receive the generated [code] in [send] and the service
/// checks it against a stored HMAC. Hosted providers such as Twilio Verify
/// generate and check the code themselves ([hostsCodes] is true).
abstract interface class VerificationProvider {
  bool get hostsCodes;

  Future<void> send({required VerificationChannel channel, required String to, required String code});

  /// Only called when [hostsCodes] is true.
  Future<bool> check({required VerificationChannel channel, required String to, required String code});
}

/// Development provider: prints the code. Never use in production.
class ConsoleVerificationProvider implements VerificationProvider {
  ConsoleVerificationProvider({void Function(String line)? sink}) : _sink = sink ?? stdout.writeln;

  final void Function(String line) _sink;

  @override
  bool get hostsCodes => false;

  @override
  Future<void> send({required VerificationChannel channel, required String to, required String code}) async {
    _sink('[dev verification] ${channel.name} to $to: code $code');
  }

  @override
  Future<bool> check({required VerificationChannel channel, required String to, required String code}) async =>
      false;
}

/// Twilio Verify. Phone uses the `sms` channel; email uses the `email` channel
/// (requires a Mailer configured on the Verify service in the Twilio console).
class TwilioVerifyProvider implements VerificationProvider {
  TwilioVerifyProvider({
    required this.accountSid,
    required this.authToken,
    required this.serviceSid,
    required http.Client client,
    Uri? baseUri,
  })  : _client = client,
        _base = baseUri ?? Uri.parse('https://verify.twilio.com/v2/Services/$serviceSid');

  final String accountSid;
  final String authToken;
  final String serviceSid;
  final http.Client _client;
  final Uri _base;

  @override
  bool get hostsCodes => true;

  Map<String, String> get _headers => {
        HttpHeaders.authorizationHeader: 'Basic ${base64.encode(utf8.encode('$accountSid:$authToken'))}',
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
        HttpHeaders.acceptHeader: 'application/json',
      };

  @override
  Future<void> send({required VerificationChannel channel, required String to, required String code}) async {
    final response = await _post('Verifications', {'To': to, 'Channel': channel.name});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VerificationDeliveryException('Twilio Verifications returned ${response.statusCode}');
    }
  }

  @override
  Future<bool> check({required VerificationChannel channel, required String to, required String code}) async {
    final response = await _post('VerificationCheck', {'To': to, 'Code': code});
    // 404: no pending verification (expired, already approved, or never sent).
    if (response.statusCode == 404) return false;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VerificationDeliveryException('Twilio VerificationCheck returned ${response.statusCode}');
    }
    final Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw VerificationDeliveryException('Twilio returned a non-JSON response');
    }
    return body is Map && body['status'] == 'approved';
  }

  Future<http.Response> _post(String path, Map<String, String> form) async {
    try {
      return await _client
          .post(Uri.parse('$_base/$path'), headers: _headers, body: form)
          .timeout(const Duration(seconds: 10));
    } on Exception catch (e) {
      throw VerificationDeliveryException('Twilio request failed: ${e.runtimeType}');
    }
  }
}
