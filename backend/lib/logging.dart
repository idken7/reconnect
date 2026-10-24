import 'dart:convert';
import 'dart:io';

enum LogLevel { debug, info, warn, error }

final RegExp _sensitiveKey = RegExp(
  r'pass|token|secret|authorization|cookie|pepper|api[-_]?key|code|email|phone|hash|contacts|bio|name',
  caseSensitive: false,
);
final RegExp _emailPattern = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
final RegExp _phonePattern = RegExp(r'\+?\d[\d\s().\-]{7,}\d');
final RegExp _bearerPattern = RegExp(r'Bearer\s+[A-Za-z0-9._~+/=\-]+', caseSensitive: false);

const String redacted = '[REDACTED]';

/// Scrubs emails, phone numbers and bearer tokens out of free text such as
/// exception messages.
String scrubText(String input) => input
    .replaceAll(_bearerPattern, 'Bearer $redacted')
    .replaceAll(_emailPattern, '[email]')
    .replaceAll(_phonePattern, '[phone]');

/// Recursively redacts values whose keys look sensitive and scrubs PII from
/// remaining strings.
Object? redact(Object? value, {String? key}) {
  if (key != null && _sensitiveKey.hasMatch(key)) return redacted;
  if (value is Map) {
    return <String, Object?>{for (final e in value.entries) '${e.key}': redact(e.value, key: '${e.key}')};
  }
  if (value is Iterable) return value.map((e) => redact(e)).toList();
  if (value is String) return scrubText(value);
  return value;
}

/// Structured JSON-lines logger. Every field passes through [redact].
class Logger {
  Logger({this.level = LogLevel.info, void Function(String line)? sink}) : _sink = sink ?? stdout.writeln;

  final LogLevel level;
  final void Function(String line) _sink;

  static LogLevel parseLevel(String raw) =>
      LogLevel.values.where((l) => l.name == raw).firstOrNull ?? LogLevel.info;

  void debug(String message, [Map<String, Object?> fields = const {}]) => _log(LogLevel.debug, message, fields);
  void info(String message, [Map<String, Object?> fields = const {}]) => _log(LogLevel.info, message, fields);
  void warn(String message, [Map<String, Object?> fields = const {}]) => _log(LogLevel.warn, message, fields);

  void error(String message, {Object? error, StackTrace? stack, Map<String, Object?> fields = const {}}) {
    _log(LogLevel.error, message, {
      ...fields,
      if (error != null) 'errorType': error.runtimeType.toString(),
      if (error != null) 'errorMessage': scrubText(error.toString()),
      if (stack != null) 'stack': scrubText(stack.toString()).split('\n').take(12).toList(),
    });
  }

  void _log(LogLevel at, String message, Map<String, Object?> fields) {
    if (at.index < level.index) return;
    final entry = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'level': at.name,
      'msg': scrubText(message),
      ...(redact(fields) as Map<String, Object?>),
    };
    try {
      _sink(jsonEncode(entry));
    } catch (_) {
      // Logging must never take the server down.
    }
  }
}
