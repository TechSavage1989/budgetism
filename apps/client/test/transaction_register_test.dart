import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/transaction_register.dart';
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'reports_test.dart' show reportFixture;
import 'reconciliation_test.dart' show statementRequest, reopenRequest;
import 'csv_import_test.dart' show importBatch, importRow;
import 'schedule_matching_test.dart' show matchingFixture, matchRequest;
import 'category_rules_test.dart' show ruleRequest, categorizeRequest;

RegisterResult registerFor(LocalLedger ledger, [RegisterFilter filter = const RegisterFilter()]) =>
  TransactionRegister.calculate(ledger.snapshot(includeVoided: true), filter);

void main() {
  test('read-only register counts all actual records including future dates, not schedules or opening balances', () {
    final ledger = reportFixture(), before = jsonEncode(ledger.data);
    final result = registerFor(ledger);
    expect(result.entries.length, 6); expect(result.income, 60000); expect(result.expenses, 23000);
    expect(result.transfers, 13000); expect(result.voidedCount, 0);
    final historical = registerFor(ledger, const RegisterFilter(through: '2026-10-28'));
    expect(historical.entries.length, 5); expect(historical.income, 50000);
    expect(jsonEncode(ledger.data), before);
    expect(registerFor(ledger, const RegisterFilter(from: '2026-11-01', through: '2026-11-01')).entries.length, 1);
  });

  test('combined filters select split contributions but whole amount filtering and sorting remain explicit', () {
    final ledger = reportFixture(), accountId = accounts(ledger).first['id'] as String;
    final cats = LocalLedger.rows(ledger.data['categories']).where((c) => c['kind'] == 'Expense').toList();
    final filter = RegisterFilter(accountId: accountId, categoryId: cats[1]['id'], kind: 'expense',
      minimum: '200.00', maximum: '200', from: '2026-10-27', through: '2026-10-27', query: '"test payee" housing -savings');
    final result = registerFor(ledger, filter);
    expect(result.entries.single.amount, 20000); expect(result.expenses, 14000);
    expect(result.entries.single.contributions[cats[1]['id']], 14000);
    expect(result.income, 0); expect(result.transfers, 0);
    expect(registerFor(ledger, filter.copyWith(maximum: '140', minimum: '')).entries, isEmpty);
    expect(registerFor(ledger, filter.copyWith(kind: 'transfer')).entries, isEmpty);
  });

  test('search words, exact phrases and exclusions match across fields without executing patterns', () {
    var ledger = LocalLedger.empty().apply('account', account('checking', 'Fictional checking', 0));
    final a = accounts(ledger).first['id'], c = category(ledger, 'Expense');
    for (final p in ['Fictional Corner Shop', 'Fictional Hardware Shop', 'Literal .* Merchant']) {
      ledger = ledger.apply('transaction', {...tx(p, 'expense', a, c, 100), 'payee': p, 'notes': 'Monthly household'});
    }
    expect(registerFor(ledger, const RegisterFilter(query: 'corner household checking groceries')).entries.single.payee, 'Fictional Corner Shop');
    expect(registerFor(ledger, const RegisterFilter(query: '"corner shop" -hardware')).entries.length, 1);
    expect(registerFor(ledger, const RegisterFilter(query: 'shop -"corner shop"')).entries.single.payee, 'Fictional Hardware Shop');
    expect(registerFor(ledger, const RegisterFilter(query: '.*')).entries.single.payee, 'Literal .* Merchant');
    expect(registerFor(ledger, const RegisterFilter(query: '"shop monthly"')).entries, isEmpty);
    expect(registerFor(ledger, const RegisterFilter(query: '-hardware')).entries.length, 2);
    expect(registerFor(ledger, const RegisterFilter(query: '  CORNER   "Shop" ')).entries.length, 1);
    for (final q in ['"unclosed', '""', '-', '- word', 'word"phrase"', '"word"suffix', List.filled(33, 'x').join(' '), List.filled(501, 'x').join()]) {
      expect(() => registerFor(ledger, RegisterFilter(query: q)), throwsFormatException, reason: q);
    }
  });

  test('amount/date limits validate exactly and unavailable selections fail without broadening scope', () {
    final ledger = reportFixture(), before = jsonEncode(ledger.data);
    for (final filter in <RegisterFilter>[
      const RegisterFilter(minimum: '0', maximum: '0'),
      const RegisterFilter(minimum: '1,000.00'),
      const RegisterFilter(from: '2024-02-29', through: '2024-03-01'),
    ]) { expect(registerFor(ledger, filter).entries, isEmpty); }
    for (final filter in <RegisterFilter>[
      const RegisterFilter(from: '2026-02-30'), const RegisterFilter(from: '2026-11-01', through: '2026-10-01'),
      const RegisterFilter(minimum: '1.001'), const RegisterFilter(minimum: '-1'), const RegisterFilter(minimum: 'NaN'),
      const RegisterFilter(minimum: '1,00'), const RegisterFilter(minimum: '1e3'), const RegisterFilter(maximum: '1000000000000'),
      const RegisterFilter(minimum: '2', maximum: '1'), const RegisterFilter(accountId: 'missing'),
      const RegisterFilter(categoryId: 'missing'), const RegisterFilter(kind: 'unsupported'),
      const RegisterFilter(status: 'pending'), const RegisterFilter(source: 'bank-api'), const RegisterFilter(sort: 'random'),
    ]) { expect(() => registerFor(ledger, filter), throwsFormatException); }
    expect(jsonEncode(ledger.data), before);
  });

  test('transfer receipt and reconciliation filters refer to the selected side, without weakening global edit locks', () {
    var ledger = LocalLedger.empty().apply('account', account('from', 'Fictional checking', 100000))
      .apply('account', account('to', 'Fictional savings', 0));
    final a = accounts(ledger); final source = a[0]['id'] as String, target = a[1]['id'] as String;
    ledger = ledger.apply('transaction', tx('transfer', 'transfer', source, target, 10000));
    final t = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('import-csv', importBatch(ledger,
      [{...importRow(signed: -10000), 'action': 'match', 'transactionId': t['id']}], accountId: source));
    ledger = ledger.apply('reconcile', statementRequest(ledger, accountId: source, closing: 90000));
    expect(registerFor(ledger, const RegisterFilter(source: 'statement', status: 'reconciled')).entries.length, 1);
    final destination = registerFor(ledger, RegisterFilter(accountId: target, status: 'unreconciled', source: 'unlinked'));
    expect(destination.entries.length, 1); expect(destination.transfers, 10000);
    expect(destination.entries.single.canEdit, isFalse); expect(destination.entries.single.reconciledInScope, isFalse);
    expect(registerFor(ledger, RegisterFilter(accountId: target, status: 'reconciled')).entries, isEmpty);
    expect(registerFor(ledger, RegisterFilter(accountId: target, source: 'statement')).entries, isEmpty);
    expect(destination.income, 0); expect(destination.expenses, 0);
    ledger = ledger.apply('reconcile-reopen', reopenRequest(ledger, Reconciliation.active(ledger.data, source).single));
    expect(registerFor(ledger).entries.single.canEdit, isTrue);
    expect(registerFor(ledger, const RegisterFilter(status: 'reconciled')).entries, isEmpty);
    expect(registerFor(ledger, const RegisterFilter(source: 'statement')).entries.length, 1);
  });

  test('voided entries are inspectable but never contribute to totals or edit eligibility', () {
    final ledger = reportFixture();
    final all = registerFor(ledger, const RegisterFilter(status: 'all'));
    expect(all.entries.length, 7); expect(all.voidedCount, 1); expect(all.expenses, 23000);
    final voided = registerFor(ledger, const RegisterFilter(status: 'voided'));
    expect(voided.entries.single.canEdit, isFalse); expect(voided.expenses, 0);
    expect(voided.entries.single.amount, 5000); expect(voided.voidedCount, 1);
  });

  test('all sorts have stable identifier tie-breaks and filtering never truncates 101 matching rows', () {
    final snapshot = reportFixture().snapshot(includeVoided: true);
    final seed = LocalLedger.rows(snapshot['transactions']).first;
    snapshot['transactions'] = [for (var i = 0; i < 101; i++) {...seed, 'id': 'id-${i.toString().padLeft(3, '0')}',
      'amountMinor': (i + 1) * 100, 'payee': i.isEven ? 'Alpha' : 'Beta', 'effectiveDate': i < 50 ? '2026-10-01' : '2026-10-02'}];
    RegisterResult read(String sort) => TransactionRegister.calculate(snapshot, RegisterFilter(sort: sort));
    expect(read('newest').entries.length, 101); expect(read('newest').entries.first.id, 'id-050');
    expect(read('oldest').entries.first.id, 'id-000'); expect(read('largest').entries.first.amount, 10100);
    expect(read('smallest').entries.first.amount, 100); expect(read('payee').entries.first.id, 'id-050');
    expect(read('newest').income, 515100);
    final before = read('newest').entries.map((e) => e.id).toList();
    snapshot['transactions'] = (snapshot['transactions'] as List).reversed.toList();
    expect(read('newest').entries.map((e) => e.id).toList(), before);
  });

  test('results are detached, rules and matched links remain intact, and no schema is upgraded', () {
    var ledger = matchingFixture(imported: true); ledger = ledger.apply('schedule-match', matchRequest(ledger, 'match'));
    ledger = ledger.apply('category-rule', ruleRequest(ledger, pattern: 'fictional', source: 'statement'));
    ledger = ledger.apply('categorize', categorizeRequest(ledger));
    final before = jsonEncode(ledger.data), result = registerFor(ledger);
    final entry = result.entries.single;
    expect(entry.scheduleName, isNotNull); expect(entry.receipts.length, 1);
    expect(entry.statementLinkedInScope, isTrue); expect(entry.canEdit, isTrue);
    entry.transaction['payee'] = 'Changed copy'; entry.receipts.single['fileName'] = 'Changed copy';
    expect(() => result.entries.clear(), throwsUnsupportedError);
    expect(() => entry.contributions.clear(), throwsUnsupportedError);
    expect(jsonEncode(ledger.data), before); expect(entry.payee, isNot('Changed copy'));
    expect(entry.receipts.single['fileName'], isNot('Changed copy'));
    for (final schema in [1, 2, 3, 4, 5, 6]) {
      final data = LocalLedger.clone(reportFixture().data)..['schema'] = schema;
      if (schema == 1) data.remove('budgets');
      if (schema < 3) { data.remove('schedules'); data.remove('occurrences'); }
      if (schema >= 4) data['imports'] = <Json>[];
      if (schema >= 5) data['reconciliations'] = <Json>[];
      if (schema >= 6) data['categoryRules'] = <Json>[];
      final old = LocalLedger(data), original = jsonEncode(data);
      expect(registerFor(old).expenses, 23000); expect(jsonEncode(old.data), original);
    }
  });

  test('large totals fail before rendering rather than rounding, and narrowed filters recover', () {
    final ledger = reportFixture(); final data = ledger.snapshot(includeVoided: true);
    final seed = LocalLedger.rows(data['transactions']).first;
    data['transactions'] = [for (var i = 0; i < 2; i++) {...seed, 'id': 'limit-$i', 'amountMinor': LocalLedger.maxMinor,
      'effectiveDate': i == 0 ? '2026-10-01' : '2026-10-02'}];
    expect(() => TransactionRegister.calculate(data, const RegisterFilter()), throwsFormatException);
    expect(TransactionRegister.calculate(data, const RegisterFilter(through: '2026-10-01')).income, LocalLedger.maxMinor);
  });
}
