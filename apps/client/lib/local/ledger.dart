import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;

/// Exact USD ledger. No IO, network calls, floating-point balances or sample data.
class LocalLedger {
  LocalLedger(Json source) : data = clone(source) { validate(); }
  final Json data;
  static const schema = 1;
  static const maxMinor = 99999999999999;
  static const accountTypes = ['checking', 'savings', 'cash', 'credit_card', 'loan', 'asset', 'liability'];
  static Json clone(Json value) => Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  static List<Json> rows(Object? value) => (value as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  int get revision => data['revision'] as int;

  factory LocalLedger.empty() => LocalLedger({
    'schema': schema, 'revision': 0, 'accounts': <Json>[], 'transactions': <Json>[],
    'categories': [
      for (final name in ['Groceries', 'Housing', 'Utilities', 'Transport', 'Dining', 'Other spending'])
        {'id': const Uuid().v4(), 'name': name, 'kind': 'Expense', 'currency': 'USD'},
      for (final name in ['Paycheck', 'Other income'])
        {'id': const Uuid().v4(), 'name': name, 'kind': 'Income', 'currency': 'USD'},
    ],
    'operations': <String, dynamic>{}, 'audit': <Json>[],
  });

  static Never fail(String message) => throw FormatException(message);
  static String text(Object? value, String label, int limit, {bool optional = false}) {
    if (value is! String || value.length > limit || (!optional && value.trim().isEmpty)) {
      fail('$label must contain ${optional ? 'at most' : '1 to'} $limit characters.');
    }
    return value.trim();
  }
  static int minor(Object? value, {bool signed = false}) {
    if (value is! int || value.abs() > maxMinor || (!signed && value <= 0)) {
      fail('Enter a valid ${signed ? '' : 'positive '}USD amount.');
    }
    return value;
  }
  static void date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) fail('Use a valid transaction date.');
    final d = DateTime.tryParse(value);
    if (d == null || d.toIso8601String().substring(0, 10) != value || d.year < 1900) fail('Invalid transaction date.');
  }
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  /// Applies once, or refuses reuse of an operation ID with different content.
  LocalLedger apply(String action, Json input) {
    final operation = text(input['operationId'], 'Operation identifier', 100);
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(_canonical({'action': action, 'input': input})))).toString();
    final operations = Map<String, dynamic>.from(data['operations'] as Map);
    if (operations.containsKey(operation)) {
      if (operations[operation] != fingerprint) fail('This operation identifier was already used for different data.');
      return this;
    }
    final next = clone(data);
    final accounts = rows(next['accounts']);
    final categories = rows(next['categories']);
    final transactions = rows(next['transactions']);
    final id = input['id'] as String? ?? const Uuid().v4();
    Json? before;
    Json after;
    switch (action) {
      case 'account':
        final index = accounts.indexWhere((a) => a['id'] == id);
        if (input['id'] != null && index < 0) fail('Account was not found.');
        if (index >= 0) {
          before = accounts[index];
          if (input['expectedVersion'] != before['version']) fail('Account changed. Refresh before editing.');
        }
        final name = text(input['name'], 'Account name', 100);
        if (accounts.any((a) => a['id'] != id && (a['name'] as String).toLowerCase() == name.toLowerCase())) fail('An account already uses this name.');
        if (!accountTypes.contains(input['type']) || input['currency'] != 'USD') fail('Choose a supported USD account type.');
        after = {'id': id, 'name': name, 'type': input['type'], 'currency': 'USD',
          'openingBalanceMinor': minor(input['openingBalanceMinor'], signed: true),
          'version': (before?['version'] as int? ?? 0) + 1, 'archived': false};
        if (index < 0) { accounts.add(after); } else { accounts[index] = after; }
        break;
      case 'category':
        final index = categories.indexWhere((c) => c['id'] == id);
        if (input['id'] != null && index < 0) fail('Category was not found.');
        before = index < 0 ? null : categories[index];
        final name = text(input['name'], 'Category name', 80);
        final kind = before?['kind'] ?? input['kind'];
        if (!['Income', 'Expense'].contains(kind)) fail('Choose Income or Expense.');
        if (categories.any((c) => c['id'] != id && c['kind'] == kind && (c['name'] as String).toLowerCase() == name.toLowerCase())) fail('A category already uses this name.');
        after = {'id': id, 'name': name, 'kind': kind, 'currency': 'USD'};
        if (index < 0) { categories.add(after); } else { categories[index] = after; }
        break;
      case 'transaction':
      case 'void':
        final index = transactions.indexWhere((t) => t['id'] == id);
        if ((action == 'void' || input['id'] != null) && index < 0) fail('Transaction was not found.');
        if (index >= 0) {
          before = transactions[index];
          if (input['expectedVersion'] != before['version']) fail('Transaction changed. Refresh before editing.');
          if (before['voided'] == true) fail('This transaction is already voided.');
        }
        if (action == 'void') {
          final original = before!;
          after = {...original, 'voided': true, 'version': (original['version'] as int) + 1};
        } else {
          after = {
            'id': id, 'operationId': operation, 'kind': input['kind'], 'accountId': input['accountId'],
            'counterpartyAccountId': input['counterpartyAccountId'], 'amountMinor': minor(input['amountMinor']),
            'currency': input['currency'], 'effectiveDate': input['effectiveDate'],
            'payee': text(input['payee'] ?? '', 'Payee', 150, optional: true),
            'notes': text(input['notes'] ?? '', 'Notes', 500, optional: true),
            'splits': input['splits'] ?? <Json>[], 'voided': false,
            'version': (before?['version'] as int? ?? 0) + 1,
            'createdUtc': before?['createdUtc'] ?? DateTime.now().toUtc().toIso8601String(),
          };
          date(after['effectiveDate']);
          after['postings'] = postingsFor(after, accounts, categories);
        }
        if (index < 0) { transactions.add(after); } else { transactions[index] = after; }
        break;
      default:
        fail('Unsupported local operation.');
    }
    operations[operation] = fingerprint;
    next.addAll({'accounts': accounts, 'categories': categories, 'transactions': transactions,
      'operations': operations, 'revision': revision + 1,
      'audit': [...rows(next['audit']), {'operationId': operation, 'action': action,
        'objectId': id, 'atUtc': DateTime.now().toUtc().toIso8601String(), 'before': before, 'after': clone(after)}]});
    return LocalLedger(next);
  }

  static List<Json> postingsFor(Json t, List<Json> accounts, List<Json> categories) {
    final amount = minor(t['amountMinor']);
    if (t['currency'] != 'USD' || !accounts.any((a) => a['id'] == t['accountId'])) fail('Choose a valid USD account.');
    final kind = t['kind'];
    if (!['expense', 'income', 'transfer'].contains(kind)) fail('Unsupported transaction type.');
    final splits = rows(t['splits'] ?? []);
    final signed = kind == 'income' ? amount : -amount;
    final result = <Json>[{'ledgerId': t['accountId'], 'amountMinor': signed}];
    if (kind == 'transfer') {
      if (splits.isNotEmpty || t['accountId'] == t['counterpartyAccountId'] ||
          !accounts.any((a) => a['id'] == t['counterpartyAccountId'])) fail('Choose a different destination account. Transfers cannot be split.');
      result.add({'ledgerId': t['counterpartyAccountId'], 'amountMinor': amount});
    } else {
      final lines = splits.isEmpty ? <Json>[{'categoryId': t['counterpartyAccountId'], 'amountMinor': amount}] : splits;
      if (lines.length > 50) fail('A transaction can have at most 50 splits.');
      var total = 0;
      for (final line in lines) {
        final part = minor(line['amountMinor']);
        final categoryKind = kind == 'expense' ? 'Expense' : 'Income';
        if (!categories.any((c) => c['id'] == line['categoryId'] && c['kind'] == categoryKind)) fail('Choose a valid $categoryKind category.');
        total += part;
        result.add({'ledgerId': 'category:${line['categoryId']}', 'amountMinor': kind == 'income' ? -part : part});
      }
      if (total != amount) fail('Split amounts must equal the transaction total.');
    }
    if (result.fold<int>(0, (s, p) => s + (p['amountMinor'] as int)) != 0) fail('Unbalanced transaction.');
    return result;
  }

  void validate() {
    if (data['schema'] != schema) fail('This workspace schema is not supported. Do not replace or reset it.');
    if (data['revision'] is! int || revision < 0 || data['operations'] is! Map || data['audit'] is! List) fail('Invalid workspace structure.');
    final accounts = rows(data['accounts']);
    final categories = rows(data['categories']);
    final transactions = rows(data['transactions']);
    final ids = <String>{};
    for (final item in [...accounts, ...categories, ...transactions]) {
      final id = text(item['id'], 'Record identifier', 100);
      if (!ids.add(id)) fail('Duplicate record identifier.');
    }
    for (final a in accounts) {
      text(a['name'], 'Account name', 100); minor(a['openingBalanceMinor'], signed: true);
      if (a['currency'] != 'USD' || !accountTypes.contains(a['type']) || a['version'] is! int || a['version'] < 1) fail('Invalid account record.');
    }
    for (final c in categories) {
      text(c['name'], 'Category name', 80);
      if (!['Income', 'Expense'].contains(c['kind']) || c['currency'] != 'USD') fail('Invalid category record.');
    }
    for (final t in transactions) {
      date(t['effectiveDate']); text(t['payee'], 'Payee', 150, optional: true); text(t['notes'], 'Notes', 500, optional: true);
      if (t['version'] is! int || t['version'] < 1 || t['voided'] is! bool) fail('Invalid transaction revision.');
      final expected = postingsFor(t, accounts, categories);
      if (jsonEncode(_canonical(expected)) != jsonEncode(_canonical(t['postings']))) fail('Transaction postings do not match its details.');
    }
    // Opening balances have an equal-and-opposite equity posting.
    final balances = <String, int>{for (final a in accounts) a['id'] as String: a['openingBalanceMinor'] as int};
    for (final t in transactions.where((t) => t['voided'] != true)) {
      for (final p in rows(t['postings'])) {
        final id = p['ledgerId'] as String;
        if (balances.containsKey(id)) balances[id] = balances[id]! + (p['amountMinor'] as int);
      }
    }
    for (final value in balances.values) { minor(value, signed: true); }
  }

  Json snapshot({bool includeVoided = false}) {
    final accounts = rows(clone(data)['accounts']);
    final transactions = rows(clone(data)['transactions']);
    final balances = {for (final a in accounts) a['id']: a['openingBalanceMinor'] as int};
    for (final t in transactions.where((t) => t['voided'] != true)) {
      for (final p in rows(t['postings'])) {
        if (balances.containsKey(p['ledgerId'])) balances[p['ledgerId']] = balances[p['ledgerId']]! + (p['amountMinor'] as int);
      }
    }
    return {'cursor': revision, 'accounts': [for (final a in accounts) {...a, 'balanceMinor': balances[a['id']]}],
      'categories': rows(clone(data)['categories']),
      'transactions': transactions.where((t) => includeVoided || t['voided'] != true).toList()};
  }
}
