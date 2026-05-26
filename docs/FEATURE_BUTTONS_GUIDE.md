# Feature Buttons Navigation Guide

## Overview
This document explains how the "Featured features" buttons (Spin the wheel, Conversation starters, Activity suggestions) work in the Reconnect app and how to debug issues if they're not responding.

## Button Location
- **Screen:** Profile screen (bottom navigation → Profile tab)
- **Section:** "Featured features" card (below "MVP actions")
- **Buttons:**
  1. Spin the wheel (casino icon)
  2. Conversation starters (chat bubble icon)
  3. Activity suggestions (lightbulb icon)

## How Navigation Works

### Architecture Overview
```
ReconnectApp (lib/app.dart)
    ↓
    ├─ Creates ReconnectAppState instance
    ├─ Builds 4 pages array
    └─ Passes feature callbacks to ProfileScreen
         ↓
    ProfileScreen (lib/screens/profile_screen.dart)
         ↓
         ├─ Displays buttons with onPressed callbacks
         └─ When button tapped:
            ├─ onSpinWheel → Navigator.push(SpinWheelScreen)
            ├─ onConversationStarter → Navigator.push(ConversationStarterScreen)
            └─ onActivitySuggestion → Navigator.push(ActivitySuggestionScreen)
```

### Code Flow

#### 1. Button Definition (ProfileScreen)
**File:** `lib/screens/profile_screen.dart` (lines 114-136)

```dart
if (onSpinWheel != null) ...[
  OutlinedButton.icon(
    onPressed: onSpinWheel,  // ← Called when tapped
    icon: const Icon(Icons.casino),
    label: const Text('Spin the wheel'),
  ),
],
```

The button is **only displayed if the callback is not null**.

#### 2. Callback Definition (ReconnectApp)
**File:** `lib/app.dart` (lines 114-165)

The ProfileScreen is instantiated with callbacks in the `pages` array:

```dart
ProfileScreen(
  // ... other parameters ...
  onSpinWheel: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpinWheelScreen(
          contacts: appState.contacts,
          onContactSpun: (contact) {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  },
  onConversationStarter: () {
    // Similar navigation logic
  },
  onActivitySuggestion: () {
    // Similar navigation logic
  },
)
```

#### 3. Screen Navigation
- **SpinWheelScreen:** `lib/screens/spin_wheel_screen.dart`
  - Shows animated wheel spinner
  - Displays selected contact card
  - Pop navigation on selection

- **ConversationStarterScreen:** `lib/screens/conversation_starter_screen.dart`
  - Shows random conversation prompt
  - Allows rating with thumb/star widgets
  - Pop navigation after rating

- **ActivitySuggestionScreen:** `lib/screens/activity_suggestion_screen.dart`
  - Shows activity suggestion with details
  - Allows rating and action buttons
  - Pop navigation after action

## Debugging Checklist

### Issue: Buttons Don't Appear
**Check:**
1. Are you on the Profile screen? (Bottom navigation → Profile tab)
2. Scroll down to see the "Featured features" section
3. **Root cause:** Buttons are conditionally displayed if callbacks are provided

**How to verify:**
```dart
// In app.dart ProfileScreen instantiation, check:
onSpinWheel: () { ... }  // Must not be null
onConversationStarter: () { ... }  // Must not be null
onActivitySuggestion: () { ... }  // Must not be null
```

### Issue: Buttons Appear But Don't Respond
**Check:**
1. Is the button actually tappable? (Should show visual feedback on press)
2. Check console for errors/exceptions
3. Verify the contacts list isn't empty (some screens require contacts)

**How to verify:**
```dart
// Check in app.dart that callbacks are properly defined
// Each callback should:
// 1. Check if contacts are empty (for some features)
// 2. Call Navigator.of(context).push() with a MaterialPageRoute
// 3. Provide correct screen constructor parameters
```

