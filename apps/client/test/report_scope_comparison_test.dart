import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/reports.dart';
import 'package:budgetism/local/report_comparison.dart';
import 'package:budgetism/local/csv_import.dart';
import 'reports_test.dart' show reportFixture;

void main() {
  test('category scope includes exact split contributions and leaves account balances untouched', () {
    final ledger = reportFixture(), data = ledger.snapshot(includeVoided: true);
    final before = jsonEncode(data);
    final housing = LocalLedger.rows(data['categories']).firstWhere((c) => c['name'] == 'Housing')['id'] as String;
    final all = ReportEngine.calculate(data, from: '2026-10-01', through: '2026-10-28', today: '2026-10-28');
    final scoped = ReportEngine.calculate(data, from: all.from, through: all.through, today: all.today, categoryIds: {housing});
    expect(scoped.income, 0); expect(scoped.expense, 14000); expect(scoped.netIncome, -14000);
    expect(scoped.months.single.expense, 14000); expect(scoped.transactions.single.amount, 20000);
    expect(scoped.transactions.single.categories, {housing: 14000});
    expect(scoped.closing, all.closing); expect(scoped.starting, all.starting);
    expect(scoped.balanceChange, all.balanceChange); expect(scoped.transferCount, all.transferCount);
    expect(scoped.months.single.closing, all.months.single.closing);
    final csv = CsvTable.parse(ReportCsv.encode(scoped, ReportExport.transactions));
    expect(csv.records.single[csv.headers.indexOf('Category contribution USD')], '140.00');
    expect(csv.records.single[csv.headers.indexOf('Category scope')], 'Housing');
    expect(csv.records.single[csv.headers.indexOf('Balance scope')], contains('Whole selected accounts'));
    expect(jsonEncode(data), before);
  });
  test('all versus none, archived history, missing category and signed refunds', () {
    final data = reportFixture().snapshot(includeVoided: true);
    final cats = LocalLedger.rows(data['categories']);
    final housing = cats.firstWhere((c) => c['name'] == 'Housing');
    housing['archived'] = true;
    data['categories'] = cats;
    final id = housing['id'] as String;
    final transactions = LocalLedger.rows(data['transactions']);
    final t = transactions.firstWhere((t) => t['payee'] == 'Fictional split', orElse: () =>
      transactions.firstWhere((t) => (t['amountMinor'] as int) == 20000));
    t['amountMinor'] = -(t['amountMinor'] as int);
    final postings = LocalLedger.rows(t['postings']);
    for (final p in postings) { p['amountMinor'] = -(p['amountMinor'] as int); }
    t['postings'] = postings; data['transactions'] = transactions;
    FinanceReport calculate(Set<String>? categories) => ReportEngine.calculate(data,
      from: '2026-10-01', through: '2026-10-28', today: '2026-10-28', categoryIds: categories);
    final all = calculate(null), explicitAll = calculate(cats.map((c) => c['id'] as String).toSet()), none = calculate({});
    expect(explicitAll.income, all.income); expect(explicitAll.expense, all.expense);
    expect(none.income, 0); expect(none.expense, 0); expect(none.transactions, isEmpty);
    expect(none.categories, isEmpty); expect(none.closing, all.closing);
    expect(none.categoryScope, 'No categories');
    expect(calculate({id}).expense, -14000); expect(calculate({id}).categoryScope, 'Housing');
    expect(() => calculate({'missing-category'}), throwsFormatException);
  });
  test('account and split-category scope are identical across nonempty comparison periods', () {
    final data = reportFixture().snapshot(includeVoided: true);
    final housing = LocalLedger.rows(data['categories']).firstWhere((c) => c['name'] == 'Housing')['id'] as String;
    final transactions = LocalLedger.rows(data['transactions']);
    final originalSplit = transactions.firstWhere((t) => t['amountMinor'] == 20000);
    final selectedAccount = originalSplit['accountId'] as String;
    final otherAccount = LocalLedger.rows(data['accounts']).firstWhere((a) => a['type'] == 'savings')['id'] as String;
    final prior = Map<String, dynamic>.from(jsonDecode(jsonEncode(originalSplit)) as Map);
    prior['id'] = 'fictional-prior-split'; prior['effectiveDate'] = '2026-09-10'; prior['amountMinor'] = 10000;
    final priorPostings = LocalLedger.rows(prior['postings']);
    for (final posting in priorPostings) { posting['amountMinor'] = (posting['amountMinor'] as int) ~/ 2; }
    prior['postings'] = priorPostings;
    final other = Map<String, dynamic>.from(jsonDecode(jsonEncode(originalSplit)) as Map);
    other['id'] = 'fictional-other-account'; other['accountId'] = otherAccount;
    final otherPostings = LocalLedger.rows(other['postings']);
    for (final posting in otherPostings) {
      if (posting['ledgerId'] == selectedAccount) { posting['ledgerId'] = otherAccount; }
    }
    other['postings'] = otherPostings;
    data['transactions'] = [...transactions, prior, other];
    final before = jsonEncode(data);
    final current = ReportEngine.calculate(data, from: '2026-10-01', through: '2026-10-28', today: '2026-10-28',
      accountIds: {selectedAccount}, categoryIds: {housing});
    final range = ReportComparisonRange.forPeriod(current.from, current.through, ReportComparisonPeriod.previousPeriod);
    final previous = ReportEngine.calculate(data, from: range.from, through: range.through, today: current.today,
      accountIds: {selectedAccount}, categoryIds: {housing});
    final values = ReportComparisonValue.from(current, previous);
    expect(current.expense, 14000); expect(previous.expense, 7000);
    expect(current.income, 0); expect(previous.income, 0);
    expect(values[1].delta, 7000); expect(values[1].percentage, '100.0%');
    expect(values[2].delta, -7000);
    expect(current.balances.single.id, selectedAccount); expect(previous.balances.single.id, selectedAccount);
    expect(ReportEngine.calculate(data, from: current.from, through: current.through, today: current.today,
      categoryIds: {housing}).expense, 28000);
    expect(jsonEncode(data), before);
  });
  test('equal-length previous period is inclusive and immediately adjacent across leap day', () {
    final range = ReportComparisonRange.forPeriod('2024-03-01', '2024-03-03', ReportComparisonPeriod.previousPeriod);
    expect(range.from, '2024-02-27'); expect(range.through, '2024-02-29'); expect(range.days, 3);
    final single = ReportComparisonRange.forPeriod('2026-01-01', '2026-01-01', ReportComparisonPeriod.previousPeriod);
    expect(single.from, '2025-12-31'); expect(single.through, '2025-12-31');
  });
  test('previous year clamps leap dates honestly and rejects supported-date underflow', () {
    final single = ReportComparisonRange.forPeriod('2024-02-29', '2024-02-29', ReportComparisonPeriod.previousYear);
    expect(single.from, '2023-02-28'); expect(single.through, '2023-02-28');
    final range = ReportComparisonRange.forPeriod('2024-02-28', '2024-03-01', ReportComparisonPeriod.previousYear);
    expect(range.days, 2);
    expect(() => ReportComparisonRange.forPeriod('1900-01-01', '1900-01-31', ReportComparisonPeriod.previousPeriod), throwsFormatException);
    expect(() => ReportComparisonRange.forPeriod('1900-12-01', '1900-12-31', ReportComparisonPeriod.previousYear), throwsFormatException);
  });
  test('comparison exact deltas and zero or negative base never invent growth percentages', () {
    final increase = ReportComparisonValue('Expenses', 15000, 10000);
    expect(increase.delta, 5000); expect(increase.percentage, '50.0%');
    final zero = ReportComparisonValue('Income', 12345, 0);
    expect(zero.delta, 12345); expect(zero.percentage, startsWith('N/A'));
    expect(ReportComparisonValue('Refunds', -100, -200).percentage, startsWith('N/A'));
    expect(() => ReportComparisonValue('Overflow', ReportEngine.maxTotalMinor, -1), throwsFormatException);
  });
}
