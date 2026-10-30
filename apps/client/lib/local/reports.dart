import '../money.dart';
import 'ledger.dart';
import 'recurrence.dart';

class ReportTransaction {
  ReportTransaction({required this.id, required this.date, required this.kind,
    required this.accountId, required this.accountName, required this.payee,
    required this.amount, required Map<String, int> categories})
      : categories = Map.unmodifiable(categories);
  final String id, date, kind, accountId, accountName, payee;
  final int amount;
  final Map<String, int> categories;
}

class ReportCategory {
  const ReportCategory(this.id, this.name, this.kind, this.amount, this.count);
  final String id, name, kind;
  final int amount, count;
}

class ReportMonth {
  const ReportMonth(this.month, this.income, this.expense, this.closing);
  final String month;
  final int income, expense, closing;
  int get net => ReportEngine.add(income, -expense);
}

class ReportBalance {
  const ReportBalance(this.id, this.name, this.type, this.before, this.closing);
  final String id, name, type;
  final int before, closing;
  int get change => ReportEngine.add(closing, -before);
}

/// Immutable derived values. This object has no reference to the vault or API.
class FinanceReport {
  FinanceReport({required this.from, required this.through, required this.today,
    required this.income, required this.expense, required this.starting,
    required this.closing, required this.transferCount,
    this.categoryScope = 'All categories', this.categoryFiltered = false,
    required List<ReportTransaction> transactions, required List<ReportCategory> categories,
    required List<ReportMonth> months, required List<ReportBalance> balances})
      : transactions = List.unmodifiable(transactions), categories = List.unmodifiable(categories),
        months = List.unmodifiable(months), balances = List.unmodifiable(balances);
  final String from, through, today;
  final String categoryScope;
  final bool categoryFiltered;
  final int income, expense, starting, closing, transferCount;
  final List<ReportTransaction> transactions;
  final List<ReportCategory> categories;
  final List<ReportMonth> months;
  final List<ReportBalance> balances;
  int get netIncome => ReportEngine.add(income, -expense);
  int get balanceChange => ReportEngine.add(closing, -starting);
  List<ReportTransaction> forCategory(String id) =>
      transactions.where((t) => t.categories.containsKey(id)).toList(growable: false);
}

/// Historical reports only. No schedules, budget allocations or new postings.
class ReportEngine {
  static const maxTotalMinor = 9007199254740991;
  static const maxRangeDays = 3660;
  static int add(int a, int b) {
    if (a.abs() > maxTotalMinor || b.abs() > maxTotalMinor ||
        (b > 0 && a > maxTotalMinor - b) || (b < 0 && a < -maxTotalMinor - b)) {
      throw const FormatException('Report totals exceed the supported exact amount range. Narrow the selection.');
    }
    return a + b;
  }
  static int _sum(Iterable<int> values) => values.fold(0, add);
  static bool _inside(String date, String from, String through) =>
      date.compareTo(from) >= 0 && date.compareTo(through) <= 0;

