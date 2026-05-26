import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/app.dart';

void main() {
  group('ReconnectApp Widget Tests', () {
    testWidgets('App renders MaterialApp widget', (WidgetTester tester) async {
      await tester.pumpWidget(const ReconnectApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App can be created without errors', (WidgetTester tester) async {
      // Just verify the app widget can be instantiated
      const app = ReconnectApp();
      expect(app, isNotNull);
    });
  });
}
