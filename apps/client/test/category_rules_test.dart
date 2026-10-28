import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'csv_import_test.dart' show importBatch, createRow;
import 'schedule_matching_test.dart' show matchingFixture, matchRequest;
import 'reconciliation_test.dart' show statementRequest, reopenRequest;

LocalLedger rulesFixture() {
  final l = LocalLedger.empty().apply('account', account('account', 'Fictional rules account', 100000));
  return l.apply('transaction', {...tx('expense', 'expense', accounts(l).first['id'], category(l, 'Expense'), 2500),
    'payee': 'Fictional Corner Shop'});
}
String ruleTarget(LocalLedger l, [String kind = 'Expense']) => LocalLedger.rows(l.data['categories'])
    .where((c) => c['kind'] == kind).last['id'] as String;
Json ruleRequest(LocalLedger l, {String operation = 'rule', String pattern = 'corner', int priority = 10,
    String kind = 'expense', String source = 'all'}) => {
  'operationId': operation, 'expectedRevision': l.revision, 'name': 'Fictional rule $priority',
  'pattern': pattern, 'priority': priority, 'kind': kind, 'mode': 'contains', 'source': source,
  'enabled': true, 'accountId': null, 'fromCategoryId': null, 'minimumMinor': null, 'maximumMinor': null,
  'categoryId': ruleTarget(l, kind == 'expense' ? 'Expense' : 'Income'), 'confirmRuleUpgrade': true,
};
Json categorizeRequest(LocalLedger l, {String operation = 'categorize'}) => {
  'operationId': operation, 'expectedRevision': l.revision, 'from': '2026-01-01', 'through': '2026-12-31',
  'confirmReviewed': true, 'selections': CategoryRules.preview(l.data, from: '2026-01-01', through: '2026-12-31'),
};

