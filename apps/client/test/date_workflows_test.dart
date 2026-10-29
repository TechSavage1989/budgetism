import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/date_controls.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/schedule_widgets.dart';
import 'package:budgetism/local/schedules.dart';
import 'package:budgetism/local/reconciliation_widgets.dart';
import 'package:budgetism/local/transaction_register.dart';
import 'package:budgetism/local/transaction_register_widgets.dart';
import 'package:budgetism/local/category_rule_widgets.dart';
import 'package:budgetism/local/transaction_editor.dart';
import 'local_ledger_test.dart' show accounts;
import 'category_rules_test.dart' show rulesFixture, ruleRequest;
import 'category_rule_widgets_test.dart' show preview, reveal;
import 'reconciliation_test.dart' show reconcileFixture;
import 'date_controls_test.dart' show tapDateDay;

void main() {
  const account = <String, dynamic>{'id': 'checking', 'name': 'Fictional checking'};
  const category = <String, dynamic>{'id': 'food', 'name': 'Fictional food', 'kind': 'Expense'};
  final schedule = <String, dynamic>{'id': 'schedule', 'name': 'Fictional bill', 'kind': 'expense',
    'accountId': 'checking', 'counterpartyAccountId': 'food', 'amountMinor': 2000, 'currency': 'USD',
    'notes': '', 'payee': 'Test', 'frequency': 'monthly', 'startDate': '2026-10-10', 'endDate': null,
    'version': 1, 'paused': false};

  testWidgets('schedule calendars fill controls only; optional end date clears; existing anchors stay locked', (tester) async {
    var writes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScheduleEditor(accounts: const [account],
      categories: const [category], requiresUpgrade: false, onSave: (_) async { writes++; }))));
    final start = find.byKey(const ValueKey('schedule-start'));
    await tester.ensureVisible(start); await tester.enterText(start, '2026-10-10'); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose date: First due date (YYYY-MM-DD)')); await tester.pumpAndSettle();
    await tapDateDay(tester, '15');
    expect(tester.widget<TextField>(start).controller!.text, '2026-10-15'); expect(writes, 0);
    final end = find.byKey(const ValueKey('schedule-end'));
    await tester.ensureVisible(end); await tester.enterText(end, '2026-10-20'); await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choose date: Last scheduled date (optional, YYYY-MM-DD)')); await tester.pumpAndSettle();
    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate, DateTime(2026, 10, 15));
    await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear: Last scheduled date (optional, YYYY-MM-DD)')); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(end).controller!.text, ''); expect(writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScheduleEditor(accounts: const [account],
      categories: const [category], existing: schedule, requiresUpgrade: false, onSave: (_) async { writes++; }))));
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-start')));
    final controls = find.descendant(of: find.byType(FinanceDateField), matching: find.byType(IconButton));
    for (final button in tester.widgetList<IconButton>(controls)) { expect(button.onPressed, isNull); }
    expect(writes, 0); expect(tester.takeException(), isNull);
  });

  testWidgets('postponement calendar only offers dates after the original due date', (tester) async {
    var writes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OccurrenceDialog(
      occurrence: ScheduledOccurrence(schedule, 0, '2026-10-10', null), action: 'postpone',
      onSave: (_) async { writes++; }))));
    await tester.tap(find.byTooltip('Choose date: New due date (YYYY-MM-DD)')); await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, DateTime(2026, 10, 11)); expect(picker.initialDate, DateTime(2026, 10, 11));
    await tapDateDay(tester, '15');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('occurrence-date'))).controller!.text, '2026-10-15');
    expect(writes, 0);
  });

  testWidgets('statement calendar cannot change the frozen reviewed date or write finance data', (tester) async {
    final ledger = reconcileFixture();
    final before = LocalLedger.clone(ledger.data); var writes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatementReview(snapshot: ledger.snapshot(),
      accountId: accounts(ledger).first['id'], onSave: (_) async { writes++; }))));
    await tester.enterText(find.byKey(const ValueKey('statement-date')), '2026-10-10');
    await tester.tap(find.byTooltip('Choose date: Statement ending date (YYYY-MM-DD)')); await tester.pumpAndSettle();
    await tapDateDay(tester, '31');
    await tester.enterText(find.byKey(const ValueKey('statement-closing')), '1300.00');
    await tester.ensureVisible(find.text('Review statement')); await tester.tap(find.text('Review statement')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('statement-date'))); await tester.pumpAndSettle();
    final field = find.ancestor(of: find.byKey(const ValueKey('statement-date')), matching: find.byType(FinanceDateField));
    for (final button in tester.widgetList<IconButton>(find.descendant(of: field, matching: find.byType(IconButton)))) {
      expect(button.onPressed, isNull);
    }
    expect(writes, 0); expect(ledger.data, before);
  });

  testWidgets('register preset changes both endpoints once while retaining other filters and financial data', (tester) async {
    final ledger = rulesFixture(), changes = <RegisterFilter>[];
    final before = LocalLedger.clone(ledger.data);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TransactionRegisterPanel(
      readSnapshot: () => ledger.snapshot(), initialFilter: const RegisterFilter(query: 'Corner', kind: 'expense'),
      onFilterChanged: changes.add)))));
    final preset = find.text('Last 7 days');
    await tester.ensureVisible(preset); await tester.tap(preset); await tester.pumpAndSettle();
    final expected = FinanceDates.preset('Last 7 days', DateTime.now());
    expect(changes.length, 1); expect(changes.single.from, expected.$1); expect(changes.single.through, expected.$2);
    expect(changes.single.query, 'Corner'); expect(changes.single.kind, 'expense');
    await tester.tap(find.text('All dates')); await tester.pumpAndSettle();
    expect(changes.last.from, ''); expect(changes.last.through, ''); expect(changes.last.query, 'Corner');
    expect(ledger.data, before); expect(tester.takeException(), isNull);
  });

  testWidgets('calendar change invalidates category suggestions and review without applying rules', (tester) async {
    var ledger = rulesFixture(); ledger = ledger.apply('category-rule', ruleRequest(ledger));
    final before = LocalLedger.clone(ledger.data); var writes = 0;
    await tester.pumpWidget(MaterialApp(home: CategoryRulesPage(snapshot: () => ledger.snapshot(),
      onSave: (_) async { writes++; }, onApply: (_) async { writes++; })));
    await preview(tester);
    await reveal(tester, find.byKey(const Key('rules-review')));
    expect(find.byKey(const Key('rules-review')), findsOneWidget);
    await reveal(tester, find.byTooltip('Choose date: Through (YYYY-MM-DD)'));
    await tester.tap(find.byTooltip('Choose date: Through (YYYY-MM-DD)')); await tester.pumpAndSettle();
    await tapDateDay(tester, '15');
    expect(find.byKey(const Key('rules-review')), findsNothing);
    expect(writes, 0); expect(ledger.data, before);
  });

  testWidgets('transaction calendar supports saved years after 2100 and cancels without edits', (tester) async {
    final ledger = rulesFixture();
    final existing = {...LocalLedger.rows(ledger.data['transactions']).single, 'effectiveDate': '2150-10-10'};
    var writes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LocalTransactionEditor(
      accounts: LocalLedger.rows(ledger.snapshot()['accounts']), categories: LocalLedger.rows(ledger.data['categories']),
      existing: existing, onSave: (_) async { writes++; }))));
    await tester.ensureVisible(find.text('2150-10-10'));
    await tester.tap(find.text('2150-10-10')); await tester.pumpAndSettle();
    expect(tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).initialDate, DateTime(2150, 10, 10));
    await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(find.text('2150-10-10'), findsOneWidget); expect(writes, 0); expect(tester.takeException(), isNull);
  });
}
