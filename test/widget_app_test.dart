import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/app.dart';
import 'package:reconnect/app_state.dart';
import 'package:reconnect/services/storage/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReconnectApp Widget Tests', () {
    testWidgets('App renders MaterialApp widget', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final appState = ReconnectAppState(sessionStore: InMemorySessionStore());
      addTearDown(appState.dispose);

      await tester.pumpWidget(ReconnectApp(appState: appState));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App can be created without errors', (WidgetTester tester) async {
      // Just verify the app widget can be instantiated
      const app = ReconnectApp();
      expect(app, isNotNull);
    });
  });
}