void main() {
  test('saving is explicit and never categorizes; preview is read-only; applying preserves money and identity', () {
    final original = rulesFixture(); final request = ruleRequest(original);
    expect(() => original.apply('category-rule', {...request, 'confirmRuleUpgrade': false}), throwsFormatException);
    final l = original.apply('category-rule', request);
    expect(l.data['schema'], 6); expect(l.data['transactions'], original.data['transactions']);
    expect(l.apply('category-rule', request).data, l.data);
    final before = jsonEncode(l.data);
    final command = categorizeRequest(l);
    expect(command['selections'].length, 1); expect(jsonEncode(l.data), before);
    final after = l.apply('categorize', command);
    final t = LocalLedger.rows(l.data['transactions']).single;
    final updated = LocalLedger.rows(after.data['transactions']).single;
    for (final key in t.keys.where((k) => !['version', 'counterpartyAccountId', 'postings'].contains(k))) {
      expect(updated[key], t[key], reason: key);
    }
    expect(updated['counterpartyAccountId'], ruleTarget(l)); expect(updated['version'], t['version'] + 1);
    expect(accounts(after), accounts(l)); expect(after.data['transactions'].length, 1);
    expect(BudgetEngine.calculate(after.snapshot(), '2026-10').spent, 2500);
    expect(BudgetEngine.calculate(after.snapshot(), '2026-10').categories.firstWhere((c) => c.id == ruleTarget(l)).spent, 2500);
    expect(BudgetEngine.calculate(after.snapshot(), '2026-10').categories.firstWhere((c) => c.id == t['counterpartyAccountId']).spent, 0);
    expect(after.apply('categorize', command).data, after.data);
    expect(CategoryRules.preview(after.snapshot(), from: '2026-01-01', through: '2026-12-31'), isEmpty);
    expect(LocalLedger.rows(after.data['audit']).where((a) => a['action'] == 'categorize-transaction').single['before'], t);
  });

  test('first enabled matching rule wins even for a no-op; priorities and names are unique', () {
    var l = rulesFixture(); final old = LocalLedger.rows(l.data['transactions']).single['counterpartyAccountId'];
    l = l.apply('category-rule', {...ruleRequest(l, priority: 1), 'categoryId': old});
    l = l.apply('category-rule', ruleRequest(l, operation: 'second', priority: 2));
    expect(categorizeRequest(l)['selections'], isEmpty);
    final first = CategoryRules.ordered(l.data).first;
    l = l.apply('category-rule', {...first, 'operationId': 'disable', 'expectedRevision': l.revision,
      'expectedVersion': first['version'], 'enabled': false});
    expect(categorizeRequest(l)['selections'].length, 1);
    expect(() => l.apply('category-rule', ruleRequest(l, operation: 'duplicate', priority: 2)), throwsFormatException);
    expect(() => l.apply('category-rule', {...ruleRequest(l, operation: 'name', priority: 3), 'name': first['name']}), throwsFormatException);
    final unchanged = jsonEncode(l.data); CategoryRules.ordered(l.data).first['name'] = 'changed copy';
    expect(jsonEncode(l.data), unchanged);
  });

  test('text, source, account, current category and inclusive amount/date conditions are explicit', () {
    var l = rulesFixture(); final t = LocalLedger.rows(l.data['transactions']).single;
    final input = {...ruleRequest(l, pattern: ' FICTIONAL CORNER SHOP ', source: 'manual'), 'mode': 'exact',
      'accountId': t['accountId'], 'fromCategoryId': t['counterpartyAccountId'],
      'minimumMinor': 2500, 'maximumMinor': 2500};
    l = l.apply('category-rule', input);
    expect(CategoryRules.preview(l.snapshot(), from: '2026-10-27', through: '2026-10-27').length, 1);
    expect(CategoryRules.preview(l.snapshot(), from: '2026-10-28', through: '2026-10-28'), isEmpty);
    expect(() => CategoryRules.preview(l.snapshot(), from: '2026-11-01', through: '2026-10-01'), throwsFormatException);
    expect(() => CategoryRules.preview(l.snapshot(), from: '2026-02-30', through: '2026-10-01'), throwsFormatException);
    final r = CategoryRules.ordered(l.data).single;
    expect(CategoryRules.matches({...r, 'minimumMinor': 2501}, t, false), isFalse);
    expect(CategoryRules.matches({...r, 'maximumMinor': 2499}, t, false), isFalse);
    expect(CategoryRules.matches({...r, 'accountId': 'another'}, t, false), isFalse);
    expect(CategoryRules.matches({...r, 'source': 'statement'}, t, false), isFalse);
    expect(CategoryRules.matches({...r, 'mode': 'prefix', 'pattern': 'FICTIONAL'}, t, false), isTrue);
    expect(CategoryRules.matches({...r, 'mode': 'exact', 'pattern': 'corner'}, t, false), isFalse);
    l = l.apply('import-csv', importBatch(l, [{...createRow(l, signed: -2500), 'action': 'match', 'transactionId': t['id']}], operation: 'receipt'));
    expect(categorizeRequest(l)['selections'], isEmpty);
    l = l.apply('category-rule', {...r, 'operationId': 'statement-source', 'expectedVersion': r['version'],
      'expectedRevision': l.revision, 'source': 'statement'});
    expect(categorizeRequest(l)['selections'].length, 1);
  });

  test('split, transfer, voided and reconciled transactions cannot be recategorized', () {
    var l = rulesFixture(); final a = accounts(l).first['id'] as String;
    l = l.apply('account', account('other', 'Fictional second account', 0));
    l = l.apply('transaction', {...tx('transfer', 'transfer', a, accounts(l).last['id'], 100), 'payee': 'Corner'});
    l = l.apply('transaction', {...tx('split', 'expense', a, category(l, 'Expense'), 100), 'payee': 'Corner',
      'splits': [{'categoryId': category(l, 'Expense'), 'amountMinor': 100}]});
    l = l.apply('transaction', {...tx('voided', 'expense', a, category(l, 'Expense'), 100), 'payee': 'Corner'});
    final voided = LocalLedger.rows(l.data['transactions']).last;
    l = l.apply('void', {'operationId': 'void', 'id': voided['id'], 'expectedVersion': 1});
    l = l.apply('category-rule', ruleRequest(l));
    final preview = categorizeRequest(l)['selections'] as List;
    expect(preview.length, 1);
    final primary = LocalLedger.rows(l.data['transactions']).first;
    l = l.apply('reconcile', statementRequest(l, selected: [primary['id']], closing: 97500));
    expect(categorizeRequest(l)['selections'], isEmpty);
    expect(() => l.apply('categorize', {...categorizeRequest(l), 'selections': preview}), throwsFormatException);
    final statement = Reconciliation.active(l.data, a).single;
    l = l.apply('reconcile-reopen', reopenRequest(l, statement));
    expect(categorizeRequest(l)['selections'].length, 1);
  });

  test('stale, duplicated or tampered selections fail without changing the original', () {
    var l = rulesFixture(); l = l.apply('category-rule', ruleRequest(l));
    final command = categorizeRequest(l), before = jsonEncode(l.data);
    final choice = LocalLedger.rows(command['selections']).single;
    for (final patch in <Json>[
      {'expectedRevision': -1}, {'confirmReviewed': false}, {'selections': []},
      {'selections': [choice, choice]},
      {'selections': [choice, {...choice, 'transactionId': 'missing'}]},
      for (final key in ['expectedVersion', 'expectedRuleVersion', 'ruleId', 'categoryId', 'fromCategoryId'])
        {'selections': [{...choice, key: 'invalid'}]},
      {'through': '2026-10-26'},
    ]) { expect(() => l.apply('categorize', {...command, ...patch}), throwsFormatException); expect(jsonEncode(l.data), before); }
    final rule = CategoryRules.ordered(l.data).single;
    final changed = l.apply('category-rule', {...rule, 'operationId': 'edit-rule', 'expectedRevision': l.revision,
      'expectedVersion': rule['version'], 'pattern': 'no match'});
    expect(() => changed.apply('categorize', command), throwsFormatException);
    expect(() => changed.apply('categorize', {...command, 'expectedRevision': changed.revision}), throwsFormatException);
    final result = l.apply('categorize', command);
    expect(() => result.apply('categorize', {...command, 'through': '2026-11-30'}), throwsFormatException);
  });

  test('old schemas migrate only on rule save and preserve all existing collections', () {
    for (final schema in [1, 2, 3, 4, 5]) {
      final data = LocalLedger.clone(rulesFixture().data)..['schema'] = schema;
      if (schema == 1) data.remove('budgets');
      if (schema < 3) { data.remove('schedules'); data.remove('occurrences'); }
      if (schema >= 4) data['imports'] = <Json>[];
      if (schema >= 5) data['reconciliations'] = <Json>[];
      var l = LocalLedger(data); final before = LocalLedger.clone(l.data);
      CategoryRules.preview(l.snapshot(), from: '2026-01-01', through: '2026-12-31');
      expect(l.data, before);
      l = l.apply('category-rule', ruleRequest(l)); expect(l.data['schema'], 6);
      for (final key in ['accounts', 'transactions', 'categories', 'budgets', 'schedules', 'occurrences', 'imports', 'reconciliations']) {
        if (before.containsKey(key)) expect(l.data[key], before[key], reason: key);
      }
      final rules = LocalLedger.clone(l.data)['categoryRules'];
      l = l.apply('import-csv', importBatch(l, [createRow(l)], operation: 'later-import'));
      expect(l.data['categoryRules'], rules); expect(l.data['schema'], 6);
    }
  });

  test('existing import receipts and matched schedule links survive category changes', () {
    var l = matchingFixture(imported: true); l = l.apply('schedule-match', matchRequest(l, 'match'));
    final before = LocalLedger.clone(l.data);
    l = l.apply('category-rule', ruleRequest(l, pattern: 'fictional', source: 'statement'));
    l = l.apply('categorize', categorizeRequest(l));
    for (final key in ['imports', 'schedules', 'occurrences']) { expect(l.data[key], before[key]); }
    expect(LocalLedger.rows(l.data['transactions']).single['scheduleId'], before['transactions'][0]['scheduleId']);
    expect(accounts(l).first['balanceMinor'], 98000);
    expect(() => l.apply('import-csv', importBatch(l, [createRow(l)], operation: 'repeat')), throwsFormatException);
    l = l.apply('reconcile', statementRequest(l, closing: 98000));
    expect(l.data['schema'], 6); expect(l.data['categoryRules'].length, 1);
  });

  test('invalid rule definitions and corrupt restored rules are refused', () {
    final l = rulesFixture();
    for (final patch in <Json>[{'pattern': ' '}, {'kind': 'transfer'}, {'enabled': 'yes'}, {'priority': 0},
      {'mode': 'regex'}, {'source': 'network'}, {'minimumMinor': 0}, {'minimumMinor': 30, 'maximumMinor': 29},
      {'maximumMinor': 1.5}, {'accountId': 'missing'}, {'categoryId': category(l, 'Income')}, {'fromCategoryId': 'missing'}]) {
      expect(() => l.apply('category-rule', {...ruleRequest(l), ...patch}), throwsFormatException);
    }
    final saved = l.apply('category-rule', ruleRequest(l));
    for (final corruption in ['missing', 'priority', 'operation', 'version', 'category', 'duplicate']) {
      final data = LocalLedger.clone(saved.data);
      switch (corruption) {
        case 'missing': data.remove('categoryRules'); break;
        case 'priority': data['categoryRules'][0]['priority'] = 'first'; break;
        case 'operation': data['categoryRules'][0]['operationId'] = 'missing'; break;
        case 'version': data['categoryRules'][0]['version'] = 0; break;
        case 'category': data['categoryRules'][0]['categoryId'] = 'missing'; break;
        case 'duplicate': data['categoryRules'].add(LocalLedger.clone(data['categoryRules'][0])); break;
      }
      expect(() => LocalLedger(data), throwsFormatException, reason: corruption);
    }
    expect(() => LocalLedger({...saved.data, 'schema': 5}), throwsFormatException);
  });

  test('income rules use income categories; selection is bounded and exact', () {
    var l = LocalLedger.empty().apply('account', account('account', 'Fictional income', 0));
    l = l.apply('transaction', tx('income', 'income', accounts(l).first['id'], category(l, 'Income'), 10));
    l = l.apply('category-rule', ruleRequest(l, kind: 'income', pattern: 'test'));
    final data = LocalLedger.clone(l.data), seed = LocalLedger.rows(l.data['transactions']).single;
    data['transactions'] = [for (var i = 0; i < 501; i++) {...seed, 'id': 'fictional-$i'}];
    l = LocalLedger(data); final request = categorizeRequest(l);
    expect(() => l.apply('categorize', request), throwsFormatException);
    final before = accounts(l);
    l = l.apply('categorize', {...request, 'selections': LocalLedger.rows(request['selections']).take(500).toList()});
    expect(accounts(l), before); expect(l.data['transactions'].length, 501);
    expect(categorizeRequest(l)['selections'].length, 1);
  });
}
