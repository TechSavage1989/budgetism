import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/transaction_editor.dart';
import 'local_ledger_test.dart' show account, tx, category;

void main() {
  testWidgets('edit preserves values after failed save and accepts a successful retry', (tester) async {
    var ledger = LocalLedger.empty().apply('account', account('a', 'Checking', 10000));
    final accounts = LocalLedger.rows(ledger.snapshot()['accounts']);
    ledger = ledger.apply('transaction', tx('t', 'expense', accounts.first['id'], category(ledger, 'Expense'), 250));
    final transaction = LocalLedger.rows(ledger.snapshot()['transactions']).single;
    var fail = true;
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      child: const Text('Edit'), onPressed: () => showDialog<bool>(context: context,
        builder: (_) => LocalTransactionEditor(accounts: accounts,
          categories: LocalLedger.rows(ledger.data['categories']), existing: transaction,
          onSave: (data) async { saves++; if (fail) throw StateError('Disk unavailable'); ledger = ledger.apply('transaction', data); })))))));
    await tester.tap(find.text('Edit')); await tester.pumpAndSettle();
    expect(find.text('2.50'), findsOneWidget);
    await tester.tap(find.text('Save transaction')); await tester.pumpAndSettle();
    expect(find.textContaining('Disk unavailable'), findsOneWidget);
    expect(find.text('2.50'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Save transaction')); await tester.pumpAndSettle();
    expect(saves, 2);
    expect(ledger.revision, 3);
    expect(find.text('Edit transaction'), findsNothing);
  });
}
