import 'ledger.dart';

/// Derived planning values, never account postings or cached balances.
class CategoryBudget {
  const CategoryBudget({required this.category, required this.plan, required this.allocated,
    required this.carried, required this.spent, required this.remaining, required this.rollover});
  final Json category;
  final Json? plan;
  final int allocated;
  final int carried;
  final int spent;
  final int remaining;
  final String rollover;
  String get id => category['id'] as String;
  String get name => category['name'] as String;
  bool get hasAllocation => plan != null && plan!['removed'] != true;
  int get available => BudgetEngine.add(allocated, carried);
  int get nextCarry => BudgetEngine.carry(remaining, rollover);
}

class MonthlyBudget {
  MonthlyBudget(this.month, this.categories) {
    allocated = _sum((c) => c.allocated);
    carried = _sum((c) => c.carried);
    spent = _sum((c) => c.spent);
    remaining = BudgetEngine.add(BudgetEngine.add(allocated, carried), -spent);
  }
  final String month;
  final List<CategoryBudget> categories;
  late final int allocated;
  late final int carried;
  late final int spent;
  late final int remaining;
  int get overBudgetCount => categories.where((c) => c.remaining < 0).length;
  bool get hasPlan => categories.any((c) => c.hasAllocation || c.carried != 0);
  int _sum(int Function(CategoryBudget) select) => categories.fold(0, (sum, c) => BudgetEngine.add(sum, select(c)));
}

class BudgetEngine {
  // Exact on both native Dart and JavaScript targets. Never round financial sums.
  static const maxTotalMinor = 9007199254740991;
  static int add(int a, int b) {
    if (a.abs() > maxTotalMinor || b.abs() > maxTotalMinor ||
        (b > 0 && a > maxTotalMinor - b) || (b < 0 && a < -maxTotalMinor - b)) {
      throw const FormatException('Budget totals exceed the supported exact amount range.');
    }
    return a + b;
  }
  static int carry(int remaining, String mode) => switch (mode) {
    'none' => 0,
    'positive' => remaining > 0 ? remaining : 0,
    'all' => remaining,
    _ => throw const FormatException('Unsupported rollover rule.'),
  };
  static String monthOf(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  static String label(String month) {
    LocalLedger.budgetMonth(month);
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'];
    return '${names[int.parse(month.substring(5)) - 1]} ${month.substring(0, 4)}';
  }
  static String ruleLabel(String rule) => switch (rule) {
    'positive' => 'Unused money only',
    'all' => 'Unused money and overspending',
    _ => 'No rollover',
  };

  /// Only active expense postings count. Transfer/card payments and income do not.
  static int contribution(Json transaction, String categoryId) {
    if (transaction['voided'] == true || transaction['kind'] != 'expense') return 0;
    return LocalLedger.rows(transaction['postings']).where((p) => p['ledgerId'] == 'category:$categoryId')
        .fold<int>(0, (sum, p) => add(sum, p['amountMinor'] as int));
  }
  static List<Json> transactionsFor(Json snapshot, String month, String categoryId) {
    LocalLedger.budgetMonth(month);
    return LocalLedger.rows(snapshot['transactions']).where((t) =>
      (t['effectiveDate'] as String).startsWith('$month-') && contribution(t, categoryId) != 0).toList()
      ..sort((a, b) => (b['effectiveDate'] as String).compareTo(a['effectiveDate'] as String));
  }

  /// A plan's rollover rule controls its outgoing balance. Missing months have
  /// zero allocation and inherit the last rule. Sparse months can be evaluated
  /// directly because no allocation/spending means the carry stays unchanged.
  static MonthlyBudget calculate(Json snapshot, String month) {
    LocalLedger.budgetMonth(month);
    final categories = LocalLedger.rows(snapshot['categories']).where((c) => c['kind'] == 'Expense').toList()
      ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    final plans = <String, Map<String, Json>>{};
    for (final plan in LocalLedger.rows(snapshot['budgets'] ?? <Json>[])) {
      final m = LocalLedger.budgetMonth(plan['month']);
      if (m.compareTo(month) > 0) continue;
      (plans[plan['categoryId'] as String] ??= {})[m] = plan;
    }
    final spending = <String, Map<String, int>>{};
    for (final t in LocalLedger.rows(snapshot['transactions'])) {
      if (t['voided'] == true || t['kind'] != 'expense') continue;
      final m = (t['effectiveDate'] as String).substring(0, 7);
      if (m.compareTo(month) > 0) continue;
      for (final p in LocalLedger.rows(t['postings'])) {
        final id = p['ledgerId'] as String;
        if (!id.startsWith('category:')) continue;
        final byMonth = spending[id.substring(9)] ??= {};
        byMonth[m] = add(byMonth[m] ?? 0, p['amountMinor'] as int);
      }
    }
    final result = <CategoryBudget>[];
    for (final category in categories) {
      final id = category['id'] as String;
      final byMonth = plans[id] ?? <String, Json>{};
      final spentByMonth = spending[id] ?? <String, int>{};
      final planMonths = byMonth.keys.toList()..sort();
      final first = planMonths.isEmpty ? month : planMonths.first;
      final months = <String>{month, ...planMonths,
        ...spentByMonth.keys.where((m) => m.compareTo(first) >= 0)}.toList()..sort();
      var incoming = 0;
      var rule = 'none';
      for (final m in months) {
        final plan = byMonth[m];
        if (plan != null) rule = plan['removed'] == true ? 'none' : plan['rollover'] as String;
        final allocation = plan == null || plan['removed'] == true ? 0 : plan['amountMinor'] as int;
        final spent = spentByMonth[m] ?? 0;
        final remaining = add(add(incoming, allocation), -spent);
        if (m == month) {
          result.add(CategoryBudget(category: category, plan: plan, allocated: allocation,
            carried: incoming, spent: spent, remaining: remaining, rollover: rule));
        }
        incoming = carry(remaining, rule);
      }
    }
    return MonthlyBudget(month, result);
  }
}
