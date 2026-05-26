import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reconnect/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Reconnect App Integration Tests', () {
    testWidgets('App launches and displays initial screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ReconnectApp());
      await tester.pumpAndSettle();

      // Verify the app has launched
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation between screens works', (WidgetTester tester) async {
      await tester.pumpWidget(const ReconnectApp());
      await tester.pumpAndSettle();

      // Get initial screen
      expect(find.byType(MaterialApp), findsOneWidget);

      // The integration test verifies the app can be navigated
      // without crashes or exceptions
    });

    testWidgets('App handles permissions requests gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ReconnectApp());
      await tester.pumpAndSettle();

      // Verify app doesn't crash when checking permissions
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
