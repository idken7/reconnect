import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/activity_suggestion_screen.dart';
import 'screens/contact_matches_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/conversation_starter_screen.dart';
import 'screens/nearby_screen.dart';
import 'screens/onboarding_flow.dart';
import 'screens/profile_screen.dart';
import 'screens/spin_wheel_screen.dart';

class ReconnectApp extends StatefulWidget {
  const ReconnectApp({super.key});

  @override
  State<ReconnectApp> createState() => _ReconnectAppState();
}

class _ReconnectAppState extends State<ReconnectApp> {
  late final ReconnectAppState appState;

  @override
  void initState() {
    super.initState();
    appState = ReconnectAppState();
    appState.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    appState.removeListener(_handleStateChange);
    appState.dispose();
    super.dispose();
  }

  void _handleStateChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      useMaterial3: true,
    );

    if (appState.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Reconnect',
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!appState.isAuthenticated || appState.requiresOnboarding) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Reconnect',
        theme: theme,
        home: OnboardingFlow(appState: appState),
      );
    }

    final pages = <Widget>[
      ContactsScreen(
        contactsImported: appState.contactsImported,
        contacts: appState.contacts,
        isImporting: appState.isImporting,
        statusMessage: appState.errorMessage,
        onImportContacts: () {
          unawaited(appState.importContacts());
        },
        onPreferenceChanged: (contactId, preference) {
          unawaited(appState.updatePreference(contactId, preference));
        },
      ),
      NearbyScreen(
        contactsImported: appState.contactsImported,
        currentLocation: appState.currentLocation,
        supportedLocations: appState.supportedLocations,
        suggestions: appState.nearbySuggestions,
        isResolvingLocation: appState.isResolvingLocation,
        isImporting: appState.isImporting,
        statusMessage: appState.errorMessage,
        onUseLiveLocation: () {
          unawaited(appState.refreshLiveLocation());
        },
        onLocationSelected: (location) {
          unawaited(appState.setLocation(location));
        },
        onImportContacts: () {
          unawaited(appState.importContacts());
        },
      ),
      ContactMatchesScreen(matches: appState.matches),
      ProfileScreen(
        profile: appState.profile,
        contactsImported: appState.contactsImported,
        isImporting: appState.isImporting,
        statusMessage: appState.errorMessage,
        onImportContacts: () {
          unawaited(appState.importContacts());
        },
        onRankContacts: () => appState.setIndex(0),
        onChangeLocation: () => appState.setIndex(1),
        onSpinWheel: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SpinWheelScreen(
                contacts: appState.contacts,
                onContactSpun: (contact) {
                  // Handle contact selection
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
        onConversationStarter: () {
          if (appState.contacts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No contacts available')),
            );
            return;
          }
          final contact = appState.contacts.first;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ConversationStarterScreen(
                contact: contact,
                onSuggestionRated: (starter) {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
        onActivitySuggestion: () {
          if (appState.contacts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No contacts available')),
            );
            return;
          }
          final contact = appState.contacts.first;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ActivitySuggestionScreen(
                contact: contact,
                userLocation: appState.currentLocation,
                onSuggestionRated: (suggestion) {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
      ),
    ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reconnect',
      theme: theme,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Reconnect'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  appState.currentLocation,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey<int>(appState.currentIndex),
            child: pages[appState.currentIndex],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: appState.currentIndex,
          onDestinationSelected: appState.setIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place),
              label: 'Nearby',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
