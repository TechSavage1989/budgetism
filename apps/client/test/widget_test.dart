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
}
