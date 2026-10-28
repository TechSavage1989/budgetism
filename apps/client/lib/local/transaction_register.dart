import '../money.dart';
import 'ledger.dart';

/// Session-only search state. No search text is persisted or transmitted.
class RegisterFilter {
  const RegisterFilter({this.query = '', this.accountId = '', this.categoryId = '',
    this.kind = 'all', this.status = 'active', this.source = 'all', this.from = '',
    this.through = '', this.minimum = '', this.maximum = '', this.sort = 'newest'});
  final String query, accountId, categoryId, kind, status, source;
  final String from, through, minimum, maximum, sort;
  RegisterFilter copyWith({String? query, String? accountId, String? categoryId,
    String? kind, String? status, String? source, String? from, String? through,
    String? minimum, String? maximum, String? sort}) => RegisterFilter(
      query: query ?? this.query, accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId, kind: kind ?? this.kind,
      status: status ?? this.status, source: source ?? this.source,
      from: from ?? this.from, through: through ?? this.through,
      minimum: minimum ?? this.minimum, maximum: maximum ?? this.maximum,
      sort: sort ?? this.sort);
  int get advancedCount => [accountId.isNotEmpty, categoryId.isNotEmpty,
    kind != 'all', status != 'active', source != 'all', from.isNotEmpty,
    through.isNotEmpty, minimum.isNotEmpty, maximum.isNotEmpty].where((v) => v).length;
}

class RegisterStatement {
  const RegisterStatement(this.id, this.accountId, this.accountName, this.endDate);
  final String id, accountId, accountName, endDate;
}

class RegisterEntry {
  RegisterEntry(Json transaction, {required this.accountName, required this.targetName,
    required Map<String, int> contributions, required Map<String, String> categoryNames,
    required List<Json> receipts, required List<RegisterStatement> statements,
    required this.statementLinkedInScope, required this.reconciledInScope,
    required this.scheduleName}) : _transaction = LocalLedger.clone(transaction),
      contributions = Map.unmodifiable(contributions), categoryNames = Map.unmodifiable(categoryNames),
      _receipts = receipts.map(LocalLedger.clone).toList(), statements = List.unmodifiable(statements);
  final Json _transaction;
  final List<Json> _receipts;
  final String accountName, targetName;
  final Map<String, int> contributions;
  final Map<String, String> categoryNames;
  final List<RegisterStatement> statements;
  final bool statementLinkedInScope, reconciledInScope;
  final String? scheduleName;
  Json get transaction => LocalLedger.clone(_transaction);
  List<Json> get receipts => _receipts.map(LocalLedger.clone).toList();
  String get id => _transaction['id'] as String;
  String get kind => _transaction['kind'] as String;
  String get date => _transaction['effectiveDate'] as String;
  String get payee => _transaction['payee'] as String;
  String get notes => _transaction['notes'] as String;
  int get amount => _transaction['amountMinor'] as int;
  bool get voided => _transaction['voided'] == true;
  bool get split => LocalLedger.rows(_transaction['splits'] ?? <Json>[]).isNotEmpty;
  bool get canEdit => !voided && statements.isEmpty;
  int contribution(String categoryId) => categoryId.isEmpty ? amount : contributions[categoryId] ?? 0;
  String get typeLabel => kind == 'transfer' ? 'Transfer / card payment' : kind == 'income' ? 'Income' : 'Expense';
  String get statusLabel => voided ? 'Voided' : reconciledInScope ? 'Reconciled' : 'Unreconciled';
}

class RegisterResult {
  RegisterResult(List<RegisterEntry> entries, {required this.income, required this.expenses,
    required this.transfers, required this.voidedCount}) : entries = List.unmodifiable(entries);
  final List<RegisterEntry> entries;
  final int income, expenses, transfers, voidedCount;
}

class _SearchTerm {
  const _SearchTerm(this.text, this.exclude);
  final String text;
  final bool exclude;
}

