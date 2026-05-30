import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/contact_matches_screen.dart';

void main() {
  group('ContactMatchesScreen', () {
    testWidgets('renders with no matches', (WidgetTester tester) async {
      const screen = ContactMatchesScreen(matches: ContactMatches.empty);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: screen,
          ),
        ),
      );

      expect(find.text('No matches found yet. Import contacts first to see who is already on Reconnect.'),
          findsOneWidget);
    });

    testWidgets('renders with matches and displays tabs', (WidgetTester tester) async {
      final matches = ContactMatches(
        mutual: const [],
        oneWay: const [],
        notOnApp: [
          const MatchCandidate(name: 'Alice Johnson', status: 'Not on app'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: ContactMatchesScreen(matches: matches),
            ),
          ),
        ),
      );

      // Should show the matches count
      expect(find.text('Matches found: 1'), findsOneWidget);

      // Should show all tabs
      expect(find.text('Mutual'), findsOneWidget);
      expect(find.text('Discovered'), findsOneWidget);
      expect(find.text('Not on app'), findsOneWidget);
    });

    testWidgets('displays mutual matches correctly', (WidgetTester tester) async {
      final matches = ContactMatches(
        mutual: [
          const MatchCandidate(
            name: 'Charlie Brown',
            contact: ReconnectContact(
              id: '1',
              name: 'Charlie Brown',
              email: 'charlie@example.com',
              phone: '555-1234',
              isOnApp: true,
              lastSeen: 'Last seen: 2 hours ago',
              availableIn: [],
              preference: ReconnectPreference.like,
            ),
          ),
        ],
        oneWay: const [],
        notOnApp: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: ContactMatchesScreen(matches: matches),
            ),
          ),
        ),
      );

      // Verify the mutual match is shown
      expect(find.text('Charlie Brown'), findsOneWidget);
      expect(find.text('Mutual match'), findsOneWidget);
    });

    testWidgets('renders screen without errors', (WidgetTester tester) async {
      final matches = ContactMatches(
        mutual: const [],
        oneWay: const [],
        notOnApp: [
          const MatchCandidate(name: 'Test User', status: 'Not on app'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: ContactMatchesScreen(matches: matches),
            ),
          ),
        ),
      );

      // Verify the screen renders without throwing
      expect(find.text('Not on app'), findsOneWidget);
    });
  });
}
