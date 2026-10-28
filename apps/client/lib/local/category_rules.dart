part of 'ledger.dart';

/// Saved, local category rules. Nothing runs on startup, import, or a timer.
/// Every existing-transaction change is previewed and explicitly committed.
class CategoryRules {
  static const maxRules = 100;
  static const maxBatch = 500;
  static const modes = ['contains', 'exact', 'prefix'];
  static const sources = ['all', 'statement', 'manual'];

  static List<Json> ordered(Json data) => LocalLedger.rows(data['categoryRules'] ?? <Json>[])
    ..sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));

  static void _fields(Json rule, List<Json> accounts, List<Json> categories) {
    LocalLedger.text(rule['name'], 'Rule name', 80);
    LocalLedger.text(rule['pattern'], 'Payee text', 150);
    if (!['expense', 'income'].contains(rule['kind']) || !modes.contains(rule['mode']) ||
        !sources.contains(rule['source']) || rule['enabled'] is! bool ||
        rule['priority'] is! int || rule['priority'] < 1 || rule['priority'] > 9999) {
      LocalLedger.fail('Choose a transaction type, match mode, source and priority from 1 to 9999.');
    }
    if (rule['accountId'] != null && !accounts.any((a) => a['id'] == rule['accountId'])) {
      LocalLedger.fail('Choose an existing rule account.');
    }
    final kind = rule['kind'] == 'expense' ? 'Expense' : 'Income';
    for (final key in ['categoryId', 'fromCategoryId']) {
      if (key == 'fromCategoryId' && rule[key] == null) continue;
      if (!categories.any((c) => c['id'] == rule[key] && c['kind'] == kind && c['currency'] == 'USD')) {
        LocalLedger.fail('Choose a valid $kind category for this rule.');
      }
    }
    for (final key in ['minimumMinor', 'maximumMinor']) {
      if (rule[key] != null) LocalLedger.minor(rule[key]);
    }
    if (rule['minimumMinor'] != null && rule['maximumMinor'] != null &&
        (rule['minimumMinor'] as int) > (rule['maximumMinor'] as int)) {
      LocalLedger.fail('The minimum amount cannot exceed the maximum.');
    }
  }

  static void _revision(Json data, Json input) {
    if (input['expectedRevision'] != data['revision']) {
      LocalLedger.fail('Workspace changed. Refresh the rules and review again.');
    }
  }

  static Json save(Json next, Json input, String id, String operation) {
    _revision(next, input);
    final rules = ordered(next);
    final index = rules.indexWhere((r) => r['id'] == id);
    if (input['id'] != null && index < 0) LocalLedger.fail('Rule was not found.');
    final before = index < 0 ? null : rules[index];
    if (before != null && before['version'] != input['expectedVersion']) {
      LocalLedger.fail('Rule changed. Refresh before editing.');
    }
    final rule = <String, dynamic>{'id': id,
      'name': LocalLedger.text(input['name'], 'Rule name', 80),
      'pattern': LocalLedger.text(input['pattern'], 'Payee text', 150),
      for (final key in ['kind', 'mode', 'source', 'enabled', 'priority', 'accountId',
        'categoryId', 'fromCategoryId', 'minimumMinor', 'maximumMinor']) key: input[key],
      'version': (before?['version'] as int? ?? 0) + 1, 'operationId': operation,
    };
    _fields(rule, LocalLedger.rows(next['accounts']), LocalLedger.rows(next['categories']));
    if (rules.any((r) => r['id'] != id && (r['priority'] == rule['priority'] ||
        (r['name'] as String).toLowerCase() == (rule['name'] as String).toLowerCase()))) {
      LocalLedger.fail('Each rule needs a different name and priority, including disabled rules.');
    }
    if (before == null && rules.length >= maxRules) LocalLedger.fail('This preview supports at most $maxRules rules.');
    if ((next['schema'] as int) < LocalLedger.categoryRuleSchema) {
      if (input['confirmRuleUpgrade'] != true) {
        LocalLedger.fail('Export a backup and confirm the saved-rules format upgrade first.');
      }
      next.addAll({'schema': LocalLedger.categoryRuleSchema,
        'budgets': next['budgets'] ?? <Json>[], 'schedules': next['schedules'] ?? <Json>[],
        'occurrences': next['occurrences'] ?? <Json>[], 'imports': next['imports'] ?? <Json>[],
        'reconciliations': next['reconciliations'] ?? <Json>[], 'categoryRules': <Json>[],
      });
    }
    if (index < 0) { rules.add(rule); } else { rules[index] = rule; }
    next['categoryRules'] = rules;
    return rule;
  }

  static bool matches(Json rule, Json transaction, bool statementLinked) {
    if (rule['enabled'] != true || transaction['kind'] != rule['kind'] ||
        (rule['accountId'] != null && rule['accountId'] != transaction['accountId']) ||
        (rule['fromCategoryId'] != null && rule['fromCategoryId'] != transaction['counterpartyAccountId']) ||
        (rule['source'] == 'statement' && !statementLinked) ||
        (rule['source'] == 'manual' && statementLinked)) { return false; }
    final amount = transaction['amountMinor'] as int;
    if ((rule['minimumMinor'] != null && amount < (rule['minimumMinor'] as int)) ||
        (rule['maximumMinor'] != null && amount > (rule['maximumMinor'] as int))) { return false; }
    final payee = (transaction['payee'] as String).trim().toLowerCase();
    final pattern = (rule['pattern'] as String).trim().toLowerCase();
    return switch (rule['mode']) {
      'exact' => payee == pattern,
      'prefix' => payee.startsWith(pattern),
      'contains' => payee.contains(pattern),
      _ => false,
    };
  }

  /// First matching enabled rule wins, even if its category is already set.
  /// Rules never cascade through one transaction within this preview/batch.
  static List<Json> preview(Json data, {required String from, required String through}) {
    LocalLedger.date(from); LocalLedger.date(through);
    if (from.compareTo(through) > 0) LocalLedger.fail('The start date must not follow the end date.');
    final rules = ordered(data).where((r) => r['enabled'] == true).toList();
    final statementLinked = LocalLedger.rows(data['imports'] ?? <Json>[])
        .map((r) => r['transactionId']).toSet();
    final locked = <String>{
      for (final s in LocalLedger.rows(data['reconciliations'] ?? <Json>[]).where((s) => s['reopened'] == false))
        for (final e in LocalLedger.rows(s['entries'])) e['transactionId'] as String,
    };
    final result = <Json>[];
    for (final t in LocalLedger.rows(data['transactions'])) {
      if (t['voided'] != false || !['income', 'expense'].contains(t['kind']) ||
          LocalLedger.rows(t['splits'] ?? <Json>[]).isNotEmpty || locked.contains(t['id']) ||
          (t['effectiveDate'] as String).compareTo(from) < 0 ||
          (t['effectiveDate'] as String).compareTo(through) > 0) { continue; }
      final rule = rules.where((r) => matches(r, t, statementLinked.contains(t['id']))).firstOrNull;
      if (rule == null || rule['categoryId'] == t['counterpartyAccountId']) continue;
      result.add({'transactionId': t['id'], 'expectedVersion': t['version'],
        'ruleId': rule['id'], 'expectedRuleVersion': rule['version'],
        'categoryId': rule['categoryId'], 'fromCategoryId': t['counterpartyAccountId']});
    }
    final dates = {for (final t in LocalLedger.rows(data['transactions'])) t['id']: t['effectiveDate'] as String};
    result.sort((a, b) {
      final date = dates[a['transactionId']]!.compareTo(dates[b['transactionId']]!);
      return date != 0 ? date : (a['transactionId'] as String).compareTo(b['transactionId'] as String);
    });
    return result;
  }

  static Json apply(Json next, Json input, String operation, List<Json> accounts,
      List<Json> categories, List<Json> transactions) {
    _revision(next, input);
    if (input['confirmReviewed'] != true) LocalLedger.fail('Review and confirm the selected category changes.');
    if (input['selections'] is! List || (input['selections'] as List).isEmpty ||
        (input['selections'] as List).length > maxBatch) {
      LocalLedger.fail('Select between 1 and $maxBatch category changes.');
    }
    final from = LocalLedger.text(input['from'], 'Start date', 10);
    final through = LocalLedger.text(input['through'], 'End date', 10);
    final proposals = {for (final p in preview(next, from: from, through: through)) p['transactionId']: p};
    final seen = <String>{};
    final updates = <Json>[];
    for (final selected in LocalLedger.rows(input['selections'])) {
      final id = LocalLedger.text(selected['transactionId'], 'Transaction identifier', 100);
      final proposal = proposals[id];
      if (!seen.add(id) || proposal == null ||
          proposal.keys.any((key) => proposal[key] != selected[key])) {
        LocalLedger.fail('A selected change is stale, protected, duplicated or no longer matches. Regenerate the preview.');
      }
      final index = transactions.indexWhere((t) => t['id'] == id);
      final before = transactions[index];
      final after = {...before, 'counterpartyAccountId': proposal['categoryId'],
        'version': (before['version'] as int) + 1};
      after['postings'] = LocalLedger.postingsFor(after, accounts, categories);
      transactions[index] = after;
      updates.add({'operationId': operation, 'action': 'categorize-transaction', 'objectId': id,
        'ruleId': proposal['ruleId'], 'ruleVersion': proposal['expectedRuleVersion'],
        'atUtc': DateTime.now().toUtc().toIso8601String(),
        'before': LocalLedger.clone(before), 'after': LocalLedger.clone(after)});
    }
    next['audit'] = [...LocalLedger.rows(next['audit']), ...updates];
    return {'from': from, 'through': through, 'transactionIds': seen.toList(), 'count': seen.length};
  }

  static void validate(Json data, List<Json> accounts, List<Json> categories, Set<String> ids) {
    if ((data['schema'] as int) < LocalLedger.categoryRuleSchema) {
      if (data.containsKey('categoryRules') &&
          (data['categoryRules'] is! List || (data['categoryRules'] as List).isNotEmpty)) {
        LocalLedger.fail('Saved rules require the upgraded workspace format.');
      }
      return;
    }
    if (data['categoryRules'] is! List || (data['categoryRules'] as List).length > maxRules) {
      LocalLedger.fail('Invalid saved category rules.');
    }
    final priorities = <int>{}, names = <String>{};
    for (final r in LocalLedger.rows(data['categoryRules'])) {
      _fields(r, accounts, categories);
      if (!ids.add(LocalLedger.text(r['id'], 'Rule identifier', 100)) ||
          r['version'] is! int || r['version'] < 1 ||
          r['operationId'] is! String || !(data['operations'] as Map).containsKey(r['operationId']) ||
          !priorities.add(r['priority'] as int) || !names.add((r['name'] as String).toLowerCase())) {
        LocalLedger.fail('Invalid, duplicated or orphaned category rule.');
      }
    }
  }
}
