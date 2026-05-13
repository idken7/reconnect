import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reconnect/app.dart';

void main() {
  testWidgets('Reconnect app boots to onboarding', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    await tester.pumpWidget(const ReconnectApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Welcome to Reconnect'), findsOneWidget);
    expect(find.text('Start onboarding'), findsOneWidget);
  });
}
