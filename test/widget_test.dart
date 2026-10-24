import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reconnect/app.dart';
import 'package:reconnect/app_state.dart';
import 'package:reconnect/services/storage/session_store.dart';

void main() {
  testWidgets('Reconnect app boots to onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final appState = ReconnectAppState(sessionStore: InMemorySessionStore());
    addTearDown(appState.dispose);

    await tester.pumpWidget(ReconnectApp(appState: appState));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Welcome to Reconnect'), findsOneWidget);
    expect(find.text('Start onboarding'), findsOneWidget);
  });
}