/// Derived register view over a validated local snapshot. Never mutates it.
class TransactionRegister {
  static const sorts = {'newest': 'Newest first', 'oldest': 'Oldest first',
    'largest': 'Largest amount', 'smallest': 'Smallest amount', 'payee': 'Payee A-Z'};
  static const statuses = {'active': 'Active records', 'all': 'All, including voided',
    'voided': 'Voided only', 'reconciled': 'Reconciled', 'unreconciled': 'Unreconciled'};
  static const sources = {'all': 'All sources', 'statement': 'Statement-linked', 'unlinked': 'No statement link'};
  static String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<_SearchTerm> _parse(String query) {
    if (query.length > 500) LocalLedger.fail('Search is limited to 500 characters.');
    final result = <_SearchTerm>[];
    var index = 0;
    bool space(String c) => RegExp(r'\s').hasMatch(c);
    while (index < query.length) {
      while (index < query.length && space(query[index])) { index++; }
      if (index == query.length) break;
      final exclude = query[index] == '-';
      if (exclude) index++;
      if (index == query.length || space(query[index])) LocalLedger.fail('Put a word or quoted phrase after the exclusion minus sign.');
      var token = '';
      if (query[index] == '"') {
        index++;
        while (index < query.length && query[index] != '"') { token += query[index++]; }
        if (index == query.length) LocalLedger.fail('Close the quoted search phrase.');
        index++;
        if (index < query.length && !space(query[index])) LocalLedger.fail('Separate search terms with spaces.');
      } else {
        while (index < query.length && !space(query[index])) {
          if (query[index] == '"') LocalLedger.fail('Put quotes around the whole search phrase.');
          token += query[index++];
        }
      }
      token = _normalize(token);
      if (token.isEmpty) LocalLedger.fail('Search phrases cannot be empty.');
      result.add(_SearchTerm(token, exclude));
      if (result.length > 32) LocalLedger.fail('Use at most 32 search terms.');
    }
    return result;
  }

