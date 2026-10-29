import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Budgetism welcome screen offers a sample-data demo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BudgetismApp());
    await tester.pump();

    expect(find.text('Explore with sample data'), findsOneWidget);

    // Dispose the app to cancel its periodic update timer.
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('server connection rejects plaintext before asking for credentials', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BudgetismApp()); await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Private server URL'), 'http://fictional.example');
    await tester.tap(find.text('Connect to server')); await tester.pump();
    expect(find.text('Use a trusted private HTTPS server URL.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
