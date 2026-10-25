import 'package:reconnect_backend/db/memory_repository.dart';

import 'support/repository_contract.dart';

void main() {
  defineRepositoryContract('memory', () async => MemoryRepository());
}