  static int? _amount(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^(?:\d{1,12}|\d{1,3}(?:,\d{3}){1,3})(?:\.\d{1,2})?$').hasMatch(value)) {
      LocalLedger.fail('Amount filters need nonnegative USD amounts with at most two decimal places.');
    }
    return LocalLedger.minor(parseMinor(value), signed: true);
  }
  static int _total(BigInt value) {
    if (value.abs() > BigInt.from(LocalLedger.maxMinor)) {
      LocalLedger.fail('Matching totals exceed the supported amount range. Narrow the filters.');
    }
    return value.toInt();
  }

  static RegisterResult calculate(Json snapshot, RegisterFilter filter) {
    final accounts = {for (final a in LocalLedger.rows(snapshot['accounts'])) a['id'] as String: a['name'] as String};
    final categories = {for (final c in LocalLedger.rows(snapshot['categories'])) c['id'] as String: c['name'] as String};
    final schedules = {for (final s in LocalLedger.rows(snapshot['schedules'] ?? <Json>[])) s['id']: s['name'] as String};
    if (filter.accountId.isNotEmpty && !accounts.containsKey(filter.accountId)) LocalLedger.fail('Selected account is unavailable. Reset filters or choose another account.');
    if (filter.categoryId.isNotEmpty && !categories.containsKey(filter.categoryId)) LocalLedger.fail('Selected category is unavailable. Reset filters or choose another category.');
    if (!['all', 'income', 'expense', 'transfer'].contains(filter.kind) ||
        !statuses.containsKey(filter.status) || !sources.containsKey(filter.source) || !sorts.containsKey(filter.sort)) {
      LocalLedger.fail('Choose supported register filters.');
    }
    final from = filter.from.trim(), through = filter.through.trim();
    if (from.isNotEmpty) LocalLedger.date(from);
    if (through.isNotEmpty) LocalLedger.date(through);
    if (from.isNotEmpty && through.isNotEmpty && from.compareTo(through) > 0) LocalLedger.fail('From date must not follow Through date.');
    final minimum = _amount(filter.minimum), maximum = _amount(filter.maximum);
    if (minimum != null && maximum != null && minimum > maximum) LocalLedger.fail('Minimum amount must not exceed maximum amount.');
    final terms = _parse(filter.query);
    final receipts = <String, List<Json>>{};
    for (final r in LocalLedger.rows(snapshot['imports'] ?? <Json>[])) {
      receipts.putIfAbsent(r['transactionId'] as String, () => []).add(r);
    }
    final statements = <String, List<RegisterStatement>>{};
    for (final s in LocalLedger.rows(snapshot['reconciliations'] ?? <Json>[]).where((s) => s['reopened'] == false)) {
      for (final e in LocalLedger.rows(s['entries'])) {
        statements.putIfAbsent(e['transactionId'] as String, () => []).add(RegisterStatement(
          s['id'] as String, s['accountId'] as String, accounts[s['accountId']]!, s['endDate'] as String));
      }
    }
    final entries = <RegisterEntry>[];
    var income = BigInt.zero, expenses = BigInt.zero, transfers = BigInt.zero, voidedCount = 0;
    for (final t in LocalLedger.rows(snapshot['transactions'])) {
      final id = t['id'] as String, kind = t['kind'] as String, date = t['effectiveDate'] as String;
      final amount = t['amountMinor'] as int, voided = t['voided'] == true;
      final linkedReceipts = receipts[id] ?? <Json>[];
      final linkedStatements = statements[id] ?? <RegisterStatement>[];
      final statementLinked = linkedReceipts.any((r) => filter.accountId.isEmpty || r['accountId'] == filter.accountId);
      final reconciled = linkedStatements.any((s) => filter.accountId.isEmpty || s.accountId == filter.accountId);
      if (filter.accountId.isNotEmpty && t['accountId'] != filter.accountId &&
          !(kind == 'transfer' && t['counterpartyAccountId'] == filter.accountId)) { continue; }
      if (filter.kind != 'all' && kind != filter.kind) continue;
      if ((filter.status == 'voided' && !voided) ||
          (!['all', 'voided'].contains(filter.status) && voided) ||
          (filter.status == 'reconciled' && !reconciled) || (filter.status == 'unreconciled' && reconciled)) { continue; }
      if ((filter.source == 'statement' && !statementLinked) || (filter.source == 'unlinked' && statementLinked)) { continue; }
      if ((from.isNotEmpty && date.compareTo(from) < 0) || (through.isNotEmpty && date.compareTo(through) > 0) ||
          (minimum != null && amount < minimum) || (maximum != null && amount > maximum)) { continue; }
      final contributions = <String, int>{};
      if (kind != 'transfer') {
        final splits = LocalLedger.rows(t['splits'] ?? <Json>[]);
        if (splits.isEmpty) { contributions[t['counterpartyAccountId'] as String] = amount; }
        for (final part in splits) {
          final category = part['categoryId'] as String;
          contributions[category] = (contributions[category] ?? 0) + (part['amountMinor'] as int);
        }
      }
      if (filter.categoryId.isNotEmpty && !contributions.containsKey(filter.categoryId)) continue;
      final accountName = accounts[t['accountId']]!;
      final targetName = kind == 'transfer' ? accounts[t['counterpartyAccountId']]! :
        contributions.keys.map((id) => categories[id]!).join(', ');
      final fields = [t['payee'] as String, t['notes'] as String, accountName,
        if (kind == 'transfer') targetName, ...contributions.keys.map((id) => categories[id]!)].map(_normalize).toList();
      if (!terms.every((term) => fields.any((value) => value.contains(term.text)) != term.exclude)) continue;
      entries.add(RegisterEntry(t, accountName: accountName, targetName: targetName,
        contributions: contributions, categoryNames: {for (final id in contributions.keys) id: categories[id]!},
        receipts: linkedReceipts, statements: linkedStatements, statementLinkedInScope: statementLinked,
        reconciledInScope: reconciled, scheduleName: schedules[t['scheduleId']]));
      if (voided) { voidedCount++; continue; }
      final contribution = filter.categoryId.isEmpty ? amount : contributions[filter.categoryId]!;
      if (kind == 'income') income += BigInt.from(contribution);
      if (kind == 'expense') expenses += BigInt.from(contribution);
      if (kind == 'transfer') transfers += BigInt.from(amount);
    }
    entries.sort((a, b) {
      final primary = switch (filter.sort) {
        'oldest' => a.date.compareTo(b.date),
        'largest' => b.amount.compareTo(a.amount),
        'smallest' => a.amount.compareTo(b.amount),
        'payee' => _normalize(a.payee).compareTo(_normalize(b.payee)),
        _ => b.date.compareTo(a.date),
      };
      if (primary != 0) return primary;
      final date = b.date.compareTo(a.date);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return RegisterResult(entries, income: _total(income), expenses: _total(expenses),
      transfers: _total(transfers), voidedCount: voidedCount);
  }
}
