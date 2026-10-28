part of 'ledger.dart';

/// Reads existing encrypted audit records. Undo is a new, audited category-only
/// change, never a database rollback or a replay of historical transactions.
class CategoryHistory {
  static bool _equal(Object? a, Object? b) =>
      jsonEncode(LocalLedger._canonical(a)) == jsonEncode(LocalLedger._canonical(b));

  static List<Json> _audit(Json data) {
    if (data['audit'] is! List || (data['audit'] as List).any((r) => r is! Map)) {
      LocalLedger.fail('Categorization history is incomplete. No records were changed.');
    }
    return LocalLedger.rows(data['audit']);
  }

  static List<Json> batches(Json data) {
    final audit = _audit(data);
    final undone = <Object?, Json>{};
    for (final a in audit.where((a) => a['action'] == 'category-undo')) {
      if (a['after'] is Map) {
        final after = Map<String, dynamic>.from(a['after'] as Map);
        undone[after['sourceOperationId']] = {
          'atUtc': a['atUtc'], 'reason': after['reason'],
        };
      }
    }
    return [for (final a in audit.reversed.where((a) => a['action'] == 'categorize'))
      LocalLedger.clone({
        'operationId': a['operationId'], 'atUtc': a['atUtc'],
        'count': a['after'] is Map ? a['after']['count'] : null,
        'from': a['after'] is Map ? a['after']['from'] : null,
        'through': a['after'] is Map ? a['after']['through'] : null,
        'undone': undone.containsKey(a['operationId']),
        'undoAtUtc': undone[a['operationId']]?['atUtc'],
        'undoReason': undone[a['operationId']]?['reason'],
      }),
    ];
  }

  static Json _map(Object? value) {
    if (value is! Map) LocalLedger.fail('The original batch history is incomplete. Undo is unavailable.');
    return Map<String, dynamic>.from(value);
  }

