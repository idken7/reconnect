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
      const matches = ContactMatches(
        mutual: [],
        oneWay: [],
        notOnApp: [
          MatchCandidate(name: 'Alice Johnson', status: 'Not on app'),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: ContactMatchesScreen(matches: matches),
            ),
          ),
        ),
      );

      // Should show the header
      expect(find.text('Matches'), findsOneWidget);

      // Should show all tabs
      expect(find.text('Mutual'), findsOneWidget);
      expect(find.text('Discovered'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
    });

    testWidgets('displays mutual matches correctly', (WidgetTester tester) async {
      const matches = ContactMatches(
        mutual: [
          MatchCandidate(
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
        oneWay: [],
        notOnApp: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: ContactMatchesScreen(matches: matches),
            ),
          ),
        ),
      );

      // Verify the mutual match is shown, badged "Mutual" (which also
      // labels the currently-selected tab pill, hence findsWidgets).
      expect(find.text('Charlie Brown'), findsOneWidget);
      expect(find.text('Mutual'), findsWidgets);
    });

    testWidgets('renders screen without errors', (WidgetTester tester) async {
      const matches = ContactMatches(
        mutual: [],
        oneWay: [],
        notOnApp: [
          MatchCandidate(name: 'Test User', status: 'Not on app'),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: ContactMatchesScreen(matches: matches),
            ),
          ),
        ),
      );

      // Verify the screen renders without throwing
      expect(find.text('Invite'), findsOneWidget);
    });
  });
}
