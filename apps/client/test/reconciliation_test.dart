import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'csv_import_test.dart' show importBatch, createRow;
import 'schedule_matching_test.dart' show matchingFixture, matchRequest;

LocalLedger reconcileFixture() {
  var l = LocalLedger.empty().apply('account', account('account', 'Fictional statement', 100000));
  l = l.apply('transaction', tx('income', 'income', accounts(l).first['id'], category(l, 'Income'), 50000));
  return l.apply('transaction', tx('expense', 'expense', accounts(l).first['id'], category(l, 'Expense'), 20000));
}
Json statementRequest(LocalLedger l, {String operation = 'reconcile', String? accountId,
    List<String>? selected, int closing = 130000, String end = '2026-10-31'}) => {
  'operationId': operation, 'expectedRevision': l.revision,
  'accountId': accountId ?? accounts(l).first['id'], 'endDate': end, 'closingMinor': closing,
  'transactionIds': selected ?? LocalLedger.rows(l.data['transactions']).map((t) => t['id'] as String).toList(),
  'confirmReviewed': true, 'confirmReconciliationUpgrade': true, 'note': 'Fictional statement',
};
Json reopenRequest(LocalLedger l, Json s, {String operation = 'reopen'}) => {
  'operationId': operation, 'expectedRevision': l.revision, 'id': s['id'], 'expectedVersion': s['version'],
  'confirmReopen': true, 'reason': 'Correct fictional statement selection',
};
void main() {
  test('preview is read-only; completion preserves all financial values and requires exact consent', () {
    final l = reconcileFixture();
    final saved = jsonEncode(l.data);
    expect(Reconciliation.candidates(l.snapshot(), accounts(l).first['id'], '2026-10-31').length, 2);
    expect(jsonEncode(l.data), saved);
    expect(() => l.apply('reconcile', {...statementRequest(l), 'confirmReviewed': false}), throwsFormatException);
    expect(() => l.apply('reconcile', {...statementRequest(l), 'confirmReconciliationUpgrade': false}), throwsFormatException);
    expect(() => l.apply('reconcile', statementRequest(l, closing: 130001)), throwsFormatException);
    final result = l.apply('reconcile', statementRequest(l));
    expect(result.data['schema'], 5);
    for (final key in ['accounts', 'transactions', 'categories', 'budgets', 'schedules', 'occurrences']) {
      expect(result.data[key], l.data[key], reason: key);
    }
    expect(BudgetEngine.calculate(result.snapshot(), '2026-10').spent, 20000);
    expect(result.apply('reconcile', statementRequest(l)).data, result.data);
    expect(() => result.apply('reconcile', statementRequest(result, operation: 'duplicate')), throwsFormatException);
  });
  test('outstanding transactions carry to later statements; only latest can reopen', () {
    var l = reconcileFixture(); final rows = LocalLedger.rows(l.data['transactions']);
    l = l.apply('reconcile', statementRequest(l, selected: [rows.first['id']], closing: 150000));
    final first = Reconciliation.active(l.data, accounts(l).first['id']).single;
    expect(Reconciliation.candidates(l.data, accounts(l).first['id'], '2026-11-30').single['id'], rows.last['id']);
    l = l.apply('reconcile', statementRequest(l, operation: 'november', selected: [rows.last['id']], end: '2026-11-30'));
    expect(() => l.apply('reconcile-reopen', reopenRequest(l, first)), throwsFormatException);
    final latest = Reconciliation.active(l.data, accounts(l).first['id']).last;
    final originalBalances = accounts(l);
    l = l.apply('reconcile-reopen', reopenRequest(l, latest));
    expect(accounts(l), originalBalances); expect(Reconciliation.locked(l.data, rows.last['id']), isFalse);
    expect(Reconciliation.locked(l.data, rows.first['id']), isTrue);
    expect(Reconciliation.history(l.data, accounts(l).first['id']).length, 2);
    l = l.apply('reconcile', statementRequest(l, operation: 'correct-november', selected: [rows.last['id']], end: '2026-11-30'));
    expect(Reconciliation.active(l.data, accounts(l).first['id']).length, 2);
  });
  test('completed transactions and account opening cannot change until explicit reopen', () {
    var l = reconcileFixture(); l = l.apply('reconcile', statementRequest(l));
    final t = LocalLedger.rows(l.data['transactions']).first;
    final edit = {...t, 'operationId': 'edit', 'expectedVersion': t['version'], 'amountMinor': 60000};
    expect(() => l.apply('transaction', edit), throwsFormatException);
    expect(() => l.apply('void', {'operationId': 'void', 'id': t['id'], 'expectedVersion': t['version']}), throwsFormatException);
    final a = accounts(l).first;
    expect(() => l.apply('account', {...a, 'operationId': 'opening', 'expectedVersion': a['version'], 'openingBalanceMinor': 0}), throwsFormatException);
    l = l.apply('account', {...a, 'operationId': 'rename', 'expectedVersion': a['version'], 'name': 'Renamed'});
    l = l.apply('reconcile-reopen', reopenRequest(l, Reconciliation.active(l.data, a['id']).single));
    l = l.apply('transaction', edit);
    expect(accounts(l).first['balanceMinor'], 140000);
    LocalLedger(l.data);
  });
  test('signed card balance and both transfer sides reconcile independently and remain protected', () {
    var l = LocalLedger.empty().apply('account', account('checking', 'Checking', 100000))
      .apply('account', account('card', 'Card', -50000, type: 'credit_card'));
    final a = accounts(l); l = l.apply('transaction', tx('pay', 'transfer', a.first['id'], a.last['id'], 10000));
    l = l.apply('reconcile', statementRequest(l, closing: 90000));
    l = l.apply('reconcile', statementRequest(l, operation: 'card-statement', accountId: a.last['id'], closing: -40000));
    l = l.apply('reconcile-reopen', reopenRequest(l, Reconciliation.active(l.data, a.first['id']).single));
    final t = LocalLedger.rows(l.data['transactions']).single;
    expect(Reconciliation.locked(l.data, t['id']), isTrue);
    expect(() => l.apply('void', {'operationId': 'void', 'id': t['id'], 'expectedVersion': t['version']}), throwsFormatException);
  });
  test('reject stale reviews, future selections, duplicates and corrupted saved history', () {
    final l = reconcileFixture(); final request = statementRequest(l);
    expect(() => l.apply('reconcile', {...request, 'expectedRevision': 0}), throwsFormatException);
    expect(() => l.apply('reconcile', {...request, 'endDate': '2026-10-26'}), throwsFormatException);
    expect(() => l.apply('reconcile', {...request, 'transactionIds': [...request['transactionIds'], request['transactionIds'][0]]}), throwsFormatException);
    final done = l.apply('reconcile', request);
    for (final mutation in ['total', 'opening', 'posting', 'missing', 'duplicate']) {
      final d = LocalLedger.clone(done.data);
      if (mutation == 'total') d['reconciliations'][0]['closingMinor']++;
      if (mutation == 'opening') d['accounts'][0]['openingBalanceMinor']++;
      if (mutation == 'posting') d['reconciliations'][0]['entries'][0]['amountMinor']++;
      if (mutation == 'missing') d.remove('reconciliations');
      if (mutation == 'duplicate') d['reconciliations'].add(LocalLedger.clone(d['reconciliations'][0]));
      expect(() => LocalLedger(d), throwsFormatException, reason: mutation);
    }
    expect(() => done.apply('reconcile-reopen', {...reopenRequest(done, done.data['reconciliations'][0]), 'reason': ''}), throwsFormatException);
  });
  test('schema 1 through 4 migrate only on finish; imports and later schedules remain intact', () {
    for (final schema in [1, 2, 3, 4]) {
      final d = LocalLedger.clone(reconcileFixture().data); d['schema'] = schema;
      if (schema == 1) d.remove('budgets');
      if (schema < 3) { d.remove('schedules'); d.remove('occurrences'); }
      if (schema == 4) d['imports'] = <Json>[];
      var l = LocalLedger(d); expect(l.data['schema'], schema);
      l = l.apply('reconcile', statementRequest(l)); expect(l.data['schema'], 5);
      l = l.apply('import-csv', importBatch(l, [createRow(l)], operation: 'after-reconcile'));
      expect(l.data['schema'], 5); expect(l.data['reconciliations'].length, 1);
      expect(l.data['imports'].length, 1);
    }
    var l = matchingFixture(imported: true);
    l = l.apply('reconcile', statementRequest(l, closing: 98000));
    final imports = LocalLedger.clone(l.data)['imports'];
    l = l.apply('schedule-match', matchRequest(l, 'match-after-reconcile'));
    expect(l.data['schema'], 5); expect(l.data['imports'], imports);
    expect(Reconciliation.active(l.data, accounts(l).first['id']).length, 1);
  });
  test('zero-activity statements and exact integer limits', () {
    final l = LocalLedger.empty().apply('account', account('zero', 'Zero activity', 12345));
    final done = l.apply('reconcile', statementRequest(l, selected: [], closing: 12345));
    expect(done.data['transactions'], isEmpty);
    expect(Reconciliation.total(LocalLedger.maxMinor, [-LocalLedger.maxMinor, 1]), 1);
    expect(() => Reconciliation.total(LocalLedger.maxMinor, [1]), throwsFormatException);
  });
}
