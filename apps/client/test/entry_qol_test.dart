import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/entry_controls.dart';
import 'package:budgetism/local/transaction_editor.dart';
import 'package:budgetism/local/daily_workspace.dart';
import 'local_ledger_test.dart' show account, accounts, category, tx;

LocalLedger entryFixture() => LocalLedger.empty()
  .apply('account', account('one', 'Fictional checking', 100000))
  .apply('account', account('two', 'Fictional savings', 0));

Future<void> entryVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder); await tester.pumpAndSettle();
}
Future<void> entryText(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(Key(key)); await entryVisible(tester, finder);
  await tester.enterText(finder, value); await tester.pumpAndSettle();
}
Future<void> openEntry(WidgetTester tester, LocalLedger ledger, Future<void> Function(Json) save, {Json? existing}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
    onPressed: () => showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => LocalTransactionEditor(
      accounts: accounts(ledger), categories: LocalLedger.rows(ledger.data['categories']),
      history: LocalLedger.rows(ledger.data['transactions']), existing: existing, onSave: save)), child: const Text('Open entry'))))));
  await tester.tap(find.text('Open entry')); await tester.pumpAndSettle();
}
Future<void> pickEntryChoice(WidgetTester tester, String key, String search, String id) async {
  await entryVisible(tester, find.byKey(Key(key))); await tester.tap(find.byKey(Key(key))); await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('choice-query')), search); await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('choice-$id'))); await tester.pumpAndSettle();
}
void main() {
  test('payee suggestions are bounded, deterministic, detached and type-specific', () {
    final history = <Json>[
      for (var i = 0; i < 12; i++) {'id': '$i', 'kind': 'expense', 'payee': 'Fictional shop $i', 'effectiveDate': '2026-10-27', 'voided': false},
      {'id': 'new', 'kind': 'expense', 'payee': 'FICTIONAL SHOP 1', 'effectiveDate': '2026-10-28', 'voided': false},
      {'id': 'void', 'kind': 'expense', 'payee': 'Fictional voided', 'effectiveDate': '2026-10-29', 'voided': true},
      {'id': 'income', 'kind': 'income', 'payee': 'Fictional employer', 'effectiveDate': '2026-10-29', 'voided': false},
    ];
    final before = jsonEncode(history), result = PayeeSuggestions.find(history, 'fiCTional', 'expense');
    expect(result.length, 8); expect(result.first, 'FICTIONAL SHOP 1');
    expect(result.where((x) => x.toLowerCase() == 'fictional shop 1').length, 1);
    expect(result, isNot(contains('Fictional voided'))); expect(result, isNot(contains('Fictional employer')));
    expect(PayeeSuggestions.find(history, '', 'expense'), isEmpty);
    expect(PayeeSuggestions.find(history, 'fictional', 'transfer'), isEmpty);
    expect(PayeeSuggestions.find(history, 'fictional', 'income'), ['Fictional employer']);
    result.clear(); expect(jsonEncode(history), before);
  });

  test('Home reuses exact historical reports and excludes future/voided entries without writes', () {
    var ledger = entryFixture(); final a = accounts(ledger);
    ledger = ledger.apply('transaction', tx('income', 'income', a.first['id'], category(ledger, 'Income'), 50000));
    ledger = ledger.apply('transaction', tx('expense', 'expense', a.first['id'], category(ledger, 'Expense'), 20000));
    ledger = ledger.apply('transaction', tx('transfer', 'transfer', a.first['id'], a.last['id'], 5000));
    ledger = ledger.apply('transaction', {...tx('future', 'expense', a.first['id'], category(ledger, 'Expense'), 1000), 'effectiveDate': '2026-10-30'});
    final before = jsonEncode(ledger.data);
    final summary = DailyHomeSummary(ledger.snapshot(), DateTime(2026, 10, 29));
    expect(summary.report.closing, 130000); expect(summary.assets, 130000); expect(summary.report.expense, 20000);
    expect(summary.futureCount, 1); expect(summary.transactions.length, 3);
    expect(summary.transactions.any((t) => t['effectiveDate'] == '2026-10-30'), isFalse);
    summary.transactions.first['payee'] = 'Changed detached result'; expect(jsonEncode(ledger.data), before);
    expect(DailyHomeSummary(LocalLedger.empty().snapshot(), DateTime(2026, 10, 29)).report.closing, 0);
  });

  testWidgets('searchable choices cancel without changing identity and accept only a selected result', (tester) async {
    var value = 'a', calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(builder: (context, update) => SearchableFinanceChoice(
      key: const Key('selector'), label: 'Category', value: value, options: const {'a': 'Other spending', 'b': 'Groceries'},
      onChanged: (id) => update(() { value = id; calls++; }))))));
    await tester.tap(find.byKey(const Key('selector'))); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('choice-query')), 'missing'); await tester.pumpAndSettle();
    expect(find.text('No matches. Change the search.'), findsOneWidget);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(value, 'a'); expect(calls, 0);
    await pickEntryChoice(tester, 'selector', 'groc', 'b'); expect(value, 'b'); expect(calls, 1);
    expect(find.byKey(const Key('choice-query')), findsNothing);
  });

  testWidgets('payee completion changes only text and never copies financial fields or saves', (tester) async {
    var ledger = entryFixture();
    ledger = ledger.apply('transaction', {...tx('prior', 'expense', accounts(ledger).first['id'], category(ledger, 'Expense'), 999), 'payee': 'Fictional shop'});
    final before = jsonEncode(ledger.data); var calls = 0;
    await openEntry(tester, ledger, (_) async { calls++; });
    await entryText(tester, 'entry-amount', '12.34'); await entryText(tester, 'entry-payee', 'Fictional');
    expect(find.byKey(const ValueKey('payee-option-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payee-option-0'))); await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('entry-payee'))).controller!.text, 'Fictional shop');
    expect(tester.widget<TextField>(find.byKey(const Key('entry-amount'))).controller!.text, '12.34');
    expect(calls, 0); expect(jsonEncode(ledger.data), before);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(calls, 0);
  });

  testWidgets('save another retains failed requests then clears fields and uses a new identity for each successful entry', (tester) async {
    var ledger = entryFixture(), fail = true; final sent = <Json>[];
    await openEntry(tester, ledger, (input) async {
      sent.add(LocalLedger.clone(input)); final next = ledger.apply('transaction', input);
      if (fail) throw StateError('Disk unavailable'); ledger = next;
    });
    final groceries = category(ledger, 'Expense');
    await pickEntryChoice(tester, 'entry-category', 'Groceries', groceries);
    await entryText(tester, 'entry-amount', '1.25'); await entryText(tester, 'entry-payee', 'First fictional purchase');
    await entryText(tester, 'entry-notes', 'Only first entry');
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle();
    expect(ledger.data['transactions'], isEmpty); expect(find.textContaining('Disk unavailable'), findsOneWidget);
    fail = false; await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle();
    expect(sent[0], sent[1]); expect(ledger.data['transactions'].length, 1);
    for (final key in ['entry-amount', 'entry-payee', 'entry-notes']) {
      expect(tester.widget<TextField>(find.byKey(Key(key))).controller!.text, '');
    }
    expect(tester.widget<SearchableFinanceChoice>(find.byKey(const Key('entry-category'))).value, groceries);
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle(); expect(sent.length, 2);
    await entryText(tester, 'entry-amount', '2.75');
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle();
    expect(sent.last['operationId'], isNot(sent.first['operationId']));
    expect(ledger.data['transactions'].length, 2); expect(accounts(ledger).first['balanceMinor'], 99600);
    expect(LocalLedger.rows(ledger.data['transactions']).last['notes'], '');
    await tester.tap(find.text('Close')); await tester.pumpAndSettle();
    expect(find.byType(LocalTransactionEditor), findsNothing); expect(ledger.data['transactions'].length, 2);
  });

  testWidgets('save another is single-flight and unavailable while editing an existing entry', (tester) async {
    var ledger = entryFixture(); var calls = 0; final complete = Completer<void>();
    await openEntry(tester, ledger, (input) async { calls++; await complete.future; ledger = ledger.apply('transaction', input); });
    await entryText(tester, 'entry-amount', '1.00');
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pump();
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('entry-save-another'))).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.byKey(const Key('entry-save'))).onPressed, isNull);
    expect(calls, 1); complete.complete(); await tester.pumpAndSettle();
    await tester.tap(find.text('Close')); await tester.pumpAndSettle();
    await openEntry(tester, ledger, (_) async { calls++; }, existing: LocalLedger.rows(ledger.data['transactions']).single);
    expect(find.byKey(const Key('entry-save-another')), findsNothing);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(calls, 1);
  });

  testWidgets('transfer destinations must be chosen and are not copied into the next entry', (tester) async {
    var ledger = entryFixture(); var calls = 0;
    await openEntry(tester, ledger, (input) async { calls++; ledger = ledger.apply('transaction', input); });
    await tester.tap(find.byKey(const Key('entry-kind'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer / card payment').last); await tester.pumpAndSettle();
    await entryText(tester, 'entry-amount', '1.00');
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle(); expect(calls, 0);
    await pickEntryChoice(tester, 'entry-category', 'savings', accounts(ledger).last['id']);
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle(); expect(calls, 1);
    expect(tester.widget<SearchableFinanceChoice>(find.byKey(const Key('entry-category'))).value, isNull);
    await entryText(tester, 'entry-amount', '1.00');
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle(); expect(calls, 1);
    expect(accounts(ledger).fold<int>(0, (s, a) => s + (a['balanceMinor'] as int)), 100000);
  });

  testWidgets('successful split is balanced and the next entry does not inherit split allocations', (tester) async {
    var ledger = entryFixture();
    await openEntry(tester, ledger, (input) async { ledger = ledger.apply('transaction', input); });
    await entryText(tester, 'entry-amount', '3.00');
    await entryVisible(tester, find.byKey(const Key('entry-split'))); await tester.tap(find.byKey(const Key('entry-split'))); await tester.pumpAndSettle();
    await entryText(tester, 'entry-split-amount-0', '1.00'); await entryText(tester, 'entry-split-amount-1', '2.00');
    await tester.tap(find.byKey(const Key('entry-save-another'))); await tester.pumpAndSettle();
    expect(LocalLedger.rows(ledger.data['transactions']).single['splits'].length, 2);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('entry-split'))).value, isFalse);
    expect(find.byKey(const Key('entry-split-amount-0')), findsNothing); expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 1100.0]) {
    testWidgets('entry and searchable selector fit $width pixels without saving', (tester) async {
      tester.view.physicalSize = Size(width, 850); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0; final ledger = entryFixture();
      await openEntry(tester, ledger, (_) async { calls++; });
      await pickEntryChoice(tester, 'entry-account', 'savings', accounts(ledger).last['id']);
      await entryText(tester, 'entry-payee', 'Fictional new payee');
      await entryText(tester, 'entry-notes', 'Fictional note');
      expect(tester.takeException(), isNull); expect(calls, 0);
      await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(calls, 0);
    });
  }
}