  /// Returns detached review values. Record order follows the original batch;
  /// no timestamp sorting, financial writes, rule execution or partial undo.
  static Json preview(Json data, String sourceOperation) {
    LocalLedger.text(sourceOperation, 'Batch identifier', 100);
    final audit = _audit(data);
    final summaries = audit.where((a) => a['action'] == 'categorize' && a['operationId'] == sourceOperation).toList();
    if (summaries.length != 1 || data['operations'] is! Map ||
        !(data['operations'] as Map).containsKey(sourceOperation)) {
      LocalLedger.fail('The original categorization batch was not found or is incomplete.');
    }
    final summary = summaries.single;
    final info = _map(summary['after']);
    LocalLedger.date(info['from']); LocalLedger.date(info['through']);
    if ((info['from'] as String).compareTo(info['through'] as String) > 0 ||
        info['transactionIds'] is! List || info['count'] is! int ||
        info['count'] < 1 || info['count'] > CategoryRules.maxBatch ||
        info['count'] != (info['transactionIds'] as List).length ||
        DateTime.tryParse(summary['atUtc']?.toString() ?? '') == null) {
      LocalLedger.fail('The original batch history is incomplete. Undo is unavailable.');
    }
    final ids = (info['transactionIds'] as List)
        .map((id) => LocalLedger.text(id, 'Transaction identifier', 100)).toList();
    final changes = audit.where((a) => a['action'] == 'categorize-transaction' &&
        a['operationId'] == sourceOperation).toList();
    if (ids.toSet().length != ids.length || changes.length != ids.length ||
        !_equal(changes.map((a) => a['objectId']).toList(), ids)) {
      LocalLedger.fail('The original batch history is incomplete. Undo is unavailable.');
    }
    final accounts = LocalLedger.rows(data['accounts']);
    final categories = LocalLedger.rows(data['categories']);
    final names = {for (final r in [...accounts, ...categories]) r['id']: r['name']};
    final transactions = {for (final t in LocalLedger.rows(data['transactions'])) t['id']: t};
    final reversals = audit.where((a) => a['action'] == 'category-undo' &&
        a['after'] is Map && a['after']['sourceOperationId'] == sourceOperation).toList();
    final rows = <Json>[];
    for (final change in changes) {
      final before = _map(change['before']), after = _map(change['after']);
      final id = change['objectId'];
      if (before['id'] != id || after['id'] != id || before['version'] is! int ||
          before['version'] < 1 || after['version'] != before['version'] + 1 ||
          before['voided'] != false || after['voided'] != false ||
          !['expense', 'income'].contains(before['kind']) ||
          before['splits'] is! List || (before['splits'] as List).isNotEmpty ||
          before['counterpartyAccountId'] == after['counterpartyAccountId'] ||
          change['ruleId'] is! String || change['ruleVersion'] is! int || change['ruleVersion'] < 1) {
        LocalLedger.fail('The saved change is not a reversible category-only edit.');
      }
      final sameFields = LocalLedger.clone(before)..remove('version')..remove('counterpartyAccountId')..remove('postings');
      final otherFields = LocalLedger.clone(after)..remove('version')..remove('counterpartyAccountId')..remove('postings');
      if (!_equal(sameFields, otherFields) ||
          !_equal(before['postings'], LocalLedger.postingsFor(before, accounts, categories)) ||
          !_equal(after['postings'], LocalLedger.postingsFor(after, accounts, categories))) {
        LocalLedger.fail('The saved change is not a reversible category-only edit.');
      }
      LocalLedger.date(before['effectiveDate']);
      LocalLedger.text(before['payee'], 'Payee', 150, optional: true);
      final current = transactions[id];
      String? blocked;
      if (current == null) {
        blocked = 'Transaction no longer exists.';
      } else if (current['voided'] == true) {
        blocked = 'Transaction was voided after this batch.';
      } else if (Reconciliation.locked(data, id as String)) {
        blocked = 'Transaction is reconciled. Reopen its statement before making corrections.';
      } else if (!_equal(current, after)) {
        blocked = 'Transaction changed after this batch. Later edits will not be overwritten.';
      }
      final ruleRecord = audit.where((a) => a['action'] == 'category-rule' &&
        a['after'] is Map && a['after']['id'] == change['ruleId'] &&
        a['after']['version'] == change['ruleVersion']).firstOrNull;
      rows.add({'transactionId': id, 'date': before['effectiveDate'], 'payee': before['payee'],
        'amountMinor': before['amountMinor'], 'kind': before['kind'],
        'accountName': names[before['accountId']] ?? 'Unavailable account',
        'originalCategoryId': before['counterpartyAccountId'],
        'originalCategoryName': names[before['counterpartyAccountId']] ?? 'Unavailable category',
        'appliedCategoryId': after['counterpartyAccountId'],
        'appliedCategoryName': names[after['counterpartyAccountId']] ?? 'Unavailable category',
        'currentCategoryName': current == null ? 'Unavailable transaction' :
          (names[current['counterpartyAccountId']] ?? 'Split or unavailable category'),
        'ruleName': ruleRecord == null ? 'Rule ${change['ruleId']}' : ruleRecord['after']['name'],
        'ruleVersion': change['ruleVersion'], 'blockedReason': blocked,
      });
    }
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(LocalLedger._canonical({
      'sourceOperationId': sourceOperation, 'revision': data['revision'],
      'summary': summary, 'changes': changes, 'current': [for (final id in ids) transactions[id]],
    })))).toString();
    return LocalLedger.clone({'sourceOperationId': sourceOperation, 'atUtc': summary['atUtc'],
      'from': info['from'], 'through': info['through'], 'count': ids.length,
      'expectedRevision': data['revision'], 'fingerprint': fingerprint, 'changes': rows,
      'undone': reversals.isNotEmpty,
      'undoAtUtc': reversals.isEmpty ? null : reversals.first['atUtc'],
      'undoReason': reversals.isEmpty ? null : reversals.first['after']['reason'],
      'canUndo': reversals.isEmpty && rows.every((r) => r['blockedReason'] == null),
    });
  }

  static Json undo(Json next, Json input, String operation, List<Json> accounts,
      List<Json> categories, List<Json> transactions) {
    if (input['expectedRevision'] != next['revision']) {
      LocalLedger.fail('Workspace changed. Refresh history and review the batch again.');
    }
    if (input['confirmReviewed'] != true) LocalLedger.fail('Review and confirm the complete batch before undoing it.');
    final reason = LocalLedger.text(input['reason'], 'Undo reason', 250);
    final source = LocalLedger.text(input['sourceOperationId'], 'Batch identifier', 100);
    final review = preview(next, source);
    if (review['undone'] == true) LocalLedger.fail('This categorization batch has already been undone.');
    if (review['canUndo'] != true) {
      LocalLedger.fail('The entire batch is blocked because a transaction changed or is protected. No categories were restored.');
    }
    if (input['previewFingerprint'] != review['fingerprint']) {
      LocalLedger.fail('The undo preview is stale. Refresh history and review the batch again.');
    }
    final events = <Json>[];
    final ids = <String>[];
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in LocalLedger.rows(review['changes'])) {
      final id = row['transactionId'] as String;
      final index = transactions.indexWhere((t) => t['id'] == id);
      final before = transactions[index];
      final after = {...before, 'counterpartyAccountId': row['originalCategoryId'],
        'version': (before['version'] as int) + 1};
      after['postings'] = LocalLedger.postingsFor(after, accounts, categories);
      transactions[index] = after; ids.add(id);
      events.add({'operationId': operation, 'action': 'undo-categorization-transaction',
        'sourceOperationId': source, 'objectId': id, 'atUtc': now,
        'before': LocalLedger.clone(before), 'after': LocalLedger.clone(after)});
    }
    next['audit'] = [...LocalLedger.rows(next['audit']), ...events];
    return {'sourceOperationId': source, 'reason': reason, 'transactionIds': ids, 'count': ids.length};
  }
}
