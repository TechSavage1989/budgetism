import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'recurrence.dart';

part 'schedule_rules.dart';
part 'schedule_matching.dart';
part 'import_rules.dart';
part 'import_profiles.dart';
part 'reconciliation.dart';
part 'category_rules.dart';
part 'category_history.dart';
part 'bank_sync.dart';

typedef Json = Map<String, dynamic>;

/// Exact USD ledger. No IO, network calls, floating-point balances or sample data.
class LocalLedger {
  LocalLedger(Json source) : data = clone(source) { validate(); }
  final Json data;
  static const schema = 3;
  static const importSchema = 4;
  static const importProfileSchema = 7;
  static const bankSchema = 8;
  static const reconciliationSchema = 5;
  static const categoryRuleSchema = 6;
  static const budgetSchema = 2;
  static const legacySchema = 1;
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
    'operations': <String, dynamic>{}, 'audit': <Json>[], 'budgets': <Json>[],
    'schedules': <Json>[], 'occurrences': <Json>[],
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
  static String budgetMonth(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value) ||
        int.parse(value.substring(0, 4)) < 1900) {
      fail('Choose a month between January 1900 and December 9999.');
    }
    return value;
  }
  static String shiftMonth(String value, int delta) {
    budgetMonth(value);
    final index = int.parse(value.substring(0, 4)) * 12 + int.parse(value.substring(5)) - 1 + delta;
    if (index < 1900 * 12 || index >= 10000 * 12) fail('Month is outside the supported range.');
    return '${(index ~/ 12).toString().padLeft(4, '0')}-${(index % 12 + 1).toString().padLeft(2, '0')}';
  }
  static const rolloverModes = ['none', 'positive', 'all'];
  static int budgetAmount(Object? value) {
    final result = minor(value, signed: true);
    if (result < 0) fail('A budget allocation cannot be negative.');
    return result;
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
    if (action == 'bank-refresh' && BankSync.isReplay(data, input) &&
        BankSync.connection(data, input['connectionId'])['refreshStatus'] != 'error') return this;
    final next = clone(data);
    final accounts = rows(next['accounts']);
    final categories = rows(next['categories']);
    final transactions = rows(next['transactions']);
    var id = input['id'] as String? ?? const Uuid().v4();
    Json? before;
    Json after;
    final budgets = rows(next['budgets'] ?? <Json>[]);
    if (['budget', 'budget-remove', 'budget-copy'].contains(action) && next['schema'] == legacySchema) {
      if (input['confirmSchemaUpgrade'] != true) {
        fail('Export a backup and confirm the budgeting format upgrade before saving your first budget.');
      }
      next['schema'] = budgetSchema;
      next['budgets'] = budgets;
    }
    if (_ScheduleRules.actions.contains(action) && (next['schema'] as int) < schema) {
      if (input['confirmScheduleUpgrade'] != true) {
        fail('Export a backup and confirm the recurring-schedule format upgrade first.');
      }
      next.addAll({'schema': schema, 'budgets': budgets,
        'schedules': <Json>[], 'occurrences': <Json>[]});
    }
    switch (action) {
      case 'bank-connect':
      case 'bank-refresh':
      case 'bank-failure':
      case 'bank-state':
      case 'bank-review':
        after = BankSync.apply(next, action, input, operation, accounts, categories, transactions);
        break;
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
        if (before != null && Reconciliation.active(data, id).isNotEmpty &&
            (before['openingBalanceMinor'] != input['openingBalanceMinor'] || before['type'] != input['type'])) {
          fail('Reopen the account statements before changing its opening balance or type.');
        }
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
          if (Reconciliation.locked(data, id)) {
            fail('This transaction is reconciled. Reopen its statement in Reconcile before editing or deleting it.');
          }
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
            if (before?.containsKey('scheduleId') == true) ...{
              'scheduleId': before!['scheduleId'], 'occurrenceIndex': before['occurrenceIndex'],
            },
          };
          date(after['effectiveDate']);
          after['postings'] = postingsFor(after, accounts, categories);
        }
        if (index < 0) { transactions.add(after); } else { transactions[index] = after; }
        break;
      case 'budget':
      case 'budget-remove':
        final month = budgetMonth(input['month']);
        final categoryId = input['categoryId'];
        if (!categories.any((c) => c['id'] == categoryId && c['kind'] == 'Expense')) {
          fail('Choose an expense category for this budget.');
        }
        final index = budgets.indexWhere((b) => b['month'] == month && b['categoryId'] == categoryId);
        before = index < 0 ? null : budgets[index];
        if (input['expectedVersion'] != (before?['version'] ?? 0)) {
          fail('Budget changed. Refresh before editing.');
        }
        if (before != null) id = before['id'] as String;
        if (action == 'budget-remove') {
          if (before == null || before['removed'] == true) fail('There is no allocation to remove.');
          after = {...before, 'amountMinor': 0, 'rollover': 'none', 'removed': true,
            'version': (before['version'] as int) + 1};
        } else {
          if (!rolloverModes.contains(input['rollover'])) fail('Choose a supported rollover rule.');
          after = {'id': id, 'categoryId': categoryId, 'month': month,
            'amountMinor': budgetAmount(input['amountMinor']), 'rollover': input['rollover'],
            'removed': false, 'version': (before?['version'] as int? ?? 0) + 1};
        }
        if (index < 0) { budgets.add(after); } else { budgets[index] = after; }
        next['budgets'] = budgets;
        break;
      case 'budget-copy':
        final target = budgetMonth(input['month']);
        final source = shiftMonth(target, -1);
        if (input['expectedRevision'] != revision) fail('Workspace changed. Refresh before copying budgets.');
        if (input['replaceExisting'] is! bool) fail('Choose whether existing allocations can be replaced.');
        final previous = budgets.where((b) => b['month'] == source && b['removed'] != true).toList();
        if (previous.isEmpty) fail('The previous month has no allocations to copy.');
        final changes = <Json>[];
        for (final plan in previous) {
          final index = budgets.indexWhere((b) => b['month'] == target && b['categoryId'] == plan['categoryId']);
          if (index >= 0 && input['replaceExisting'] != true) continue;
          final old = index < 0 ? null : budgets[index];
          final copied = {...plan, 'id': old?['id'] ?? const Uuid().v4(), 'month': target,
            'version': (old?['version'] as int? ?? 0) + 1, 'removed': false};
          if (index < 0) { budgets.add(copied); } else { budgets[index] = copied; }
          changes.add({'before': old, 'after': clone(copied)});
        }
        if (changes.isEmpty) fail('All allocations already exist. Enable replacement to overwrite them.');
        next['budgets'] = budgets;
        after = {'sourceMonth': source, 'month': target, 'changes': changes};
        break;
      case 'category-undo':
        after = CategoryHistory.undo(next, input, operation, accounts, categories, transactions);
        break;
      case 'category-rule':
        before = rows(next['categoryRules'] ?? <Json>[]).where((r) => r['id'] == id).firstOrNull;
        after = CategoryRules.save(next, input, id, operation);
        break;
      case 'categorize':
        after = CategoryRules.apply(next, input, operation, accounts, categories, transactions);
        break;
      case 'reconcile':
        after = Reconciliation.finish(next, input, operation, id);
        break;
      case 'reconcile-reopen':
        before = rows(next['reconciliations'] ?? <Json>[]).where((s) => s['id'] == id).firstOrNull;
        after = Reconciliation.reopen(next, input, operation);
        break;
      case 'import-profile':
      case 'import-profile-state':
        before = rows(next['importProfiles'] ?? <Json>[]).where((p) => p['id'] == id).firstOrNull;
        after = action == 'import-profile'
            ? ImportProfiles.save(next, input, id, operation)
            : ImportProfiles.setArchived(next, input, id, operation);
        break;
      case 'import-csv':
        after = _ImportRules.apply(next, input, operation, accounts, categories, transactions);
        break;
      case 'schedule':
      case 'schedule-state':
      case 'schedule-confirm':
      case 'schedule-match':
      case 'schedule-postpone':
      case 'schedule-skip':
        final change = _ScheduleRules.apply(next, action, input, operation, accounts, categories, transactions);
        id = change.id; before = change.before; after = change.after;
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
          !accounts.any((a) => a['id'] == t['counterpartyAccountId'])) { fail('Choose a different destination account. Transfers cannot be split.'); }
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
    if (data['schema'] is! int || ![legacySchema, budgetSchema, schema, importSchema, reconciliationSchema, categoryRuleSchema, importProfileSchema, bankSchema].contains(data['schema'])) fail('This workspace schema is not supported. Do not replace or reset it.');
    if (data['schema'] != legacySchema && data['budgets'] is! List) fail('Budget records are missing from this workspace.');
    if (data['schema'] == legacySchema && data.containsKey('budgets') && (data['budgets'] is! List || (data['budgets'] as List).isNotEmpty)) fail('Budget records require the upgraded workspace schema.');
    if (data['revision'] is! int || revision < 0 || data['operations'] is! Map || data['audit'] is! List) fail('Invalid workspace structure.');
    final accounts = rows(data['accounts']);
    final categories = rows(data['categories']);
    final transactions = rows(data['transactions']);
    final ids = <String>{};
    final budgets = rows(data['budgets'] ?? <Json>[]);
    for (final item in [...accounts, ...categories, ...transactions, ...budgets]) {
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
    final budgetKeys = <String>{};
    for (final b in budgets) {
      final month = budgetMonth(b['month']);
      budgetAmount(b['amountMinor']);
      if (!categories.any((c) => c['id'] == b['categoryId'] && c['kind'] == 'Expense') ||
          !rolloverModes.contains(b['rollover']) || b['removed'] is! bool ||
          b['version'] is! int || (b['version'] as int) < 1 ||
          (b['removed'] == true && (b['amountMinor'] != 0 || b['rollover'] != 'none'))) {
        fail('Invalid category budget record.');
      }
      if (!budgetKeys.add('$month|${b['categoryId']}')) fail('Duplicate category budget for the same month.');
    }
    _ScheduleRules.validate(data, accounts, categories, transactions, ids);
    _ImportRules.validate(data, accounts, transactions, ids);
    Reconciliation.validate(data, accounts, transactions, ids);
    CategoryRules.validate(data, accounts, categories, ids);
    ImportProfiles.validate(data, categories, ids);
    BankSync.validate(data, accounts, transactions, ids);
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
    return {'schema': data['schema'],
      for (final key in BankSync.collections) key: rows(clone(data)[key] ?? <Json>[]),
      'importProfiles': rows(clone(data)['importProfiles'] ?? <Json>[]), 'categoryRules': rows(clone(data)['categoryRules'] ?? <Json>[]), 'reconciliations': rows(clone(data)['reconciliations'] ?? <Json>[]), 'imports': rows(clone(data)['imports'] ?? <Json>[]), 'budgets': rows(clone(data)['budgets'] ?? <Json>[]),
      'schedules': rows(clone(data)['schedules'] ?? <Json>[]),
      'occurrences': rows(clone(data)['occurrences'] ?? <Json>[]),
      'cursor': revision, 'accounts': [for (final a in accounts) {...a, 'balanceMinor': balances[a['id']]}],
      'categories': rows(clone(data)['categories']),
      'transactions': transactions.where((t) => includeVoided || t['voided'] != true).toList()};
  }
}