  /// null selects all accounts; an empty set deliberately selects none.
  /// Undated opening balances are the saved ledger baseline, not valuations.
  static FinanceReport calculate(Json data, {required String from, required String through,
      required String today, Set<String>? accountIds, Set<String>? categoryIds}) {
    final first = Recurrence.parse(from), last = Recurrence.parse(through);
    final current = Recurrence.parse(today);
    if (last.isBefore(first) || last.isAfter(current) || last.difference(first).inDays >= maxRangeDays) {
      throw const FormatException('Choose an ordered historical range of at most 3,660 days ending today or earlier.');
    }
    final all = LocalLedger.rows(data['accounts']);
    final known = {for (final a in all) a['id'] as String: a};
    final selected = accountIds == null ? known.keys.toSet() : Set<String>.from(accountIds);
    if (selected.any((id) => !known.containsKey(id))) {
      throw const FormatException('An account in this report is no longer available. Refresh the selection.');
    }
    final accounts = all.where((a) => selected.contains(a['id'])).toList()
      ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    final categoryMap = {for (final c in LocalLedger.rows(data['categories'])) c['id'] as String: c};
    final categorySelection = categoryIds == null ? null : Set<String>.from(categoryIds);
    if (categorySelection != null && categorySelection.any((id) => !categoryMap.containsKey(id))) {
      throw const FormatException('A report category is no longer available. Reset the category selection.');
    }
    final before = {for (final a in accounts) a['id'] as String: a['openingBalanceMinor'] as int};
    final closing = Map<String, int>.from(before);
    final movement = <String, int>{}, monthlyIncome = <String, int>{}, monthlyExpense = <String, int>{};
    final categoryTotals = <String, int>{}, categoryCounts = <String, int>{};
    final entries = <ReportTransaction>[];
    var income = 0, expense = 0, transfers = 0;
    for (final t in LocalLedger.rows(data['transactions'])) {
      final date = t['effectiveDate'] as String;
      if (t['voided'] == true || date.compareTo(through) > 0) continue;
      final inside = _inside(date, from, through), month = date.substring(0, 7);
      var touchesSelected = false;
      for (final p in LocalLedger.rows(t['postings'])) {
        final id = p['ledgerId'] as String;
        if (!selected.contains(id)) continue;
        touchesSelected = true;
        final amount = p['amountMinor'] as int;
        closing[id] = add(closing[id]!, amount);
        if (!inside) { before[id] = add(before[id]!, amount); }
        else { movement[month] = add(movement[month] ?? 0, amount); }
      }
      if (!inside) continue;
      // Server openings have effective dates and signed postings. They affect
      // balances/monthly movement, never income, spending or transfer counts.
      if (t['kind'] == 'opening') continue;
      if (t['kind'] == 'transfer') {
        if (touchesSelected) transfers++;
        continue;
      }
      if (!selected.contains(t['accountId'])) continue;
      final kind = t['kind'] as String, amount = t['amountMinor'] as int;
      if (kind != 'income' && kind != 'expense') {
        throw const FormatException('Unsupported transaction type in report.');
      }
      final contributions = <String, int>{};
      for (final p in LocalLedger.rows(t['postings'])) {
        final ledgerId = p['ledgerId'] as String;
        if (!ledgerId.startsWith('category:')) continue;
        final id = ledgerId.substring(9);
        if (!categoryMap.containsKey(id)) throw const FormatException('A report category is missing.');
        final part = (p['amountMinor'] as int) * (kind == 'income' ? -1 : 1);
        contributions[id] = add(contributions[id] ?? 0, part);
      }
      if (_sum(contributions.values) != amount) throw const FormatException('Category amounts do not match the recorded transaction.');
      // Validate the full transaction first, then scope only category contributions.
      // Whole-account postings above deliberately remain unfiltered.
      if (categorySelection != null) {
        contributions.removeWhere((id, _) => !categorySelection.contains(id));
      }
      if (contributions.isEmpty) continue;
      final scopedAmount = _sum(contributions.values);
      if (kind == 'income') {
        income = add(income, scopedAmount); monthlyIncome[month] = add(monthlyIncome[month] ?? 0, scopedAmount);
      } else {
        expense = add(expense, scopedAmount); monthlyExpense[month] = add(monthlyExpense[month] ?? 0, scopedAmount);
      }
      for (final item in contributions.entries) {
        categoryTotals[item.key] = add(categoryTotals[item.key] ?? 0, item.value);
        categoryCounts[item.key] = (categoryCounts[item.key] ?? 0) + 1;
      }
      entries.add(ReportTransaction(id: t['id'] as String, date: date, kind: kind,
        accountId: t['accountId'] as String, accountName: known[t['accountId']]!['name'] as String,
        payee: t['payee'] as String, amount: amount, categories: contributions));
    }
    final categories = [for (final id in categoryTotals.keys) ReportCategory(id,
      categoryMap[id]!['name'] as String, categoryMap[id]!['kind'] as String,
      categoryTotals[id]!, categoryCounts[id]!)];
    categories.sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      return byAmount != 0 ? byAmount : a.id.compareTo(b.id);
    });
    entries.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    final starting = _sum(before.values), finalBalance = _sum(closing.values);
    // Validate derived deltas inside the engine so the screen can show a
    // recoverable range error before reading any report getter.
    add(finalBalance, -starting);
    for (final id in selected) { add(closing[id]!, -before[id]!); }
    var running = starting, month = from.substring(0, 7);
    final lastMonth = through.substring(0, 7), months = <ReportMonth>[];
    while (true) {
      running = add(running, movement[month] ?? 0);
      add(monthlyIncome[month] ?? 0, -(monthlyExpense[month] ?? 0));
      months.add(ReportMonth(month, monthlyIncome[month] ?? 0, monthlyExpense[month] ?? 0, running));
      if (month == lastMonth) break;
      month = LocalLedger.shiftMonth(month, 1);
    }
    if (running != finalBalance) throw const FormatException('Report balance cross-check failed.');
    add(income, -expense);
    final selectedCategoryNames = categorySelection?.map((id) => categoryMap[id]!['name'] as String).toList();
    selectedCategoryNames?.sort();
    return FinanceReport(from: from, through: through, today: today,
      categoryFiltered: categorySelection != null,
      categoryScope: categorySelection == null ? 'All categories' : categorySelection.isEmpty
        ? 'No categories' : selectedCategoryNames!.join(' | '),
      income: income, expense: expense, starting: starting, closing: finalBalance, transferCount: transfers,
      transactions: entries, categories: categories, months: months,
      balances: [for (final a in accounts) ReportBalance(a['id'] as String,
        a['name'] as String, a['type'] as String, before[a['id']]!, closing[a['id']]!)]);
  }
}

