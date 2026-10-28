import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'category_rules_test.dart' show rulesFixture, ruleRequest, categorizeRequest, ruleTarget;
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'schedule_matching_test.dart' show matchingFixture, matchRequest;
import 'csv_import_test.dart' show importBatch, createRow;
import 'reconciliation_test.dart' show statementRequest, reopenRequest;

LocalLedger appliedFixture() {
  var l = rulesFixture(); l = l.apply('category-rule', ruleRequest(l));
  return l.apply('categorize', categorizeRequest(l));
}
Json undoRequest(LocalLedger l, {String source = 'categorize', String operation = 'undo'}) => {
  'operationId': operation, 'sourceOperationId': source, 'expectedRevision': l.revision,
  'previewFingerprint': CategoryHistory.preview(l.data, source)['fingerprint'],
  'reason': 'Correct a fictional categorization test', 'confirmReviewed': true,
};

void main() {
  test('prior batch history and preview are detached read-only views with original rule version', () {
    final l = appliedFixture();
    final before = jsonEncode(l.data), list = CategoryHistory.batches(l.data);
    expect(list.single['count'], 1); expect(list.single['undone'], false);
    final review = CategoryHistory.preview(l.data, 'categorize');
    expect(review['canUndo'], true); expect(review['changes'][0]['ruleName'], 'Fictional rule 10');
    expect(review['changes'][0]['ruleVersion'], 1);
    list.first['count'] = 30; review['changes'][0]['originalCategoryId'] = 'tampered-copy';
    expect(jsonEncode(l.data), before);
  });

  test('undo restores only category, preserves all money/identities/collections and appends history', () {
    final before = appliedFixture(); final request = undoRequest(before);
    final t = LocalLedger.rows(before.data['transactions']).single;
    final changed = before.apply('category-undo', request);
    final after = LocalLedger.rows(changed.data['transactions']).single;
    for (final key in t.keys.where((key) => !['version', 'counterpartyAccountId', 'postings'].contains(key))) {
      expect(after[key], t[key], reason: key);
    }
    expect(after['version'], t['version'] + 1); expect(after['counterpartyAccountId'], category(before, 'Expense'));
    for (final key in ['schema', 'accounts', 'categories', 'budgets', 'schedules', 'occurrences', 'imports', 'reconciliations', 'categoryRules']) {
      expect(changed.data[key], before.data[key], reason: key);
    }
    expect(accounts(changed), accounts(before)); expect(changed.data['transactions'].length, 1);
    expect(changed.data['audit'].take(before.data['audit'].length).toList(), before.data['audit']);
    expect(BudgetEngine.calculate(changed.snapshot(), '2026-10').spent, 2500);
    expect(BudgetEngine.calculate(changed.snapshot(), '2026-10').categories.firstWhere((c) => c.id == category(before, 'Expense')).spent, 2500);
    expect(CategoryHistory.batches(changed.data).single['undone'], true);
    expect(CategoryHistory.preview(changed.data, 'categorize')['canUndo'], false);
    expect(changed.apply('category-undo', request).data, changed.data);
    expect(() => changed.apply('category-undo', undoRequest(changed, operation: 'again')), throwsFormatException);
    expect(() => changed.apply('category-undo', {...request, 'reason': 'Different reason'}), throwsFormatException);
    expect(LocalLedger.rows(changed.data['audit']).where((a) => a['action'] == 'undo-categorization-transaction').single['before'], t);
  });

  test('undo requires a complete current preview, explicit consent and a bounded reason', () {
    final l = appliedFixture();
    final request = undoRequest(l), before = jsonEncode(l.data);
    for (final patch in <Json>[{'expectedRevision': -1}, {'confirmReviewed': false}, {'reason': ' '},
      {'reason': List.filled(251, 'x').join()}, {'sourceOperationId': 'unknown'},
      {'previewFingerprint': ''}, {'previewFingerprint': List.filled(64, 'a').join()}]) {
      expect(() => l.apply('category-undo', {...request, ...patch}), throwsFormatException);
      expect(jsonEncode(l.data), before);
    }
    final other = l.apply('category', {'operationId': 'unrelated', 'name': 'Fictional category', 'kind': 'Expense'});
    expect(() => other.apply('category-undo', request), throwsFormatException);
    expect(() => other.apply('category-undo', {...request, 'expectedRevision': other.revision}), throwsFormatException);
    expect(other.apply('category-undo', undoRequest(other)).data['schema'], 6);
  });

  test('any later transaction edit, void or reconciliation blocks the whole batch without partial undo', () {
    var seed = rulesFixture();
    seed = seed.apply('transaction', {...tx('second-expense', 'expense', accounts(seed).first['id'], category(seed, 'Expense'), 1200), 'payee': 'Fictional Corner Shop'});
    seed = seed.apply('category-rule', ruleRequest(seed)); seed = seed.apply('categorize', categorizeRequest(seed));
    final last = LocalLedger.rows(seed.data['transactions']).last;
    final variants = [
      seed.apply('transaction', {...last, 'operationId': 'edit', 'expectedVersion': last['version'], 'notes': 'Later note'}),
      seed.apply('void', {'operationId': 'void', 'id': last['id'], 'expectedVersion': last['version']}),
      seed.apply('reconcile', statementRequest(seed, selected: [last['id']], closing: 98800)),
    ];
    for (final l in variants) {
      final before = jsonEncode(l.data), review = CategoryHistory.preview(l.data, 'categorize');
      expect(review['changes'].length, 2); expect(review['canUndo'], false);
      expect(LocalLedger.rows(review['changes']).singleWhere((r) => r['transactionId'] == last['id'])['blockedReason'], isNotNull);
      expect(() => l.apply('category-undo', undoRequest(l)), throwsFormatException);
      expect(jsonEncode(l.data), before);
    }
    var reconciled = variants.last;
    reconciled = reconciled.apply('reconcile-reopen', reopenRequest(reconciled,
      Reconciliation.active(reconciled.data, accounts(reconciled).first['id']).single));
    expect(CategoryHistory.preview(reconciled.data, 'categorize')['canUndo'], true);
    expect(reconciled.apply('category-undo', undoRequest(reconciled)).data['transactions'].length, 2);
  });

  test('rule changes do not change original review labels or prevent undo of unchanged transactions', () {
    var l = appliedFixture(); final rule = CategoryRules.ordered(l.data).single;
    l = l.apply('category-rule', {...rule, 'expectedRevision': l.revision, 'expectedVersion': rule['version'],
      'operationId': 'edit-rule', 'name': 'Renamed current rule', 'enabled': false});
    final preview = CategoryHistory.preview(l.data, 'categorize');
    expect(preview['changes'][0]['ruleName'], 'Fictional rule 10'); expect(preview['canUndo'], true);
    final changed = l.apply('category-undo', undoRequest(l));
    expect(changed.data['categoryRules'], l.data['categoryRules']);
  });

  test('undo never reruns rules and later reapplication is a separate explicit batch', () {
    var l = appliedFixture(); l = l.apply('category-undo', undoRequest(l));
    expect(CategoryRules.preview(l.data, from: '2026-01-01', through: '2026-12-31').length, 1);
    l = l.apply('categorize', categorizeRequest(l, operation: 'reapply'));
    expect(CategoryHistory.batches(l.data).length, 2);
    expect(CategoryHistory.batches(l.data).first['operationId'], 'reapply');
    expect(CategoryHistory.preview(l.data, 'categorize')['undone'], true);
    expect(l.apply('category-undo', undoRequest(l, source: 'reapply', operation: 'undo-reapply')).data['transactions'].length, 1);
  });

  test('disjoint older batches can undo, but newer versions never cascade back into older batches', () {
    var l = appliedFixture();
    l = l.apply('transaction', {...tx('new-expense', 'expense', accounts(l).first['id'], category(l, 'Expense'), 10), 'payee': 'Corner'});
    l = l.apply('categorize', categorizeRequest(l, operation: 'second'));
    expect(CategoryHistory.preview(l.data, 'categorize')['canUndo'], true);
    l = l.apply('category-undo', undoRequest(l));
    expect(CategoryHistory.preview(l.data, 'second')['canUndo'], true);
    var shared = appliedFixture(); final rule = CategoryRules.ordered(shared.data).single;
    shared = shared.apply('category-rule', {...rule, 'operationId': 'reverse-rule', 'expectedRevision': shared.revision,
      'expectedVersion': rule['version'], 'categoryId': category(shared, 'Expense')});
    shared = shared.apply('categorize', categorizeRequest(shared, operation: 'newer'));
    expect(CategoryHistory.preview(shared.data, 'categorize')['canUndo'], false);
    shared = shared.apply('category-undo', undoRequest(shared, source: 'newer'));
    expect(CategoryHistory.preview(shared.data, 'categorize')['canUndo'], false);
  });

  test('import identity and reciprocal scheduled links survive categorization then undo', () {
    var l = matchingFixture(imported: true); l = l.apply('schedule-match', matchRequest(l, 'match'));
    final original = LocalLedger.clone(l.data);
    l = l.apply('category-rule', ruleRequest(l, pattern: 'fictional', source: 'statement'));
    l = l.apply('categorize', categorizeRequest(l)); l = l.apply('category-undo', undoRequest(l));
    for (final key in ['imports', 'schedules', 'occurrences']) { expect(l.data[key], original[key]); }
    expect(accounts(l).first['balanceMinor'], 98000);
    expect(l.data['transactions'][0]['counterpartyAccountId'], original['transactions'][0]['counterpartyAccountId']);
    expect(() => l.apply('import-csv', importBatch(l, [createRow(l)], operation: 'repeat')), throwsFormatException);
  });

  test('incomplete, duplicated or non-category audit records cannot authorize undo', () {
    final seed = appliedFixture();
    for (final kind in ['missing-summary', 'duplicate-summary', 'missing-change', 'duplicate-change',
      'amount', 'postings', 'version', 'type', 'split', 'ids', 'count', 'operation', 'empty-audit', 'bad-row']) {
      final data = LocalLedger.clone(seed.data), audit = LocalLedger.rows(data['audit']);
      final summary = audit.firstWhere((a) => a['action'] == 'categorize');
      final detail = audit.firstWhere((a) => a['action'] == 'categorize-transaction');
      switch (kind) {
        case 'missing-summary': audit.remove(summary); break;
        case 'duplicate-summary': audit.add(LocalLedger.clone(summary)); break;
        case 'missing-change': audit.remove(detail); break;
        case 'duplicate-change': audit.add(LocalLedger.clone(detail)); break;
        case 'amount': detail['before']['amountMinor'] = 1; break;
        case 'postings': detail['before']['postings'][0]['amountMinor'] = 1; break;
        case 'version': detail['after']['version']++; break;
        case 'type': detail['before']['kind'] = 'transfer'; break;
        case 'split': detail['before']['splits'] = [{'categoryId': category(seed, 'Expense'), 'amountMinor': 2500}]; break;
        case 'ids': summary['after']['transactionIds'] = ['missing']; break;
        case 'count': summary['after']['count'] = 2; break;
        case 'operation': data['operations'].remove('categorize'); break;
        case 'empty-audit': audit.clear(); break;
        case 'bad-row': break;
      }
      data['audit'] = kind == 'bad-row' ? [false] : audit;
      expect(() => CategoryHistory.preview(data, 'categorize'), throwsFormatException, reason: kind);
    }
  });

  test('all legacy schemas show empty history without migration and no account mutations', () {
    for (final schema in [1, 2, 3, 4, 5]) {
      final data = LocalLedger.clone(LocalLedger.empty().data)..['schema'] = schema;
      if (schema == 1) data.remove('budgets');
      if (schema < 3) { data.remove('schedules'); data.remove('occurrences'); }
      if (schema >= 4) data['imports'] = <Json>[];
      if (schema >= 5) data['reconciliations'] = <Json>[];
      final l = LocalLedger(data), before = jsonEncode(data);
      expect(CategoryHistory.batches(l.data), isEmpty); expect(jsonEncode(l.data), before);
    }
  });

  test('income undo remains exact and rule category target is not used to restore history', () {
    var l = LocalLedger.empty().apply('account', account('income-account', 'Fictional income', 0));
    l = l.apply('transaction', tx('income', 'income', accounts(l).first['id'], category(l, 'Income'), LocalLedger.maxMinor));
    l = l.apply('category-rule', ruleRequest(l, kind: 'income', pattern: 'test'));
    l = l.apply('categorize', categorizeRequest(l)); expect(l.data['transactions'][0]['counterpartyAccountId'], ruleTarget(l, 'Income'));
    l = l.apply('category-undo', undoRequest(l));
    expect(accounts(l).single['balanceMinor'], LocalLedger.maxMinor);
    expect(l.data['transactions'][0]['counterpartyAccountId'], category(l, 'Income'));
  });
}
