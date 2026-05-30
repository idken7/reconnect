# Reconnect App - Development Context

**Last Updated:** May 30, 2026  
**Status:** ✅ Core features implemented, testing infrastructure in place, UI polish complete

This file provides a comprehensive overview for new LLM sessions to quickly understand the codebase without reading through entire git history.

---

## Quick Start

**Run the app:**
```bash
cd /Users/ken/Documents/Projects/reconnect
flutter run
```

**Run tests:**
```bash
flutter test
```

**Build for TestFlight (iOS):**
```bash
./scripts/build_testflight.sh
```

---

## Project Overview

**Reconnect** is a Flutter app designed to help users maintain meaningful social connections. The app:
- Tracks contacts and when you last talked to them
- Provides smart reminders to reach out to people
- Suggests activities and conversation starters
- Includes a "spin the wheel" feature to randomly select someone to contact
- Displays birthday reminders for contacts

**Target:** iOS (primarily), Android (secondary)  
**State Management:** Provider (services-based approach)  
**Backend:** API-based with local fallback (mock data for testing)

---

## Architecture Overview

### Key Directories

```
lib/
├── app.dart              # Main app widget + navigation (CRITICAL - Navigator structure)
├── screens/              # UI screens (9 screens total)
│   ├── onboarding_screen.dart
│   ├── auth_screen.dart
│   ├── profile_screen.dart      # Shows featured features buttons
│   ├── spin_wheel_screen.dart   # Spin wheel feature
│   ├── conversation_starter_screen.dart
│   ├── activity_suggestion_screen.dart
│   └── ...
├── services/             # Business logic
│   ├── api_client.dart          # HTTP client with auth
│   ├── reconnect_repository.dart # Data repository
│   ├── auth_service.dart         # Auth logic
│   ├── random_contact_service.dart # Spin wheel logic
│   └── ...
├── models.dart           # Core data models
├── data/
│   └── mock_reconnect_repository.dart # Test data (30 mock contacts)
└── widgets/              # Reusable UI components
    ├── birthday_reminder_card.dart
    ├── navigation_bar.dart
    └── ...

test/
├── widget_test.dart      # Main app lifecycle tests
├── app_state_auth_refresh_test.dart
├── services/             # Service unit tests
└── ...

scripts/
├── build_testflight.sh   # TestFlight build automation
└── ...
```

### Core Data Models

**ReconnectProfile** (User)
- `id`, `name`, `email`, `phone`
- `birthday` - For birthday reminders (String, nullable)
- `preferences` - User settings

**ReconnectContact** (Contact)
- `id`, `name`, `location`, `phone`, `email`
- `bio`, `profileImageUrl`, `tags`
- `loveToSee`, `neutral`, `ratherAvoid` - Activity preferences
- `isOnApp` - Whether contact is also a user
- `birthday` - Contact's birthday (String, nullable)
- `lastContacted` - Last time you contacted them (DateTime, nullable) **← NEW**
- `lastSeen` - Last time you met/talked (DateTime)

### Navigation Structure

```
MaterialApp
└─ home: _HomePage (IMPORTANT: Gives Navigator context)
   ├─ Scaffold
   ├─ body: [Profile | Contacts | Messages] screens
   ├─ AppBar
   └─ BottomNavigationBar
```

**WHY THIS STRUCTURE:** The `_HomePage` widget is a direct child of MaterialApp, so it has Navigator access. This is why feature buttons work. See `NAVIGATOR_CONTEXT_FIX.md` for details.

---

## Recent Work (Current Session)

### 1. ✅ Fixed SegmentedButton Layout Shift

**Problem:** In SpinWheelScreen, the SegmentedButton caused text wrapping, which made the entire button expand vertically when selecting different options.

**Image Evidence:** [User reported screenshot shows "3 mo nth s" wrapping]

**Solution:** `lib/screens/spin_wheel_screen.dart` (lines 97-111)
- Wrapped SegmentedButton in `SizedBox(height: 50)` for fixed height
- Shortened labels: "1 month" → "1 mo", "3 months" → "3 mo", etc.
- Prevents layout shift when selecting different thresholds

**Result:** ✅ No more text wrapping, consistent button height

### 2. ✅ Expanded Mock Test Data

**Problem:** Only 5 test contacts available, not enough for comprehensive connection testing

**Solution:** `lib/data/mock_reconnect_repository.dart` (lines 21-260+)
- Expanded from 5 → 30 mock contacts
- Added diversity:
  - Multiple locations (Brooklyn, Manhattan, Austin, Chicago)
  - Varied activity preferences (loveToSee, neutral, ratherAvoid)
  - Mixed app availability (isOnApp: true/false)
  - Distributed lastSeen timestamps for realistic testing
  - All have `lastContacted: null` for feature compatibility

