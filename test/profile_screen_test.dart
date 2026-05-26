import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/profile_screen.dart';

void main() {
  group('ProfileScreen Feature Buttons', () {
    testWidgets('Feature buttons are displayed', (WidgetTester tester) async {
      final profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              profile: profile,
              contactsImported: true,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onRankContacts: () {},
              onChangeLocation: () {},
              onSpinWheel: () {},
              onConversationStarter: () {},
              onActivitySuggestion: () {},
            ),
          ),
        ),
      );

      // Verify buttons are present
      expect(find.text('Spin the wheel'), findsOneWidget);
      expect(find.text('Conversation starters'), findsOneWidget);
      expect(find.text('Activity suggestions'), findsOneWidget);
      
      // Verify they are OutlinedButton widgets
      expect(find.byType(OutlinedButton), findsWidgets);
    });

    testWidgets('Feature buttons are hidden when callbacks are null', (WidgetTester tester) async {
      final profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              profile: profile,
              contactsImported: true,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onRankContacts: () {},
              onChangeLocation: () {},
              // All feature callbacks are null
            ),
          ),
        ),
      );

      // Verify buttons are NOT present when callbacks are null
      expect(find.text('Spin the wheel'), findsNothing);
      expect(find.text('Conversation starters'), findsNothing);
      expect(find.text('Activity suggestions'), findsNothing);
    });
  });
}
