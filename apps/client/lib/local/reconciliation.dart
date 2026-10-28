part of 'ledger.dart';

/// Statement checks are metadata, never balancing transactions. Each account
/// reconciles its own side of a transfer; active statements lock both sides.
class Reconciliation {
  static const maxEntries = 2000;
  static List<Json> history(Json data, String accountId) =>
      LocalLedger.rows(data['reconciliations'] ?? <Json>[])
          .where((s) => s['accountId'] == accountId).toList();
  static List<Json> active(Json data, String accountId) =>
      history(data, accountId).where((s) => s['reopened'] == false).toList();
  static int effect(Json transaction, String accountId) =>
      LocalLedger.rows(transaction['postings']).where((p) => p['ledgerId'] == accountId)
          .fold<int>(0, (sum, p) => sum + (p['amountMinor'] as int));
  static Set<String> checkedIds(Json data, String accountId) => {
    for (final statement in active(data, accountId))
      for (final entry in LocalLedger.rows(statement['entries'])) entry['transactionId'] as String,
  };
  static bool locked(Json data, String transactionId) =>
      LocalLedger.rows(data['reconciliations'] ?? <Json>[]).any((s) => s['reopened'] == false &&
        LocalLedger.rows(s['entries']).any((e) => e['transactionId'] == transactionId));
  static Json account(Json data, String accountId) => LocalLedger.rows(data['accounts'])
      .firstWhere((a) => a['id'] == accountId, orElse: () => LocalLedger.fail('Choose an existing account.'));
  static int opening(Json data, String accountId) {
    final previous = active(data, accountId);
    return previous.isEmpty ? account(data, accountId)['openingBalanceMinor'] as int
        : previous.last['closingMinor'] as int;
  }
  static List<Json> candidates(Json data, String accountId, String endDate) {
    account(data, accountId); LocalLedger.date(endDate);
    final done = checkedIds(data, accountId);
    final result = LocalLedger.rows(data['transactions']).where((t) => t['voided'] == false &&
        !done.contains(t['id']) && (t['effectiveDate'] as String).compareTo(endDate) <= 0 &&
        effect(t, accountId) != 0).toList();
    result.sort((a, b) {
      final date = (a['effectiveDate'] as String).compareTo(b['effectiveDate'] as String);
      return date != 0 ? date : (a['id'] as String).compareTo(b['id'] as String);
    });
    return result;
  }
  static int total(int start, Iterable<int> amounts) {
    var result = BigInt.from(start);
    for (final amount in amounts) { result += BigInt.from(amount); }
    if (result.abs() > BigInt.from(LocalLedger.maxMinor)) {
      LocalLedger.fail('Statement total exceeds the supported amount range.');
    }
    return result.toInt();
  }
  static void _revision(Json data, Json input) {
    if (input['expectedRevision'] != data['revision']) {
      LocalLedger.fail('Workspace changed. Close the review and refresh before reconciling.');
    }
  }
  static Json finish(Json next, Json input, String operation, String id) {
    _revision(next, input);
    if (input['confirmReviewed'] != true) LocalLedger.fail('Review and confirm the statement first.');
    final accountId = LocalLedger.text(input['accountId'], 'Statement account', 100);
    account(next, accountId);
    final endDate = input['endDate']; LocalLedger.date(endDate);
    final closing = LocalLedger.minor(input['closingMinor'], signed: true);
    final previous = active(next, accountId);
    if (previous.isNotEmpty && (endDate as String).compareTo(previous.last['endDate'] as String) <= 0) {
      LocalLedger.fail('Choose a later ending date or reopen the latest statement first.');
    }
    if (input['transactionIds'] is! List || (input['transactionIds'] as List).length > maxEntries) {
      LocalLedger.fail('Select at most $maxEntries statement transactions.');
    }
    final selected = <String>{};
    for (final value in input['transactionIds'] as List) {
      if (!selected.add(LocalLedger.text(value, 'Transaction identifier', 100))) {
        LocalLedger.fail('A transaction was selected twice.');
      }
    }
    final eligible = candidates(next, accountId, endDate as String);
    final entries = <Json>[for (final t in eligible.where((t) => selected.contains(t['id'])))
      {'transactionId': t['id'], 'date': t['effectiveDate'], 'amountMinor': effect(t, accountId)}];
    if (entries.length != selected.length) {
      LocalLedger.fail('A selected transaction is already reconciled, voided, future-dated or belongs to another account.');
    }
    final start = opening(next, accountId);
    if (total(start, entries.map((e) => e['amountMinor'] as int)) != closing) {
      LocalLedger.fail('The statement difference must be exactly zero. No adjustment was created.');
    }
    if ((next['schema'] as int) < LocalLedger.reconciliationSchema) {
      if (input['confirmReconciliationUpgrade'] != true) {
        LocalLedger.fail('Export a backup and confirm the reconciliation-history format upgrade first.');
      }
      next.addAll({'schema': LocalLedger.reconciliationSchema, 'budgets': next['budgets'] ?? <Json>[],
        'schedules': next['schedules'] ?? <Json>[], 'occurrences': next['occurrences'] ?? <Json>[],
        'imports': next['imports'] ?? <Json>[], 'reconciliations': <Json>[]});
    }
    final statement = <String, dynamic>{'id': id, 'accountId': accountId, 'endDate': endDate,
      'openingMinor': start, 'closingMinor': closing, 'previousId': previous.isEmpty ? null : previous.last['id'],
      'entries': entries, 'note': LocalLedger.text(input['note'] ?? '', 'Statement note', 300, optional: true),
      'reopened': false, 'version': 1, 'operationId': operation, 'createdUtc': DateTime.now().toUtc().toIso8601String()};
    next['reconciliations'] = [...LocalLedger.rows(next['reconciliations']), statement];
    return statement;
  }
  static Json reopen(Json next, Json input, String operation) {
    _revision(next, input);
    if (input['confirmReopen'] != true) LocalLedger.fail('Confirm reopening this statement.');
    final statements = LocalLedger.rows(next['reconciliations'] ?? <Json>[]);
    final index = statements.indexWhere((s) => s['id'] == input['id']);
    if (index < 0) LocalLedger.fail('Statement was not found.');
    final before = statements[index];
    if (before['reopened'] == true || before['version'] != input['expectedVersion']) {
      LocalLedger.fail('Statement changed. Refresh before reopening.');
    }
    if (active(next, before['accountId'] as String).last['id'] != before['id']) {
      LocalLedger.fail('Reopen later statements for this account first.');
    }
    final after = {...before, 'reopened': true, 'version': (before['version'] as int) + 1,
      'reopenReason': LocalLedger.text(input['reason'], 'Reopening reason', 300),
      'reopenOperationId': operation, 'reopenedUtc': DateTime.now().toUtc().toIso8601String()};
    statements[index] = after; next['reconciliations'] = statements;
    return after;
  }
  static void validate(Json data, List<Json> accounts, List<Json> transactions, Set<String> ids) {
    if ((data['schema'] as int) < LocalLedger.reconciliationSchema) {
      if (data.containsKey('reconciliations') && (data['reconciliations'] is! List ||
          (data['reconciliations'] as List).isNotEmpty)) {
        LocalLedger.fail('Reconciliation history requires the upgraded workspace schema.');
      }
      return;
    }
    if (data['reconciliations'] is! List) LocalLedger.fail('Reconciliation history is missing.');
    final byAccount = {for (final a in accounts) a['id']: a};
    final byTransaction = {for (final t in transactions) t['id']: t};
    final latest = <String, Json>{}, used = <String>{};
    for (final s in LocalLedger.rows(data['reconciliations'])) {
      if (!ids.add(LocalLedger.text(s['id'], 'Statement identifier', 100))) LocalLedger.fail('Duplicate statement identifier.');
      final accountId = LocalLedger.text(s['accountId'], 'Statement account', 100);
      LocalLedger.date(s['endDate']); LocalLedger.text(s['note'], 'Statement note', 300, optional: true);
      final start = LocalLedger.minor(s['openingMinor'], signed: true);
      final closing = LocalLedger.minor(s['closingMinor'], signed: true);
      if (!byAccount.containsKey(accountId) || s['entries'] is! List ||
          (s['entries'] as List).length > maxEntries || s['reopened'] is! bool ||
          s['version'] != (s['reopened'] == true ? 2 : 1) ||
          s['createdUtc'] is! String || DateTime.tryParse(s['createdUtc'] as String) == null ||
          !(data['operations'] as Map).containsKey(s['operationId'])) {
        LocalLedger.fail('Invalid statement history.');
      }
      final entries = LocalLedger.rows(s['entries']); final selected = <String>{};
      for (final e in entries) {
        final transactionId = LocalLedger.text(e['transactionId'], 'Statement transaction', 100);
        LocalLedger.date(e['date']);
        final amount = LocalLedger.minor(e['amountMinor'], signed: true);
        if (!selected.add(transactionId) || !byTransaction.containsKey(transactionId) || amount == 0 ||
            (e['date'] as String).compareTo(s['endDate'] as String) > 0) {
          LocalLedger.fail('Invalid statement transaction.');
        }
        if (s['reopened'] == false) {
          final t = byTransaction[transactionId]!;
          if (t['voided'] != false || t['effectiveDate'] != e['date'] || effect(t, accountId) != amount ||
              !used.add('$accountId|$transactionId')) {
            LocalLedger.fail('A reconciled transaction changed or was selected more than once.');
          }
        }
      }
      if (total(start, entries.map((e) => e['amountMinor'] as int)) != closing) {
        LocalLedger.fail('Statement history does not balance.');
      }
      if (s['reopened'] == true) {
        LocalLedger.text(s['reopenReason'], 'Reopening reason', 300);
        if (!(data['operations'] as Map).containsKey(s['reopenOperationId']) ||
            s['reopenedUtc'] is! String || DateTime.tryParse(s['reopenedUtc'] as String) == null) {
          LocalLedger.fail('Invalid statement reopening history.');
        }
      } else {
        final prior = latest[accountId];
        if (s['previousId'] != prior?['id'] || start != (prior?['closingMinor'] ?? byAccount[accountId]!['openingBalanceMinor']) ||
            (prior != null && (s['endDate'] as String).compareTo(prior['endDate'] as String) <= 0)) {
          LocalLedger.fail('Statement sequence or opening balance changed.');
        }
        latest[accountId] = s;
      }
    }
  }
}
