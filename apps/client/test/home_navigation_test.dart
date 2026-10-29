import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/main.dart' show FinanceShell;
import 'package:budgetism/local/budget_widgets.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;

void main() {
  testWidgets('Home current-month budget shortcut overrides only the session month without financial writes', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final storage = TestStorage(); late LocalVault vault;
    await tester.runAsync(() async {
      vault = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    });
    final before = jsonEncode(vault.ledger.data), encrypted = storage.saved;
    final month = DateTime.now().toIso8601String().substring(0, 7);
    Finder navigation(String text) => find.descendant(of: find.byType(NavigationRail), matching: find.text(text));
    try {
      await tester.pumpWidget(MaterialApp(home: FinanceShell(api: LocalFinanceApi(vault), username: 'Fictional',
        onLogout: () {}, onToggleTheme: () {}, onCheckUpdates: () {})));
      await tester.pumpAndSettle();
      await tester.tap(navigation('Budgets')); await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('budget-previous'))); await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('budget-previous'))); await tester.pumpAndSettle();
      expect(tester.widget<BudgetPanel>(find.byType(BudgetPanel)).month, LocalLedger.shiftMonth(month, -1));
      await tester.tap(navigation('Home')); await tester.pumpAndSettle();
      await tester.tap(navigation('Budgets')); await tester.pumpAndSettle();
      expect(tester.widget<BudgetPanel>(find.byType(BudgetPanel)).month, LocalLedger.shiftMonth(month, -1));
      await tester.tap(navigation('Home')); await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open budgets')); await tester.pumpAndSettle();
      await tester.tap(find.text('Open budgets')); await tester.pumpAndSettle();
      expect(tester.widget<BudgetPanel>(find.byType(BudgetPanel)).month, month);
      expect(jsonEncode(vault.ledger.data), before); expect(storage.saved, encrypted);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(() => vault.close());
    }
  });
}
