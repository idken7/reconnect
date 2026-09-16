import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/services/conversation_starter_service.dart';

void main() {
  late ConversationStarterService service;

  setUp(() {
    service = ConversationStarterService();
  });

  group('getRandomStarter', () {
    test('returns a starter from the full catalog', () {
      final starter = service.getRandomStarter();
      expect(service.getAllStarters().map((s) => s.id), contains(starter.id));
    });
  });

  group('getAllStarters', () {
    test('returns every catalog entry and is safe to mutate', () {
      final starters = service.getAllStarters();
      expect(starters, isNotEmpty);

      starters.clear();

      expect(service.getAllStarters(), isNotEmpty);
    });
  });

  group('getStartersByCategory', () {
    test('only returns starters in the requested category', () {
      final starters = service.getStartersByCategory('nostalgic');
      expect(starters, isNotEmpty);
      expect(starters.every((s) => s.category == 'nostalgic'), isTrue);
    });

    test('returns an empty list for an unknown category', () {
      expect(service.getStartersByCategory('nonexistent'), isEmpty);
    });
  });

  group('rateStarter', () {
    test('returns a copy carrying the new rating without mutating the catalog', () {
      final original = service.getAllStarters().first;
      final rated = service.rateStarter(original, 4);

      expect(rated.rating, 4);
      expect(rated.id, original.id);
      expect(service.getAllStarters().first.rating, isNull);
    });
  });

  group('getTopRatedStarters', () {
    test('is empty since rateStarter never persists back to the catalog', () {
      service.rateStarter(service.getAllStarters().first, 5);
      expect(service.getTopRatedStarters(), isEmpty);
    });
  });
}
