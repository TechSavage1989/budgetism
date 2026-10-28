import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'local_ledger_test.dart' show account, tx, category, accounts;

Json plan(String op, String categoryId, String month, int amount,
    {String rollover = 'none', int version = 0, bool upgrade = false}) => {
  'operationId': op, 'categoryId': categoryId, 'month': month, 'amountMinor': amount,
  'rollover': rollover, 'expectedVersion': version, 'confirmSchemaUpgrade': upgrade,
};
CategoryBudget row(LocalLedger ledger, String month, String categoryId) =>
  BudgetEngine.calculate(ledger.snapshot(), month).categories.singleWhere((c) => c.id == categoryId);

void main() {
  late LocalLedger ledger;
  late String groceries;
  late String housing;
  late String checking;
  setUp(() {
    ledger = LocalLedger.empty().apply('account', account('a', 'Checking', 1000000))
      .apply('account', account('b', 'Card', 0, type: 'credit_card'));
    final categories = LocalLedger.rows(ledger.data['categories']);
    groceries = categories.firstWhere((c) => c['name'] == 'Groceries')['id'] as String;
    housing = categories.firstWhere((c) => c['name'] == 'Housing')['id'] as String;
    checking = accounts(ledger).first['id'] as String;
  });
  void spend(String id, String date, int amount, {String? categoryId}) {
    ledger = ledger.apply('transaction', {...tx(id, 'expense', checking, categoryId ?? groceries, amount),
      'effectiveDate': date});
  }
  test('allocation is not a bank movement; actual expense consumes the budget', () {
    final before = jsonEncode(accounts(ledger));
    ledger = ledger.apply('budget', plan('plan', groceries, '2026-10', 40000));
    expect(jsonEncode(accounts(ledger)), before);
    expect(ledger.snapshot()['transactions'], isEmpty);
    spend('expense', '2026-10-27', 12500);
    final result = row(ledger, '2026-10', groceries);
    expect([result.allocated, result.carried, result.spent, result.remaining], [40000, 0, 12500, 27500]);
    expect(accounts(ledger).first['balanceMinor'], 987500);
  });
  test('positive carry gives 325 remaining for 400 allocation + 50 carry - 125 spent', () {
    ledger = ledger.apply('budget', plan('sep', groceries, '2026-09', 5000, rollover: 'positive'))
      .apply('budget', plan('oct', groceries, '2026-10', 40000, rollover: 'positive'));
    spend('grocery', '2026-10-01', 12500);
    final result = row(ledger, '2026-10', groceries);
    expect([result.carried, result.remaining, result.nextCarry], [5000, 32500, 32500]);
  });
  test('none, positive and all have distinct overspending carry behavior', () {
    for (final mode in LocalLedger.rolloverModes) {
      var l = ledger.apply('budget', plan('sep-$mode', groceries, '2026-09', 10000, rollover: mode));
      l = l.apply('transaction', {...tx('spend-$mode', 'expense', checking, groceries, 12000), 'effectiveDate': '2026-09-30'})
        .apply('budget', plan('oct-$mode', groceries, '2026-10', 10000));
      expect(row(l, '2026-10', groceries).carried, mode == 'all' ? -2000 : 0);
      expect(row(l, '2026-10', groceries).remaining, mode == 'all' ? 8000 : 10000);
    }
  });
  test('zero-allocation missing months consume carried funds without inventing budgets', () {
    ledger = ledger.apply('budget', plan('jan', groceries, '2026-01', 10000, rollover: 'all'));
    spend('feb-spending', '2026-02-01', 3000);
    final march = row(ledger, '2026-03', groceries);
    expect([march.allocated, march.carried, march.remaining], [0, 7000, 7000]);
    expect(march.hasAllocation, false);
    expect(row(ledger, '9999-12', groceries).carried, 7000); // Sparse, no 97,000-month loop.
  });
  test('spending before first plan is visible but does not invent historical debt', () {
    spend('early', '2026-01-01', 15000);
    ledger = ledger.apply('budget', plan('first', groceries, '2026-03', 10000, rollover: 'all'));
    expect(row(ledger, '2026-01', groceries).remaining, -15000);
    expect(row(ledger, '2026-03', groceries).carried, 0);
    expect(row(ledger, '2026-03', groceries).remaining, 10000);
  });
  test('unbudgeted categories remain in monthly totals; transfers and income are excluded', () {
    spend('unbudgeted', '2026-10-01', 4500, categoryId: housing);
    final card = accounts(ledger)[1]['id'] as String;
    ledger = ledger.apply('transaction', tx('payment', 'transfer', checking, card, 2500))
      .apply('transaction', tx('income', 'income', checking, category(ledger, 'Income'), 50000));
    final result = BudgetEngine.calculate(ledger.snapshot(), '2026-10');
    expect([result.allocated, result.spent, result.remaining, result.overBudgetCount], [0, 4500, -4500, 1]);
  });
  test('card purchase counts once; duplicate-category splits aggregate and drill down correctly', () {
    final card = accounts(ledger)[1]['id'] as String;
    ledger = ledger.apply('transaction', {...tx('purchase', 'expense', card, groceries, 10000), 'splits': [
      {'categoryId': groceries, 'amountMinor': 2000}, {'categoryId': groceries, 'amountMinor': 4000},
      {'categoryId': housing, 'amountMinor': 4000}]})
      .apply('transaction', tx('payment', 'transfer', checking, card, 10000));
    expect(row(ledger, '2026-10', groceries).spent, 6000);
    expect(row(ledger, '2026-10', housing).spent, 4000);
    final entries = BudgetEngine.transactionsFor(ledger.snapshot(), '2026-10', groceries);
    expect(entries.length, 1);
    expect(BudgetEngine.contribution(entries.single, groceries), 6000);
    expect(BudgetEngine.calculate(ledger.snapshot(), '2026-10').spent, 10000);
  });
  test('prior allocation/transaction edits and voids recalculate dependent rollover', () {
    ledger = ledger.apply('budget', plan('jan', groceries, '2026-01', 10000, rollover: 'all'))
      .apply('budget', plan('feb', groceries, '2026-02', 10000, rollover: 'all'));
    spend('old', '2026-01-10', 4000);
    expect(row(ledger, '2026-02', groceries).remaining, 16000);
    ledger = ledger.apply('budget', plan('edit-jan', groceries, '2026-01', 20000, rollover: 'all', version: 1));
    expect(row(ledger, '2026-02', groceries).remaining, 26000);
    final t = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('transaction', {...t, 'operationId': 'edit-transaction', 'expectedVersion': 1, 'amountMinor': 7000});
    expect(row(ledger, '2026-02', groceries).remaining, 23000);
    ledger = ledger.apply('void', {'operationId': 'void', 'id': t['id'], 'expectedVersion': 2});
    expect(row(ledger, '2026-02', groceries).remaining, 30000);
    expect(BudgetEngine.transactionsFor(ledger.snapshot(includeVoided: true), '2026-01', groceries), isEmpty);
  });
  test('moving a transaction to a different month/category reallocates spending', () {
    spend('old', '2026-01-31', 1000);
    final t = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('transaction', {...t, 'operationId': 'move', 'expectedVersion': 1,
      'effectiveDate': '2026-02-01', 'counterpartyAccountId': housing});
    expect(row(ledger, '2026-01', groceries).spent, 0);
    expect(row(ledger, '2026-02', housing).spent, 1000);
  });
  test('copy preserves existing plans unless replacement is explicitly selected', () {
    ledger = ledger.apply('budget', plan('dec-food', groceries, '2025-12', 10000, rollover: 'positive'))
      .apply('budget', plan('dec-house', housing, '2025-12', 20000))
      .apply('budget', plan('jan-food', groceries, '2026-01', 30000));
    spend('dec-spend', '2025-12-15', 1000);
    final transactions = jsonEncode(ledger.data['transactions']);
    final balances = jsonEncode(accounts(ledger));
    final copy = {'operationId': 'copy', 'month': '2026-01', 'expectedRevision': ledger.revision, 'replaceExisting': false};
    ledger = ledger.apply('budget-copy', copy);
    expect(row(ledger, '2026-01', groceries).allocated, 30000);
    expect(row(ledger, '2026-01', housing).allocated, 20000);
    expect(row(ledger, '2026-01', groceries).carried, 9000);
    expect(jsonEncode(ledger.data['transactions']), transactions);
    expect(jsonEncode(accounts(ledger)), balances);
    expect(identical(ledger.apply('budget-copy', copy), ledger), true);
    ledger = ledger.apply('budget-copy', {'operationId': 'replace', 'month': '2026-01',
      'expectedRevision': ledger.revision, 'replaceExisting': true});
    expect(row(ledger, '2026-01', groceries).allocated, 10000);
    expect(row(ledger, '2026-01', groceries).rollover, 'positive');
    expect(row(ledger, '2026-01', groceries).spent, 0);
  });
  test('copy stale revision and empty source fail without partial changes', () {
    ledger = ledger.apply('budget', plan('jan', groceries, '2026-01', 5000));
    final original = jsonEncode(ledger.data);
    expect(() => ledger.apply('budget-copy', {'operationId': 'bad-copy', 'month': '2026-02',
      'expectedRevision': 0, 'replaceExisting': false}), throwsFormatException);
    expect(() => ledger.apply('budget-copy', {'operationId': 'empty', 'month': '2026-01',
      'expectedRevision': ledger.revision, 'replaceExisting': false}), throwsFormatException);
    expect(jsonEncode(ledger.data), original);
  });
  test('removal retains audit, incoming carry and transactions, stops future carry', () {
    ledger = ledger.apply('budget', plan('jan', groceries, '2026-01', 10000, rollover: 'all'))
      .apply('budget', plan('feb', groceries, '2026-02', 20000, rollover: 'all'));
    spend('feb-spent', '2026-02-02', 5000);
    ledger = ledger.apply('budget-remove', {'operationId': 'remove', 'month': '2026-02',
      'categoryId': groceries, 'expectedVersion': 1});
    final feb = row(ledger, '2026-02', groceries);
    expect([feb.allocated, feb.carried, feb.spent, feb.remaining, feb.hasAllocation], [0, 10000, 5000, 5000, false]);
    expect(row(ledger, '2026-03', groceries).carried, 0);
    expect(LocalLedger.rows(ledger.data['audit']).last['before']['amountMinor'], 20000);
    expect(ledger.snapshot()['transactions'], hasLength(1));
  });
  test('strict months, zero allocations, bounds, categories and record versions', () {
    expect(LocalLedger.shiftMonth('2026-01', -1), '2025-12');
    expect(LocalLedger.shiftMonth('2024-02', 1), '2024-03');
    for (final month in ['2026-00', '2026-13', '2026-1', '1899-12', 'x', '2026-01-01']) {
      expect(() => ledger.apply('budget', plan('bad-month', groceries, month, 1)), throwsFormatException);
    }
    for (final amount in [-1, LocalLedger.maxMinor + 1]) {
      expect(() => ledger.apply('budget', plan('bad-amount', groceries, '2026-01', amount)), throwsFormatException);
    }
    expect(() => ledger.apply('budget', plan('income-plan', category(ledger, 'Income'), '2026-01', 100)), throwsFormatException);
    expect(() => ledger.apply('budget', plan('unknown', groceries, '2026-01', 100, rollover: 'anything')), throwsFormatException);
    final input = plan('zero', groceries, '2026-01', 0);
    ledger = ledger.apply('budget', input);
    expect(row(ledger, '2026-01', groceries).hasAllocation, true);
    expect(identical(ledger.apply('budget', input), ledger), true);
    expect(() => ledger.apply('budget', {...input, 'amountMinor': 1}), throwsFormatException);
    expect(() => ledger.apply('budget', plan('stale', groceries, '2026-01', 100)), throwsFormatException);
    expect(() => BudgetEngine.add(BudgetEngine.maxTotalMinor, 1), throwsFormatException);
    expect(() => BudgetEngine.add(-BudgetEngine.maxTotalMinor, -1), throwsFormatException);
  });
  test('first legacy budget requires confirmation and preserves all finance records', () {
    spend('prior', '2026-10-01', 777);
    final legacyData = LocalLedger.clone(ledger.data)..['schema'] = 1;
    legacyData.remove('budgets');
    final old = LocalLedger(legacyData);
    expect(old.data, legacyData);
    expect(() => old.apply('budget', plan('migration', groceries, '2026-10', 1000)), throwsFormatException);
    final updated = old.apply('budget', plan('migration', groceries, '2026-10', 1000, upgrade: true));
    expect(updated.data['schema'], LocalLedger.budgetSchema);
    expect(updated.data['accounts'], old.data['accounts']);
    expect(updated.data['categories'], old.data['categories']);
    expect(updated.data['transactions'], old.data['transactions']);
    expect(updated.revision, old.revision + 1);
    expect(() => LocalLedger({...updated.data, 'schema': 1}), throwsFormatException); // No unsafe downgrade.
    expect(old.data.containsKey('budgets'), false);
  });
  test('malformed budget records cannot be restored or silently accepted', () {
    ledger = ledger.apply('budget', plan('valid', groceries, '2026-10', 1000));
    final data = LocalLedger.clone(ledger.data);
    final b = (data['budgets'] as List).first as Map;
    b['categoryId'] = 'missing';
    expect(() => LocalLedger(data), throwsFormatException);
    final duplicate = LocalLedger.clone(ledger.data);
    (duplicate['budgets'] as List).add({...Map<String, dynamic>.from((duplicate['budgets'] as List).first as Map), 'id': 'different-id'});
    expect(() => LocalLedger(duplicate), throwsFormatException);
    final missing = LocalLedger.clone(ledger.data)..remove('budgets');
    expect(() => LocalLedger(missing), throwsFormatException);
  });
  test('month boundaries are based on calendar date, including leap years', () {
    spend('leap', '2024-02-29', 100);
    spend('march', '2024-03-01', 200);
    spend('dec', '2025-12-31', 300);
    spend('jan', '2026-01-01', 400);
    expect(row(ledger, '2024-02', groceries).spent, 100);
    expect(row(ledger, '2024-03', groceries).spent, 200);
    expect(row(ledger, '2025-12', groceries).spent, 300);
    expect(row(ledger, '2026-01', groceries).spent, 400);
  });
}
