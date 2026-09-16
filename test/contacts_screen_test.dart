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
      await tester.pumpAndSettle(const Duration(seconds: 2));

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
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
    });

    testWidgets('ContactsScreen filters contacts via the search bar', (WidgetTester tester) async {
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
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
    });

    testWidgets('Dragging a contact chip into another lane updates its preference', (WidgetTester tester) async {
      ReconnectPreference? changedTo;
      await tester.pumpWidget(
        MaterialApp(
          home: ContactsScreen(
            contactsImported: true,
            contacts: mockContacts,
            isImporting: false,
            statusMessage: null,
            onImportContacts: () {},
            onPreferenceChanged: (_, preference) => changedTo = preference,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final aliceChip = find.text('Alice');
      final likeLaneLabel = find.text('Like');
      expect(aliceChip, findsOneWidget);
      expect(likeLaneLabel, findsOneWidget);

      final start = tester.getCenter(aliceChip);
      final end = tester.getCenter(likeLaneLabel);
      final gesture = await tester.startGesture(start);
      // Draggable(affinity: Axis.vertical) decides the gesture is a drag
      // (rather than the lane's own horizontal scroll) from the direction
      // of the first move, so step vertically toward the target in a few
      // increments rather than jumping straight there.
      final steps = 5;
      for (var i = 1; i <= steps; i++) {
        await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedTo, ReconnectPreference.like);
    });
  });

  group('ReconnectPreference Tests', () {
    test('All preferences have emojis', () {
      for (final pref in ReconnectPreference.values) {
        expect(pref.emoji, isNotEmpty);
      }
    });

    test('All preferences have labels', () {
      for (final pref in ReconnectPreference.values) {
        expect(pref.label, isNotEmpty);
        expect(pref.shortLabel, isNotEmpty);
      }
    });

    test('Preferences have correct emojis', () {
      expect(ReconnectPreference.loveToSee.emoji, equals('😍'));
      expect(ReconnectPreference.like.emoji, equals('🙂'));
      expect(ReconnectPreference.neutral.emoji, equals('😐'));
      expect(ReconnectPreference.dislike.emoji, equals('😕'));
      expect(ReconnectPreference.ratherAvoid.emoji, equals('☹️'));
    });

    test('Preferences have correct sort weights', () {
      expect(ReconnectPreference.loveToSee.sortWeight, equals(0));
      expect(ReconnectPreference.like.sortWeight, equals(1));
      expect(ReconnectPreference.neutral.sortWeight, equals(2));
      expect(ReconnectPreference.dislike.sortWeight, equals(3));
      expect(ReconnectPreference.ratherAvoid.sortWeight, equals(4));
    });
  });
}
