import 'package:reconnect_backend/db/memory_repository.dart';

import 'support/api_suite.dart';

void main() {
  defineApiSuite('memory', () async => MemoryRepository());
}
