import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/reports.dart';
import 'package:budgetism/local/csv_import.dart';
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'reconciliation_test.dart' show reconcileFixture, statementRequest;

LocalLedger reportFixture() {
  var l = LocalLedger.empty().apply('account', account('checking', 'Fictional checking', 100000))
    .apply('account', account('saving', 'Fictional savings', 20000, type: 'savings'))
    .apply('account', account('card', 'Fictional card', -10000, type: 'credit_card'));
  final a = accounts(l), cats = LocalLedger.rows(l.data['categories']).where((c) => c['kind'] == 'Expense').toList();
  l = l.apply('transaction', tx('income', 'income', a[0]['id'], category(l, 'Income'), 50000));
  l = l.apply('transaction', {...tx('split', 'expense', a[0]['id'], cats[0]['id'], 20000), 'splits': [
    {'categoryId': cats[0]['id'], 'amountMinor': 6000}, {'categoryId': cats[1]['id'], 'amountMinor': 7000},
    {'categoryId': cats[1]['id'], 'amountMinor': 7000}]});
  l = l.apply('transaction', tx('card-buy', 'expense', a[2]['id'], cats[0]['id'], 3000));
  l = l.apply('transaction', tx('card-pay', 'transfer', a[0]['id'], a[2]['id'], 3000));
  l = l.apply('transaction', tx('saving-move', 'transfer', a[0]['id'], a[1]['id'], 10000));
  l = l.apply('transaction', {...tx('future', 'income', a[0]['id'], category(l, 'Income'), 10000), 'effectiveDate': '2026-11-01'});
  l = l.apply('transaction', tx('voided', 'expense', a[0]['id'], cats[0]['id'], 5000));
  final last = LocalLedger.rows(l.data['transactions']).last;
  return l.apply('void', {'operationId': 'void', 'id': last['id'], 'expectedVersion': last['version']});
}
FinanceReport reportFor(LocalLedger l, {Set<String>? ids, String from = '2026-10-01',
    String through = '2026-10-28', String today = '2026-10-28'}) =>
  ReportEngine.calculate(l.snapshot(includeVoided: true), from: from, through: through, today: today, accountIds: ids);

