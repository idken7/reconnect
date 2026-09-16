import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/contact_detail_screen.dart';
import 'package:reconnect/widgets/suggestion_deck_sheet.dart';

const _contact = ReconnectContact(
  id: '1',
  name: 'Alice',
  email: 'alice@example.com',
  phone: '+11111111111',
  preference: ReconnectPreference.loveToSee,
  availableIn: ['San Francisco', 'Oakland'],
  lastSeen: '2 weeks ago',
  isOnApp: true,
);

void main() {
  testWidgets('displays the contact\'s name and availability', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactDetailScreen(contact: _contact),
      ),
    );

    expect(find.text('Alice'), findsWidgets);
    expect(find.text('On Reconnect'), findsOneWidget);
    expect(find.text('San Francisco, Oakland'), findsOneWidget);
  });

  testWidgets('shows "Not on Reconnect" for a contact who is not on the app', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactDetailScreen(
          contact: ReconnectContact(
            id: '2',
            name: 'Bob',
            email: 'bob@example.com',
            phone: '+12222222222',
            preference: ReconnectPreference.neutral,
            availableIn: [],
            lastSeen: 'Unknown',
            isOnApp: false,
          ),
        ),
      ),
    );

    expect(find.text('Not on Reconnect'), findsOneWidget);
  });

  testWidgets('Start conversation opens the suggestion deck sheet', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactDetailScreen(contact: _contact),
      ),
    );

    await tester.tap(find.text('Start conversation'));
    await tester.pumpAndSettle();

    expect(find.byType(SuggestionDeckSheet), findsOneWidget);
    expect(find.text('Conversation starters'), findsOneWidget);
  });

  testWidgets('Suggest activity opens the suggestion deck sheet', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactDetailScreen(contact: _contact),
      ),
    );

    await tester.tap(find.text('Suggest activity'));
    await tester.pumpAndSettle();

    expect(find.byType(SuggestionDeckSheet), findsOneWidget);
    expect(find.text('Activity ideas'), findsOneWidget);
  });

  testWidgets('Call or message shows a "coming soon" message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ContactDetailScreen(contact: _contact),
      ),
    );

    await tester.tap(find.text('Call or message'));
    await tester.pump();

    expect(find.text('Contact options coming soon'), findsOneWidget);
  });
}