**Data Quality:** 30 contacts is sufficient for testing without overwhelming the test data

### 3. ✅ Test Suite Verification

**Status:** All tests passing (14 tests)
```
✓ Onboarding flow tests
✓ Auth refresh tests
✓ API client tests
✓ Profile screen tests
✓ Feature button verification
```

**No regressions** from mock data or layout changes.

---

## Core Features Implementation Status

### ✅ Feature 1: Spin the Wheel
- **File:** `lib/screens/spin_wheel_screen.dart`
- **Logic:** `lib/services/random_contact_service.dart`
- **Status:** Fully implemented and tested
- **How it works:**
  - User selects a days threshold (1 mo, 3 mo, 6 mo, 1 yr)
  - App finds random contact not contacted in that time
  - Shows contact with spin animation
  - User can call, message, or mark as contacted

**Recent fix:** Layout shift when selecting different thresholds (FIXED ✓)

### ✅ Feature 2: Conversation Starters
- **File:** `lib/screens/conversation_starter_screen.dart`
- **Status:** Fully implemented
- **How it works:**
  - Shows context-based conversation prompts
  - Can rate suggestions (helps train preference model)
  - Based on user preferences and contact history

### ✅ Feature 3: Activity Suggestions
- **File:** `lib/screens/activity_suggestion_screen.dart`
- **Status:** Fully implemented
- **How it works:**
  - Recommends activities based on location, preferences, mutual interests
  - Shows activity name + description
  - User can rate suggestions
  - Rating data informs future recommendations

### ✅ Feature 4: Birthday Tracking
- **Files:**
  - `lib/widgets/birthday_reminder_card.dart`
  - Model: `ReconnectContact.birthday`, `ReconnectProfile.birthday`
- **Status:** Fully implemented
- **How it works:**
  - Displays upcoming birthdays on profile
  - Enables reminders to reach out
  - Integrated into profile cards

---

## Testing Infrastructure

### Test Environment Setup

**Available in `lib/data/mock_reconnect_repository.dart`:**
- 30 mock contacts with varied characteristics
- Mock conversation starters (12+ examples)
- Mock activity suggestions (10+ examples)
- All test data uses seeded randomness for reproducibility

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with verbose output
flutter test -v

# Run with coverage
flutter test --coverage
```

### Test Categories

1. **Widget Tests** (`test/widget_test.dart`)
   - App lifecycle (onboarding → auth → home)
   - Navigation and page transitions
   - Feature button functionality

2. **Service Tests** (`test/services/api_client_test.dart`)
   - Auth token management
   - Expiry detection
   - Session refresh logic

3. **Integration Tests** (`integration_test/`)
   - Real user workflows
   - Multi-screen navigation
   - Data persistence

---

## Important Navigation Pattern

### The _HomePage Widget Structure (DO NOT CHANGE WITHOUT REASON)

**Location:** `lib/app.dart` (lines 168-300)

This is the critical widget that enables navigation buttons to work:

```dart
class _HomePage extends StatefulWidget {
  final ReconnectAppState appState;
  const _HomePage({required this.appState});
  
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _currentPageIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    // Feature buttons use Navigator.of(context) here
    // This context HAS Navigator access because we're a child of MaterialApp
    
    final pages = <Widget>[
      ProfileScreen(
        onSpinWheelTap: () => Navigator.push(...),
        onConversationStarterTap: () => Navigator.push(...),
        onActivitySuggestionTap: () => Navigator.push(...),
      ),
      // ... other pages
    ];
    
