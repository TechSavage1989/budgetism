import 'package:uuid/uuid.dart';
import 'finance_api.dart';

/// Ephemeral example workspace. There is no disk or network access in demo mode.
/// Never use this type for real financial records.
class DemoFinanceApi extends FinanceApi {
  DemoFinanceApi() : super('demo://memory') {
    _seed();
  }

  @override
  bool get isDemo => true;

  final _accounts = <Map<String, dynamic>>[];
  final _categories = <Map<String, dynamic>>[];
  final _transactions = <Map<String, dynamic>>[];
  final _operationIds = <String>{};
  int _cursor = 0;

  void _seed() {
    const uuid = Uuid();
    for (final item in [
      ('Groceries', 'Expense'), ('Housing', 'Expense'),
      ('Utilities', 'Expense'), ('Transport', 'Expense'),
      ('Dining', 'Expense'), ('Other spending', 'Expense'),
      ('Paycheck', 'Income'), ('Other income', 'Income')
    ]) {
      _categories.add({'id': uuid.v4(), 'name': item.$1, 'kind': item.$2, 'currency': 'USD'});
    }
    _accounts.addAll([
      _account('Everyday Checking', 'checking', 427513),
      _account('Emergency Savings', 'savings', 920000),
      _account('Credit Card', 'credit_card', -86025),
    ]);
    final checking = _accounts[0]['id'] as String;
    final card = _accounts[2]['id'] as String;
    final grocery = _categories.firstWhere((c) => c['name'] == 'Groceries')['id'] as String;
    final utilities = _categories.firstWhere((c) => c['name'] == 'Utilities')['id'] as String;
    final paycheck = _categories.firstWhere((c) => c['name'] == 'Paycheck')['id'] as String;
    final now = DateTime.now();
    for (final item in [
      ('income', checking, paycheck, 245000, 'Paycheck', 5),
      ('expense', checking, grocery, 8653, 'Groceries', 2),
      ('expense', checking, utilities, 14500, 'Electric company', 1),
      ('expense', card, grocery, 4385, 'Market', 0),
    ]) {
      final date = now.subtract(Duration(days: item.$6));
      _transactions.add({
        'id': const Uuid().v4(), 'operationId': const Uuid().v4(),
        'kind': item.$1, 'accountId': item.$2, 'counterpartyAccountId': item.$3,
        'amountMinor': item.$4, 'currency': 'USD', 'effectiveDate': _date(date),
        'payee': item.$5, 'notes': '', 'version': 1,
        'createdUtc': date.toUtc().toIso8601String(),
      });
    }
  }

  Map<String, dynamic> _account(String name, String type, int cents) => {
    'id': const Uuid().v4(), 'name': name, 'type': type, 'currency': 'USD',
    'balanceMinor': cents, 'archived': false,
    'createdUtc': DateTime.now().toUtc().toIso8601String(),
  };

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Map<String, dynamic>> snapshot() async => {
    'cursor': _cursor,
    'accounts': _accounts.map((a) => Map<String, dynamic>.from(a)).toList(),
    'categories': _categories.map((c) => Map<String, dynamic>.from(c)).toList(),
    'transactions': _transactions.map((t) => Map<String, dynamic>.from(t)).toList(),
  };

  @override
  Future<void> createAccount(Map<String, dynamic> data) async {
    final op = data['operationId'] as String?;
    if (op == null) throw ArgumentError('Missing operation identifier');
    if (!_operationIds.add(op)) return;
    final name = (data['name'] as String? ?? '').trim();
    if (name.isEmpty) throw ArgumentError('Account name required');
    _accounts.add(_account(name, data['type'] as String, data['openingBalanceMinor'] as int));
    _cursor++;
  }

  @override
  Future<void> createTransaction(Map<String, dynamic> data) async {
    final op = data['operationId'] as String?;
    if (op == null) throw ArgumentError('Missing operation identifier');
    if (_operationIds.contains(op)) return;
    final amount = data['amountMinor'] as int;
    if (amount <= 0) throw ArgumentError('Transaction amount must be positive');
    final from = _accounts.where((x) => x['id'] == data['accountId']).firstOrNull;
    if (from == null) throw ArgumentError('Account was not found');
    final kind = data['kind'] as String;
    final counterpart = data['counterpartyAccountId'] as String;
    if (kind == 'transfer') {
      final to = _accounts.where((x) => x['id'] == counterpart).firstOrNull;
      if (to == null || identical(to, from)) throw ArgumentError('Choose a different destination account');
      to['balanceMinor'] = (to['balanceMinor'] as int) + amount;
      from['balanceMinor'] = (from['balanceMinor'] as int) - amount;
    } else if (kind == 'expense' || kind == 'income') {
      final categoryKind = kind == 'expense' ? 'Expense' : 'Income';
      if (!_categories.any((c) => c['id'] == counterpart && c['kind'] == categoryKind)) {
        throw ArgumentError('Choose a valid category');
      }
      from['balanceMinor'] = (from['balanceMinor'] as int) + (kind == 'income' ? amount : -amount);
    } else {
      throw ArgumentError('Unsupported transaction type');
    }
    _transactions.add({
      ...data, 'id': const Uuid().v4(), 'version': 1,
      'createdUtc': DateTime.now().toUtc().toIso8601String(),
    });
    _operationIds.add(op);
    _cursor++;
  }

  @override
  Future<void> logout() async { token = null; }
}