void main() {
  test('reports are read-only; spending excludes transfers, voids, future entries and opening equity', () {
    final l = reportFixture();
    final original = jsonEncode(l.data), r = reportFor(l);
    expect(r.income, 50000); expect(r.expense, 23000); expect(r.netIncome, 27000);
    expect(r.starting, 110000); expect(r.closing, 137000); expect(r.balanceChange, 27000);
    expect(r.transactions.length, 3); expect(r.transferCount, 2);
    expect(jsonEncode(l.data), original);
    expect(() => r.transactions.clear(), throwsUnsupportedError);
    expect(() => r.transactions.first.categories.clear(), throwsUnsupportedError);
  });
  test('account filters keep correct transfer sides without calling transfers income or expenses', () {
    final l = reportFixture(), a = accounts(l);
    final cash = reportFor(l, ids: {a[0]['id']});
    expect(cash.income, 50000); expect(cash.expense, 20000); expect(cash.netIncome, 30000);
    expect(cash.balanceChange, 17000); expect(cash.closing, 117000);
    final card = reportFor(l, ids: {a[2]['id']});
    expect(card.expense, 3000); expect(card.income, 0); expect(card.closing, -10000);
    expect(card.balanceChange, 0);
    expect(reportFor(l, ids: <String>{}).balances, isEmpty);
    expect(reportFor(l, ids: <String>{}).closing, 0);
    expect(() => reportFor(l, ids: {'missing-account'}), throwsFormatException);
  });
  test('duplicate split categories aggregate once and drilldown shows the contribution', () {
    final l = reportFixture(), r = reportFor(l);
    final cats = LocalLedger.rows(l.data['categories']).where((c) => c['kind'] == 'Expense').toList();
    final housing = r.categories.firstWhere((c) => c.id == cats[1]['id']);
    expect(housing.amount, 14000); expect(housing.count, 1);
    expect(r.forCategory(housing.id).single.amount, 20000);
    expect(r.forCategory(housing.id).single.categories[housing.id], 14000);
    expect(r.categories.where((c) => c.kind == 'Expense').fold<int>(0, (s, c) => s + c.amount), r.expense);
  });
  test('inclusive dates, prior activity and empty months give exact balance continuity', () {
    var l = reconcileFixture(); final id = accounts(l).single['id'];
    l = l.apply('transaction', {...tx('old', 'income', id, category(l, 'Income'), 123), 'effectiveDate': '2026-09-30'});
    final r = reportFor(l, from: '2026-10-27', through: '2026-10-27');
    expect(r.starting, 100123); expect(r.closing, 130123); expect(r.income, 50000);
    final year = reportFor(l, from: '2026-09-01', through: '2026-12-31', today: '2026-12-31');
    expect(year.months.map((m) => m.month), ['2026-09', '2026-10', '2026-11', '2026-12']);
    expect(year.months.map((m) => m.closing), [100123, 130123, 130123, 130123]);
    expect(year.months.last.income, 0); expect(year.months.last.expense, 0);
  });
  test('calendar bounds, leap days, year changes, invalid ranges and future periods', () {
    final l = reconcileFixture();
    expect(reportFor(l, from: '2024-02-29', through: '2024-03-01').months.length, 2);
    expect(reportFor(l, from: '2025-12-31', through: '2026-01-01').months.length, 2);
    expect(() => reportFor(l, from: '2026-02-30'), throwsFormatException);
    expect(() => reportFor(l, from: '2026-10-29'), throwsFormatException);
    expect(() => reportFor(l, through: '2026-10-29'), throwsFormatException);
    expect(() => reportFor(l, from: '1900-01-01'), throwsFormatException);
  });
  test('editing and voiding recalculate reports without cached financial totals', () {
    var l = reconcileFixture(); final t = LocalLedger.rows(l.data['transactions']).last;
    l = l.apply('transaction', {...t, 'operationId': 'edit', 'expectedVersion': t['version'], 'amountMinor': 25000});
    expect(reportFor(l).expense, 25000);
    l = l.apply('void', {'operationId': 'void', 'id': t['id'], 'expectedVersion': 2});
    expect(reportFor(l).expense, 0); expect(reportFor(l).closing, 150000);
  });
  test('plans and budgets are not actuals, and reconciliation status does not hide recorded activity', () {
    var l = reconcileFixture(); final a = accounts(l).single['id'], cat = category(l, 'Expense');
    l = l.apply('budget', {'operationId': 'budget', 'month': '2026-10', 'categoryId': cat,
      'amountMinor': 90000, 'rollover': 'positive', 'expectedVersion': 0});
    l = l.apply('schedule', {'operationId': 'schedule', 'expectedVersion': 0,
      'name': 'Fictional plan', 'kind': 'expense', 'accountId': a, 'counterpartyAccountId': cat,
      'currency': 'USD', 'amountMinor': 30000, 'payee': '', 'notes': '',
      'startDate': '2026-10-28', 'frequency': 'monthly', 'endDate': null});
    l = l.apply('reconcile', statementRequest(l));
    final before = jsonEncode(l.data), r = reportFor(l);
    expect(r.expense, 20000); expect(r.income, 50000); expect(r.closing, 130000);
    expect(jsonEncode(l.data), before); expect(l.data['schema'], 5);
    final t = LocalLedger.rows(l.data['transactions']).first;
    expect(Reconciliation.locked(l.data, t['id']), isTrue);
  });
  test('all readable financial schemas report without a schema change', () {
    for (final schema in [1, 2, 3, 4, 5]) {
      final data = LocalLedger.clone(reconcileFixture().data);
      data['schema'] = schema;
      final before = jsonEncode(data);
      final r = ReportEngine.calculate(data, from: '2026-10-01', through: '2026-10-28', today: '2026-10-28');
      expect(r.closing, 130000); expect(jsonEncode(data), before);
    }
  });
  test('integer total bounds reject overflow instead of silently rounding', () {
    expect(ReportEngine.add(ReportEngine.maxTotalMinor - 1, 1), ReportEngine.maxTotalMinor);
    expect(() => ReportEngine.add(ReportEngine.maxTotalMinor, 1), throwsFormatException);
    expect(() => ReportEngine.add(-ReportEngine.maxTotalMinor, -1), throwsFormatException);
    expect(ReportEngine.add(ReportEngine.maxTotalMinor, -ReportEngine.maxTotalMinor), 0);
  });
  test('CSV sections preserve exact cents and scope; split detail totals do not duplicate the whole transaction', () {
    final r = reportFor(reportFixture());
    for (final type in ReportExport.values) {
      final output = ReportCsv.encode(r, type), table = CsvTable.parse(output);
      expect(output.startsWith('\ufeff'), isTrue); expect(output.endsWith('\r\n'), isTrue);
      expect(table.records.every((row) => row.length == table.headers.length), isTrue);
      expect(table.records.every((row) => row[0] == r.from && row[1] == r.through && row[2] == 'USD'), isTrue);
    }
    final detail = CsvTable.parse(ReportCsv.encode(r, ReportExport.transactions));
    expect(detail.records.length, 4);
    expect(detail.records.where((row) => row[detail.headers.indexOf('Type')] == 'expense').map((row) => row[detail.headers.indexOf('Category contribution USD')]).toList()..sort(), ['140.00', '30.00', '60.00']);
    final balances = CsvTable.parse(ReportCsv.encode(r, ReportExport.balances));
    expect(balances.records.any((row) => row.last == '-100.00'), isTrue);
  });
  test('CSV user text cannot introduce columns or executable formula prefixes', () {
    for (final value in ['=SUM(1,2)', '+1+1', '-1+1', '@SUM(A1)', '＝1+1', '\t=1+1', '  =1+1']) {
      var l = reconcileFixture(); final t = LocalLedger.rows(l.data['transactions']).last;
      l = l.apply('transaction', {...t, 'operationId': 'text', 'expectedVersion': t['version'], 'payee': value});
      final table = CsvTable.parse(ReportCsv.encode(reportFor(l), ReportExport.transactions));
      expect(table.records.firstWhere((row) => row[table.headers.indexOf('Type')] == 'expense')[table.headers.indexOf('Payee')], startsWith('Text: '));
    }
    var l = reconcileFixture(); final t = LocalLedger.rows(l.data['transactions']).last;
    l = l.apply('transaction', {...t, 'operationId': 'quoted', 'expectedVersion': t['version'], 'payee': 'Shop, "quoted"\nnext line'});
    final table = CsvTable.parse(ReportCsv.encode(reportFor(l), ReportExport.transactions));
    expect(table.records.firstWhere((row) => row[table.headers.indexOf('Type')] == 'expense')[table.headers.indexOf('Payee')], 'Shop, "quoted" next line');
  });
  test('empty workspace produces valid zero totals and header-only detail', () {
    final l = LocalLedger.empty(), r = reportFor(l);
    expect(r.income, 0); expect(r.expense, 0); expect(r.closing, 0);
    expect(r.categories, isEmpty); expect(r.months.single.net, 0);
    expect(ReportCsv.encode(r, ReportExport.transactions).split('\r\n').length, 2);
  });
}