enum ReportExport { summary, categories, monthly, balances, transactions }

class _CsvAmount {
  const _CsvAmount(this.value);
  final int value;
}

class ReportCsv {
  static String label(ReportExport type) => switch (type) {
    ReportExport.summary => 'Income and spending summary',
    ReportExport.categories => 'Category totals',
    ReportExport.monthly => 'Monthly trends',
    ReportExport.balances => 'Account balances',
    ReportExport.transactions => 'Income and expense detail',
  };
  static String _field(Object value) {
    if (value is _CsvAmount) return decimalAmount(value.value);
    // Keep user text literal even in spreadsheets. A visible text prefix is
    // intentional; CSV is a viewing export, not a lossless workspace backup.
    var text = value.toString().replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
    if (RegExp(r'^\s*[=+\-@＝＋－＠]').hasMatch(text)) text = 'Text: $text';
    return '"${text.replaceAll('"', '""')}"';
  }
  static String encode(FinanceReport report, ReportExport type) {
    final rows = <List<Object>>[];
    final common = <Object>['Period from', 'Period through', 'Currency', 'Category scope', 'Balance scope'];
    final prefix = <Object>[report.from, report.through, 'USD', report.categoryScope, 'Whole selected accounts; category filter does not affect balances'];
    void row(List<Object> value) => rows.add([...prefix, ...value]);
    final scope = report.balances.map((a) => a.name).join(' | ');
    switch (type) {
      case ReportExport.summary:
        rows.add([...common, 'Selected accounts', 'Income USD', 'Expenses USD', 'Net income USD',
          'Starting recorded net balance USD', 'Closing recorded net balance USD']);
        row([scope, _CsvAmount(report.income), _CsvAmount(report.expense), _CsvAmount(report.netIncome),
          _CsvAmount(report.starting), _CsvAmount(report.closing)]);
        break;
      case ReportExport.categories:
        rows.add([...common, 'Selected accounts', 'Type', 'Category', 'Amount USD', 'Transaction count']);
        for (final c in report.categories) { row([scope, c.kind, c.name, _CsvAmount(c.amount), c.count]); }
        break;
      case ReportExport.monthly:
        rows.add([...common, 'Selected accounts', 'Month', 'Income USD', 'Expenses USD', 'Net income USD', 'Closing recorded net balance USD']);
        for (final m in report.months) { row([scope, m.month, _CsvAmount(m.income), _CsvAmount(m.expense), _CsvAmount(m.net), _CsvAmount(m.closing)]); }
        break;
      case ReportExport.balances:
        rows.add([...common, 'Account', 'Account type', 'Starting recorded balance USD', 'Change USD', 'Closing recorded balance USD']);
        for (final a in report.balances) { row([a.name, a.type, _CsvAmount(a.before), _CsvAmount(a.change), _CsvAmount(a.closing)]); }
        break;
      case ReportExport.transactions:
        rows.add([...common, 'Date', 'Type', 'Account', 'Payee', 'Category', 'Category contribution USD', 'Transaction ID']);
        final names = {for (final c in report.categories) c.id: c.name};
        for (final t in report.transactions) {
          for (final c in t.categories.entries) { row([t.date, t.kind, t.accountName, t.payee, names[c.key]!, _CsvAmount(c.value), t.id]); }
        }
        break;
    }
    return '\ufeff${rows.map((r) => r.map(_field).join(',')).join('\r\n')}\r\n';
  }
}
