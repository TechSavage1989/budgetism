import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/budget_widgets.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestStorage, TestDeviceKeys;

void main() {
  const category = <String, dynamic>{'id': 'groceries', 'name': 'Groceries', 'kind': 'Expense', 'currency': 'USD'};
  const row = CategoryBudget(category: category, plan: null, allocated: 0, carried: 0, spent: 0, remaining: 0, rollover: 'none');
  testWidgets('invalid precision is rejected inline and failed save retains entered amount', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BudgetEditorDialog(row: row,
      month: '2026-10', requiresUpgrade: false, onRemove: (_) async {}, onSave: (_) async {
        calls++; throw const FormatException('Budget changed. Refresh before editing.');
      }))));
    await tester.enterText(find.byKey(const ValueKey('budget-amount')), '0.001');
    await tester.tap(find.text('Save budget')); await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('two decimal places'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('budget-amount')), '400.00');
    await tester.tap(find.text('Save budget')); await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Budget changed.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('budget-amount'))).controller!.text, '400.00');
  });
  testWidgets('legacy upgrade needs confirmation and saves exact cents without floating point', (tester) async {
    Json? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<bool>(context: context, builder: (_) => BudgetEditorDialog(row: row,
        month: '2026-10', requiresUpgrade: true, onRemove: (_) async {}, onSave: (data) async { saved = data; })),
      child: const Text('Edit'))))));
    await tester.tap(find.text('Edit')); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('budget-amount')), '0.01');
    await tester.tap(find.text('Save budget')); await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.textContaining('Confirm the workspace format upgrade first.'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile)); await tester.pumpAndSettle();
    await tester.tap(find.text('Save budget')); await tester.pumpAndSettle();
    expect(saved!['amountMinor'], 1);
    expect(saved!['confirmSchemaUpgrade'], true);
    expect(saved!['expectedVersion'], 0);
    expect(find.byType(BudgetEditorDialog), findsNothing);
  });
  testWidgets('copy defaults to preserving existing allocations', (tester) async {
    Json? copied;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<bool>(context: context, builder: (_) => CopyBudgetsDialog(
        month: '2026-01', revision: 42, requiresUpgrade: false, onCopy: (data) async { copied = data; })),
      child: const Text('Copy'))))));
    await tester.tap(find.text('Copy')); await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, false);
    await tester.tap(find.text('Copy allocations')); await tester.pumpAndSettle();
    expect(copied!['replaceExisting'], false);
    expect(copied!['month'], '2026-01');
    expect(copied!['expectedRevision'], 42);
  });
  testWidgets('narrow layout and year-boundary navigation render without overflow', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late LocalVault vault;
    await tester.runAsync(() async {
      vault = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    });
    var month = '2026-01';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, setState) =>
      SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12), child: BudgetPanel(api: LocalFinanceApi(vault),
        month: month, onMonthChanged: (value) => setState(() => month = value),
        onChanged: () async {}, onOpenTransaction: (_) async {})))))));
    await tester.pumpAndSettle();
    expect(find.text('Monthly budgets'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('budget-previous'))); await tester.pumpAndSettle();
    expect(month, '2025-12');
    expect(find.text('December 2025'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('budget-next'))); await tester.pumpAndSettle();
    expect(month, '2026-01');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(vault.close);
  });
}
