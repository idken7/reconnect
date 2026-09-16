import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reconnect/app_state.dart';
import 'package:reconnect/screens/onboarding_flow.dart';

void main() {
  testWidgets('starts on the welcome step', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final appState = ReconnectAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(MaterialApp(home: OnboardingFlow(appState: appState)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Reconnect with people you have not seen in a while.'), findsOneWidget);
    expect(find.text('Start onboarding'), findsOneWidget);
  });

  testWidgets('advances to the account creation step', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final appState = ReconnectAppState();
    addTearDown(appState.dispose);

    await tester.pumpWidget(MaterialApp(home: OnboardingFlow(appState: appState)));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Start onboarding'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
