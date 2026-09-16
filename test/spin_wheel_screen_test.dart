import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/spin_wheel_screen.dart';

void main() {
  group('SpinWheelScreen Contact Slices', () {
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
        preference: ReconnectPreference.like,
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
        preference: ReconnectPreference.neutral,
        lastContacted: DateTime(2024, 5, 28),
      ),
    ];

    testWidgets('SpinWheelScreen renders successfully with contact slices',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SpinWheelScreen(
              contacts: mockContacts,
              onContactSpun: (_) {},
            ),
          ),
        );

        // Wait for initialization
        await tester.pump(const Duration(seconds: 1));

        // Verify the spin wheel screen is displayed
        expect(find.byType(SpinWheelScreen), findsOneWidget);

        // Verify the wheel's painted circle is rendered
        expect(find.byType(CustomPaint), findsWidgets);
      },
    );

    testWidgets('SpinWheelScreen shows the scope toggle and spin button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SpinWheelScreen(
              contacts: mockContacts,
              onContactSpun: (_) {},
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Verify the scope toggle and spin button exist
        expect(find.text('Nearby people'), findsOneWidget);
        expect(find.text('Anywhere'), findsOneWidget);
        expect(find.text('Spin the wheel'), findsWidgets);
      },
    );

    testWidgets('SpinWheelScreen with empty contacts renders without crashing',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SpinWheelScreen(
              contacts: const [],
              onContactSpun: (_) {},
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Verify the screen renders without errors
        expect(find.byType(SpinWheelScreen), findsOneWidget);
        expect(find.text('0 people eligible'), findsOneWidget);
      },
    );

    testWidgets('Days threshold selector is displayed',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SpinWheelScreen(
              contacts: mockContacts,
              onContactSpun: (_) {},
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Verify the threshold selector text
        expect(find.text("Haven't talked in"), findsOneWidget);

        // Verify the draggable threshold slider and its default label
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('1 month+'), findsOneWidget);
      },
    );

    testWidgets('Spin button shows a spinning state once tapped',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SpinWheelScreen(
              contacts: mockContacts,
              onContactSpun: (_) {},
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Scroll the button into view, then tap it. Uses plain pump()
        // rather than pumpAndSettle() throughout this screen because the
        // wheel's idle pulse animation repeats forever and never settles.
        final spinButton = find.text('Spin the wheel').last;
        await tester.ensureVisible(spinButton);
        await tester.pump();
        await tester.tap(spinButton);
        await tester.pump();

        // Verify the button now shows a spinning state
        expect(find.text('Spinning…'), findsOneWidget);
      },
    );

    testWidgets('Multiple contacts create multiple wheel slices',
      (WidgetTester tester) async {
        final manyContacts = List.generate(
          5,
          (i) => ReconnectContact(
            id: '$i',
            name: 'Contact $i',
            email: 'contact$i@example.com',
            phone: '123456789$i',
            isOnApp: true,
            lastSeen: '${i + 1} days ago',
            availableIn: ['NYC'],
            preference: ReconnectPreference.loveToSee,
            lastContacted: DateTime(2024, 5, 29 - i),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: SpinWheelScreen(
              contacts: manyContacts,
              onContactSpun: (_) {},
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 1));

        // Verify all contacts are available for spinning
        expect(find.byType(SpinWheelScreen), findsOneWidget);
        expect(find.text('5 people eligible'), findsOneWidget);
      },
    );
  });
}
