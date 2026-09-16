
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/models.dart';
import 'package:reconnect/screens/profile_screen.dart';
import 'package:reconnect/screens/edit_profile_screen.dart';

void main() {
  group('ProfileScreen Feature Buttons', () {
    testWidgets('Spin the wheel card is displayed', (WidgetTester tester) async {
      const profile = ReconnectProfile(
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
              contactsCount: 3,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onChangeLocation: () {},
              onEditProfile: () {},
              onSpinWheel: () {},
            ),
          ),
        ),
      );

      // Verify the Spin the wheel CTA is present
      expect(find.text('Spin the wheel'), findsOneWidget);
    });

    testWidgets('Spin the wheel card is hidden when the callback is null', (WidgetTester tester) async {
      const profile = ReconnectProfile(
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
              contactsCount: 3,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onChangeLocation: () {},
              onEditProfile: () {},
              // onSpinWheel is null
            ),
          ),
        ),
      );

      // Verify the Spin the wheel CTA is NOT present when the callback is null
      expect(find.text('Spin the wheel'), findsNothing);
    });

    testWidgets('Edit profile row is displayed', (WidgetTester tester) async {
      const profile = ReconnectProfile(
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
              contactsCount: 3,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onChangeLocation: () {},
              onEditProfile: () {},
            ),
          ),
        ),
      );

      // Verify the edit profile row is present
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('Edit profile row calls onEditProfile callback', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      bool editCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              profile: profile,
              contactsImported: true,
              contactsCount: 3,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onChangeLocation: () {},
              onEditProfile: () {
                editCalled = true;
              },
            ),
          ),
        ),
      );

      // Find and tap the edit profile row
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();

      expect(editCalled, isTrue);
    });

    testWidgets('Profile information is displayed correctly', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+1234567890',
        homeCity: 'Los Angeles',
        bio: 'Love reconnecting with friends!',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              profile: profile,
              contactsImported: true,
              contactsCount: 7,
              isImporting: false,
              statusMessage: null,
              onImportContacts: () {},
              onChangeLocation: () {},
              onEditProfile: () {},
            ),
          ),
        ),
      );

      // Verify profile information is displayed
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Los Angeles'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });
  });

  group('EditProfileScreen', () {
    // The form's two text fields push the Save/Cancel row past flutter_test's
    // default 800x600 surface, which drops it out of the ListView's built
    // (virtualized) range. Use a taller surface so it's actually reachable.
    setUp(() async {
      final tester = TestWidgetsFlutterBinding.ensureInitialized();
      tester.platformDispatcher.views.first.physicalSize = const Size(800, 1400);
      tester.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() async {
      final tester = TestWidgetsFlutterBinding.ensureInitialized();
      tester.platformDispatcher.views.first.resetPhysicalSize();
      tester.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('EditProfileScreen displays user profile information', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {},
          ),
        ),
      );

      // Verify profile information is displayed
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com • +1234567890'), findsOneWidget);
    });

    testWidgets('EditProfileScreen has bio text field with initial value', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Initial bio text',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {},
          ),
        ),
      );

      // Verify bio field has initial value
      expect(find.text('Initial bio text'), findsOneWidget);
    });

    testWidgets('EditProfileScreen has home city dropdown', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {},
          ),
        ),
      );

      // Verify home city dropdown is present
      expect(find.text('San Francisco'), findsWidgets);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets('EditProfileScreen has Save and Cancel buttons', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {},
          ),
        ),
      );

      // Verify buttons are present
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('EditProfileScreen Cancel button pops navigation', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => EditProfileScreen(
                  profile: profile,
                  supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
                  onSave: (bio, homeCity) async {},
                ),
              ),
            ),
          ),
        ),
      );

      // Find and tap cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Navigation should have popped
      expect(find.byType(EditProfileScreen), findsNothing);
    });

    testWidgets('EditProfileScreen Save button calls onSave callback', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      String? savedBio;
      String? savedCity;
      bool saveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {
              saveCalled = true;
              savedBio = bio;
              savedCity = homeCity;
            },
          ),
        ),
      );

      // Change bio text
      final bioField = find.byKey(const Key('bioField'));
      await tester.tap(bioField);
      await tester.pumpAndSettle();
      await tester.enterText(bioField, 'Updated bio');

      // Tap save button
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saveCalled, isTrue);
      expect(savedBio, 'Updated bio');
      expect(savedCity, 'San Francisco');
    });

    testWidgets('EditProfileScreen shows character count for bio', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {},
          ),
        ),
      );

      // Verify character count is displayed
      expect(find.text('4/160'), findsOneWidget);
    });

    testWidgets('EditProfileScreen disables fields while saving', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      bool saveCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {
              await Future.delayed(const Duration(milliseconds: 100));
              saveCompleted = true;
            },
          ),
        ),
      );

      // Tap save button
      await tester.tap(find.text('Save'));
      await tester.pump();

      // Save button should show loading indicator while saving
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for save to complete
      await tester.pumpAndSettle();

      expect(saveCompleted, isTrue);
    });

    testWidgets('EditProfileScreen shows error message on save failure', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {
              throw Exception('Save failed');
            },
          ),
        ),
      );

      // Tap save button
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Error snackbar should be shown
      expect(find.text('Error saving profile: Exception: Save failed'), findsOneWidget);
    });

    testWidgets('EditProfileScreen validates bio is not empty', (WidgetTester tester) async {
      const profile = ReconnectProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+1234567890',
        homeCity: 'San Francisco',
        bio: 'Test bio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: profile,
            supportedLocations: const ['San Francisco', 'Los Angeles', 'New York'],
            onSave: (bio, homeCity) async {},
          ),
        ),
      );

      // Clear bio field
      final bioField = find.byKey(const Key('bioField'));
      await tester.tap(bioField);
      await tester.pumpAndSettle();
      await tester.enterText(bioField, '');

      // Tap save button
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Validation error should be shown
      expect(find.text('Bio cannot be empty'), findsOneWidget);
    });
  });
}
