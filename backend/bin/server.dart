import 'dart:async';
import 'dart:io';

import 'package:reconnect_backend/app.dart';
import 'package:reconnect_backend/config.dart';

Future<void> main() async {
  final AppConfig config;
  try {
    config = AppConfig.fromEnv(Platform.environment);
  } on ConfigException catch (error) {
    stderr.writeln(error.message);
    exit(78); // EX_CONFIG
  }

  final server = await startServer(config);

  final done = Completer<void>();
  var stopping = false;
  void stop(ProcessSignal signal) {
    if (stopping) return;
    stopping = true;
    stdout.writeln('{"level":"info","msg":"received ${signal.toString()}, shutting down"}');
    server.shutdown().whenComplete(done.complete);
  }

  ProcessSignal.sigint.watch().listen(stop);
  try {
    ProcessSignal.sigterm.watch().listen(stop);
  } on SignalException {
    // SIGTERM is not available on Windows.
  }

  await done.future;
  exit(0);
}