### Issue: App Crashes When Tapping Button
**Check:**
1. Look for exception in console/logs
2. Verify the screen being navigated to can be instantiated
3. Check that all required parameters are being passed

**Common issues:**
- Missing imports for the screen being navigated to
- Null context passed to Navigator
- Missing required parameters for the screen

### Issue: Button Appears But Opens Wrong Screen
**Check:**
1. Verify the callback is wired to the correct screen
2. Check file name matches: `onSpinWheel` → `SpinWheelScreen`, etc.
3. Verify imports in app.dart include all three screens

**Files to verify:**
- `lib/app.dart` - Import statements (lines 5-12)
- `lib/app.dart` - Callback implementation (lines 114-165)
- Screen files exist:
  - `lib/screens/spin_wheel_screen.dart`
  - `lib/screens/conversation_starter_screen.dart`
  - `lib/screens/activity_suggestion_screen.dart`

## Testing

### Unit Tests
**File:** `test/profile_screen_test.dart`

Tests verify:
1. Buttons are displayed when callbacks are provided
2. Buttons are hidden when callbacks are null
3. Button UI structure is correct

Run tests:
```bash
flutter test test/profile_screen_test.dart
```

### Manual Testing
**Steps:**
1. Run: `flutter run`
2. Navigate to Profile tab
3. Scroll to "Featured features"
4. Tap each button and verify:
   - Visual feedback on press
   - Correct screen loads
   - No console errors
   - Can navigate back with back button

## Related Components

### Services
- `lib/services/random_contact_service.dart` - Spin wheel logic
- `lib/services/conversation_starter_service.dart` - Prompt logic
- `lib/services/activity_suggestion_service.dart` - Activity logic

### Screens
- `lib/screens/spin_wheel_screen.dart` - Wheel UI
- `lib/screens/conversation_starter_screen.dart` - Prompt UI
- `lib/screens/activity_suggestion_screen.dart` - Activity UI

### Models
- `lib/models/conversation_starter.dart` - Prompt data
- `lib/models/activity_suggestion.dart` - Activity data
- `lib/models/spin_history.dart` - Spin tracking
- `lib/models/suggestion_rating.dart` - Rating data

## Verification Commands

```bash
# Check for syntax errors
flutter analyze

# Run tests
flutter test

# Run specific test
flutter test test/profile_screen_test.dart

# Check imports
grep -n "import.*spin_wheel_screen\|conversation_starter_screen\|activity_suggestion_screen" lib/app.dart

# Run app
flutter run
```

## Key Files Reference

| File | Purpose | Relevant Lines |
|------|---------|-----------------|
| `lib/app.dart` | Button callback definitions | 114-165 |
| `lib/screens/profile_screen.dart` | Button UI rendering | 114-136 |
| `lib/screens/profile_screen.dart` | ProfileScreen constructor | 6-29 |
| `lib/screens/spin_wheel_screen.dart` | Wheel screen implementation | - |
| `lib/screens/conversation_starter_screen.dart` | Prompt screen implementation | - |
| `lib/screens/activity_suggestion_screen.dart` | Activity screen implementation | - |
| `test/profile_screen_test.dart` | Button tests | - |

## Architecture Decisions

### Why callbacks in ProfileScreen?
- Keeps ProfileScreen as a stateless, reusable component
- Navigation logic centralized in app.dart
- Easy to test button behavior independently

### Why conditional rendering (if callback != null)?
- Allows ProfileScreen to be used in different contexts
- Enables flexible feature enablement/disablement
- Cleans UI if features aren't available

### Why use MaterialPageRoute?
- Standard Flutter navigation pattern
- Provides default platform-specific animations (slide on iOS, fade on Android)
- Easy to pop back with back button

## Future Enhancements
- [ ] Add navigation animations
- [ ] Add loading state while screens initialize
- [ ] Add error boundaries for screen failures
- [ ] Add analytics tracking for button taps
- [ ] Add feature flags for A/B testing
