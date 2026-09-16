import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/contact_detail_screen.dart';
import 'screens/contact_matches_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/nearby_screen.dart';
import 'screens/onboarding_flow.dart';
import 'screens/profile_screen.dart';
import 'screens/spin_wheel_screen.dart';
import 'theme/reconnect_theme.dart';
import 'widgets/reconnect_nav_bar.dart';

class ReconnectApp extends StatefulWidget {
  const ReconnectApp({super.key});

  @override
  State<ReconnectApp> createState() => _ReconnectAppState();
}

class _ReconnectAppState extends State<ReconnectApp> {
  late final ReconnectAppState appState;
  // Platform never changes at runtime, so the theme (including a
  // ColorScheme.fromSeed computation) only needs to be built once rather
  // than on every rebuild.
  late final ThemeData theme;
  // This State only decides which top-level screen (loading / onboarding /
  // home) is shown, so it only needs to rebuild when that decision actually
  // changes — not on every appState.notifyListeners() call. Everything
  // below (e.g. _HomePage) listens to appState directly, so a change like
  // switching tabs or updating a preference no longer rebuilds the whole
  // MaterialApp.
  late (bool loading, bool authenticated, bool needsOnboarding) _mode;

  @override
  void initState() {
    super.initState();
    appState = ReconnectAppState();
    _mode = _currentMode();
    appState.addListener(_handleStateChange);
    theme = buildReconnectTheme();
  }

  @override
  void dispose() {
    appState.removeListener(_handleStateChange);
    appState.dispose();
    super.dispose();
  }

  (bool, bool, bool) _currentMode() =>
      (appState.isLoading, appState.isAuthenticated, appState.requiresOnboarding);

  void _handleStateChange() {
    final mode = _currentMode();
    if (mode != _mode) {
      setState(() => _mode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reconnect',
      theme: theme,
      home: _HomePage(appState: appState),
    );
  }
}

class _HomePage extends StatefulWidget {
  final ReconnectAppState appState;

  const _HomePage({required this.appState});

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  // Whether the Spin the wheel page (opened via the nav bar's raised center
  // button) is showing instead of whichever of the 4 real tabs
  // appState.currentIndex points at. Kept as local UI state rather than on
  // appState since it's not one of the persistent tabs — mirrors the
  // mockup's flat `tab` state, which includes 'spin' alongside the 4 nav
  // destinations.
  bool _spinOpen = false;

  // The top-level State no longer rebuilds this widget on every appState
  // change (see _ReconnectAppState), so this screen listens directly —
  // that keeps the rebuild scoped to the home tab shell instead of the
  // whole app tree.
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_handleAppStateChange);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChange);
    super.dispose();
  }

  void _handleAppStateChange() {
    setState(() {});
  }

  void _selectTab(int index) {
    setState(() => _spinOpen = false);
    widget.appState.setIndex(index);
  }

  void _openSpin() => setState(() => _spinOpen = true);

  void _toggleSpin() => setState(() => _spinOpen = !_spinOpen);

  // Builds only the requested tab instead of constructing all four on every
  // rebuild — AnimatedSwitcher only ever mounts one of them at a time, so
  // building the other three was wasted work.
  Widget _buildTab(int index, BuildContext context) {
    final appState = widget.appState;

    switch (index) {
      case 0:
        return ContactsScreen(
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
          nearbyContactIds: appState.nearbySuggestions.map((s) => s.contact.id).toSet(),
        );
      case 1:
        return NearbyScreen(
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
        );
      case 2:
        return ContactMatchesScreen(matches: appState.matches);
      case 3:
      default:
        return ProfileScreen(
          profile: appState.profile,
          contactsImported: appState.contactsImported,
          contactsCount: appState.contacts.length,
          isImporting: appState.isImporting,
          statusMessage: appState.errorMessage,
          onImportContacts: () {
            unawaited(appState.importContacts());
          },
          onChangeLocation: () => _selectTab(1),
          onEditProfile: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EditProfileScreen(
                  profile: appState.profile,
                  supportedLocations: appState.supportedLocations,
                  onSave: (bio, homeCity) async {
                    await appState.updateProfile(
                      bio: bio,
                      homeCity: homeCity,
                    );
                  },
                  onSaveProfile: (bio, homeCity, profileImageUrl) async {
                    await appState.updateProfile(
                      bio: bio,
                      homeCity: homeCity,
                      profileImageUrl: profileImageUrl,
                    );
                  },
                ),
              ),
            );
          },
          onSpinWheel: _openSpin,
        );
    }
  }

  Widget _buildSpinTab(BuildContext context) {
    final appState = widget.appState;
    return SpinWheelScreen(
      contacts: appState.contacts,
      nearbySuggestions: appState.nearbySuggestions,
      onContactSpun: (contact) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ContactDetailScreen(contact: contact),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;

    // Each tab screen owns its own AdaptiveScaffold (own contextual title,
    // own nav-bar trailing actions) — this shell is just the persistent
    // bottom tab bar plus whichever tab (or the Spin page) is currently
    // showing.
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey<String>(_spinOpen ? 'spin' : 'tab-${appState.currentIndex}'),
          child: _spinOpen ? _buildSpinTab(context) : _buildTab(appState.currentIndex, context),
        ),
      ),
      bottomNavigationBar: ReconnectNavBar(
        currentIndex: appState.currentIndex,
        spinActive: _spinOpen,
        onDestinationSelected: _selectTab,
        onSpinTap: _toggleSpin,
      ),
    );
  }
}