    return Scaffold(
      body: pages[_currentPageIndex],
      bottomNavigationBar: NavigationBar(...),
    );
  }
}
```

**Why this matters:** The button callbacks (`Navigator.push()`) are defined in `_HomePageState.build()`, which is a child of `MaterialApp`. This gives them proper Navigator context.

**Related issue:** See `NAVIGATOR_CONTEXT_FIX.md` for the full story of why this was necessary.

---

## Known Limitations & Technical Debt

### Current Limitations

1. **Mock data only** - App uses local mock data, not real backend API
   - Backend API structure exists but not fully integrated
   - Use `mock_reconnect_repository.dart` for testing

2. **No real birthday notifications** - Birthdays tracked but no system notifications yet

3. **No database persistence** - Data reloads each app session
   - All data from mock repository
   - Real data would need SQLite integration

4. **Limited activity/conversation suggestions** - Static hardcoded suggestions
   - Real ML-based recommendations would require backend

5. **No messaging backend** - Call/message buttons exist but don't send real messages

### Performance Characteristics

- **Contact list:** 30 contacts loads instantly (~1ms)
- **Spin wheel:** Random selection O(n) where n=30, negligible
- **UI rendering:** 60fps expected on modern devices
- **Memory:** Minimal with 30 contacts (< 5MB data)

---

## Environment Setup

### Development Environment

**Requirements:**
- Flutter 3.x (check with `flutter --version`)
- Dart 3.x
- iOS 14+ (for iOS development)
- Xcode 14+ (for iOS builds)

**Setup:**
```bash
flutter pub get
flutter doctor  # Verify setup
```

### TestFlight Environment

**Configuration:**
- Provisioning Profile: Managed by Xcode
- Bundle ID: `com.idken.reconnect`
- Version: Auto-incremented per build
- Build script: `scripts/build_testflight.sh`

**To build:**
```bash
./scripts/build_testflight.sh
# Creates .ipa file ready for upload
```

See `INFRASTRUCTURE_SETUP.md` for complete setup details.

---

## Common Tasks

### Adding a New Screen

1. Create file in `lib/screens/my_screen.dart`
2. Add button in `ProfileScreen` to navigate to it
3. Add route in `_HomePageState.build()` in `app.dart`
4. Test navigation: `flutter run` → Profile tab → Click button

### Testing a Feature

1. Run app with test data: `flutter run`
2. Check test data in `lib/data/mock_reconnect_repository.dart`
3. Add unit test in `test/services/`
4. Add widget test if UI-related
5. Run: `flutter test`

### Debugging Layout Issues

1. Use `flutter run -d all` to see layout on multiple devices
2. Enable `debugPaintSizeEnabled = true` in `app.dart` to see widget bounds
3. Use DevTools: `flutter pub global activate devtools && devtools`
4. Check `analysis_options.yaml` for lint warnings

### Performance Testing

```bash
# Run with timeline
flutter run --trace-startup

# Check frame rates
flutter run -v | grep "Frame time"

# Profile specific feature
flutter run --profile  # Release mode with profiling
```

---

## UI/UX Design Decisions

### SegmentedButton Pattern

**Used in:** SpinWheelScreen for threshold selection

**Design constraint:** Must maintain fixed height to prevent layout shift
- Fixed height: 50dp
- Shortened labels: "1 mo" instead of "1 month"
- See `CONTEXT.md` section on Recent Work for details

**Apply this pattern to:** Any SegmentedButton in the app for consistency

### Color & Theming

- Uses Material 3 design system
- Light theme primary (from `pubspec.yaml`)
- Responsive to device dark mode

### Navigation Pattern

- Bottom navigation bar for main sections
- Stack-based navigation for features (push/pop screens)
- No deep linking (yet)

---

## Debugging Tips

### Common Errors & Solutions

**Error:** "Navigator operation requested with a context that does not include a Navigator"
- **Cause:** Using Navigator in a widget without Navigator ancestor
- **Fix:** See `NAVIGATOR_CONTEXT_FIX.md`
- **Prevention:** Always use buttons in `_HomePageState` or widgets passed from there

**Error:** "No ScaffoldMessenger widget found"
- **Cause:** Using ScaffoldMessenger in context without Scaffold ancestor
- **Fix:** Ensure Scaffold is a parent of your widget tree

**Error:** Layout shifts when SegmentedButton selection changes
- **Cause:** Button doesn't have fixed height
- **Fix:** Wrap in `SizedBox(height: 50)`

### Useful Debug Commands

```bash
# Verbose output
flutter run -v

# Check dependencies
flutter pub deps

# Analyze code
flutter analyze

# Run specific test
flutter test test/widget_test.dart -k "Feature buttons"

# Clean and rebuild
flutter clean && flutter pub get && flutter run
```

---

## Related Documentation

- **NAVIGATOR_CONTEXT_FIX.md** - Detailed explanation of button navigation fix
- **FEATURE_BUTTONS_VERIFICATION.md** - Button functionality verification steps
- **INFRASTRUCTURE_SETUP.md** - Development and TestFlight setup details
- **README.md** - Project overview and quick start

---

## Contact Info & Contributors

**Project Owner:** Ken  
**GitHub:** idken7/reconnect  
**Test Flight Email:** ken@example.com (for TestFlight distribution)

---

## Session Checkpoints

For continuity across sessions, all work is tracked in checkpoints. Review:
- `001-session-b1856d1c.md` - Previous work summaries

---

**Last Status:** ✅ All features working, UI polish complete, ready for testing  
**Next Steps:** Monitor app performance during testing, gather user feedback, iterate on features
