import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/contacts_screen.dart';

void main() {
  group('ContactsScreen Basic Functionality', () {
    final mockContacts = [
      ReconnectContact(
        id: '1',
        name: 'Alice',
        email: 'alice@example.com',
        phone: '1234567890',
        isOnApp: true,
        lastSeen: '2 days ago',
        availableIn: ['NYC'],
        preference: ReconnectPreference.loveToSee,
        lastContacted: DateTime(2024, 5, 29),
      ),
      ReconnectContact(
        id: '2',
        name: 'Bob',
        email: 'bob@example.com',
        phone: '1234567891',
        isOnApp: false,
        lastSeen: '1 week ago',
        availableIn: ['LA'],
        preference: ReconnectPreference.neutral,
        lastContacted: DateTime(2024, 5, 22),
      ),
      ReconnectContact(
        id: '3',
        name: 'Charlie',
        email: 'charlie@example.com',
        phone: '1234567892',
        isOnApp: true,
        lastSeen: '3 days ago',
        availableIn: ['SF'],
        preference: ReconnectPreference.ratherAvoid,
        lastContacted: DateTime(2024, 5, 28),
      ),
    ];

    testWidgets('ContactsScreen renders successfully with contacts', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ContactsScreen(
            contactsImported: true,
            contacts: mockContacts,
            isImporting: false,
            statusMessage: null,
            onImportContacts: () {},
            onPreferenceChanged: (_, __) {},
          ),
        ),
      );

      // Wait for initialization
      await tester.pump(const Duration(seconds: 1));

      // Verify UI is displayed and not crashing
      expect(find.byType(ContactsScreen), findsOneWidget);
    });

    testWidgets('ContactsScreen shows import button when not imported', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ContactsScreen(
            contactsImported: false,
            contacts: const [],
            isImporting: false,
            statusMessage: null,
            onImportContacts: () {},
            onPreferenceChanged: (_, __) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Import contacts'), findsOneWidget);
      expect(find.byIcon(Icons.contacts), findsOneWidget);
    });
  });
}
