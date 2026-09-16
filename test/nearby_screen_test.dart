import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/nearby_screen.dart';

const _contact = ReconnectContact(
  id: '1',
  name: 'Alice',
  email: 'alice@example.com',
  phone: '+11111111111',
  preference: ReconnectPreference.loveToSee,
  availableIn: ['Brooklyn'],
  lastSeen: '2 weeks ago',
  isOnApp: true,
);

Widget _wrap(NearbyScreen screen) => MaterialApp(home: Scaffold(body: screen));

void main() {
  testWidgets('prompts to import contacts when none are imported yet', (WidgetTester tester) async {
    var importTapped = false;

    await tester.pumpWidget(
      _wrap(NearbyScreen(
        contactsImported: false,
        currentLocation: 'Brooklyn',
        supportedLocations: const ['Brooklyn', 'Manhattan'],
        suggestions: const [],
        isResolvingLocation: false,
        isImporting: false,
        statusMessage: null,
        onUseLiveLocation: () {},
        onLocationSelected: (_) {},
        onImportContacts: () => importTapped = true,
      )),
    );

    expect(find.text('Import contacts to see nearby people.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Import contacts'));
    expect(importTapped, isTrue);
  });

  testWidgets('shows an empty state when contacts are imported but no suggestions exist', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(NearbyScreen(
        contactsImported: true,
        currentLocation: 'Brooklyn',
        supportedLocations: const ['Brooklyn', 'Manhattan'],
        suggestions: const [],
        isResolvingLocation: false,
        isImporting: false,
        statusMessage: null,
        onUseLiveLocation: () {},
        onLocationSelected: (_) {},
        onImportContacts: () {},
      )),
    );

    expect(find.textContaining('No suggested meetups in Brooklyn'), findsOneWidget);
  });

  testWidgets('lists nearby suggestions with distance and reason', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(NearbyScreen(
        contactsImported: true,
        currentLocation: 'Brooklyn',
        supportedLocations: const ['Brooklyn', 'Manhattan'],
        suggestions: const [
          NearbySuggestion(
            contact: _contact,
            reason: 'You both love coffee catch-ups',
            distanceLabel: 'Under 2 miles',
          ),
        ],
        isResolvingLocation: false,
        isImporting: false,
        statusMessage: null,
        onUseLiveLocation: () {},
        onLocationSelected: (_) {},
        onImportContacts: () {},
      )),
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('<2 miles away'), findsOneWidget);
    expect(find.text('You both love coffee catch-ups'), findsOneWidget);
  });

  testWidgets('surfaces a status message when present', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(NearbyScreen(
        contactsImported: true,
        currentLocation: 'Brooklyn',
        supportedLocations: const ['Brooklyn'],
        suggestions: const [],
        isResolvingLocation: false,
        isImporting: false,
        statusMessage: 'Location permission denied',
        onUseLiveLocation: () {},
        onLocationSelected: (_) {},
        onImportContacts: () {},
      )),
    );

    expect(find.text('Location permission denied'), findsOneWidget);
  });

  testWidgets('tapping the live location button invokes the callback', (WidgetTester tester) async {
    var liveLocationTapped = false;

    await tester.pumpWidget(
      _wrap(NearbyScreen(
        contactsImported: true,
        currentLocation: 'Brooklyn',
        supportedLocations: const ['Brooklyn'],
        suggestions: const [],
        isResolvingLocation: false,
        isImporting: false,
        statusMessage: null,
        onUseLiveLocation: () => liveLocationTapped = true,
        onLocationSelected: (_) {},
        onImportContacts: () {},
      )),
    );

    await tester.tap(find.text('Live'));
    expect(liveLocationTapped, isTrue);
  });
}
