import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/csv_rule_suggestions.dart';
import 'package:budgetism/local/budgets.dart';
import 'local_ledger_test.dart' show account, accounts;
import 'category_rules_test.dart' show ruleRequest;
import 'import_profiles_test.dart' show profileRequest;
import 'reconciliation_test.dart' show statementRequest;

String namedCategory(LocalLedger l, String name) => LocalLedger.rows(l.data['categories'])
    .firstWhere((c) => c['name'] == name)['id'] as String;
LocalLedger csvRulesFixture() {
  var l = LocalLedger.empty().apply('account', account('account', 'Fictional rule import account', 100000));
  l = l.apply('category-rule', {...ruleRequest(l), 'name': 'Fictional store rule', 'pattern': 'Rule test',
    'fromCategoryId': namedCategory(l, 'Other spending'), 'categoryId': namedCategory(l, 'Groceries')});
  return l.apply('import-profile', profileRequest(l));
}
Future<void> seedCsvRules(LocalVault v) async {
  await v.apply('account', account('account', 'Fictional rule import account', 100000));
  await v.apply('category-rule', {...ruleRequest(v.ledger), 'name': 'Fictional store rule', 'pattern': 'Rule test',
    'fromCategoryId': namedCategory(v.ledger, 'Other spending'), 'categoryId': namedCategory(v.ledger, 'Groceries')});
  await v.apply('import-profile', profileRequest(v.ledger));
}
CsvTable ruleTable([String? text]) => CsvTable.parse(text ??
  'Date,Description,Amount,Reference\n2026-10-28,Rule test store,-12.34,rule-1\n'
  '2026-10-28,Other shop,-20.00,other-1\n2026-10-28,Fictional income,500.00,income-1');
List<CsvEntry> ruleEntries(CsvTable table) => CsvImport.preview(table,
    const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2, referenceColumn: 3));
Map<int, Json> ruleChoices(LocalLedger l, List<CsvEntry> entries) => {
  for (final e in entries.where((e) => e.values != null)) e.rowNumber: {
    'action': 'create', 'kind': e.values!['signedMinor'] < 0 ? 'expense' : 'income',
    'targetId': namedCategory(l, e.values!['signedMinor'] < 0 ? 'Other spending' : 'Other income'),
    'allowDuplicate': false,
  },
};
CsvRuleReview ruleReview(LocalLedger l, CsvTable table, Map<int, Json> choices, {Set<int> protected = const {}}) =>
    CsvRuleSuggestions.preview(snapshot: l.snapshot(), accountId: accounts(l).first['id'], fileHash: table.digest,
      entries: ruleEntries(table), choices: choices, reviewedRows: protected);
Map<int, Json> acceptRules(LocalLedger l, CsvTable table, Map<int, Json> choices, CsvRuleReview review,
    {List<int> selected = const [2], bool confirmed = true, Set<int> protected = const {}}) =>
    CsvRuleSuggestions.accept(review: review, snapshot: l.snapshot(), accountId: accounts(l).first['id'],
      fileHash: table.digest, entries: ruleEntries(table), choices: choices, selectedRows: selected,
      confirmed: confirmed, reviewedRows: protected);
Json suggestedImport(LocalLedger l, CsvTable table, Map<int, Json> choices, {String operation = 'import'}) => {
  'operationId': operation, 'expectedRevision': l.revision, 'fileHash': table.digest,
  'fileName': 'fictional-rule-import.csv', 'accountId': accounts(l).first['id'], 'confirmImportUpgrade': true,
  'rows': [for (final e in ruleEntries(table)) if (e.values != null && choices[e.rowNumber]?['action'] != 'skip')
    {...e.values!, ...choices[e.rowNumber]!}],
};

void main() {
  test('preview and selective acceptance change only detached category choices, with no migration or ledger write', () {
    final l = csvRulesFixture(), table = ruleTable();
    final original = jsonEncode(l.data), choices = ruleChoices(l, ruleEntries(table));
    final choicesBefore = jsonEncode(choices.map((k, v) => MapEntry('$k', v)));
    final review = ruleReview(l, table, choices), proposal = ruleReview(l, table, choices).suggestions.single;
    expect(proposal.rowNumber, 2); expect(proposal.signedMinor, -1234);
    expect(proposal.currentCategory, 'Other spending'); expect(proposal.categoryName, 'Groceries');
    expect(proposal.ruleName, 'Fictional store rule'); expect(proposal.ruleVersion, 1);
    final changes = acceptRules(l, table, choices, review);
    expect(changes.keys, [2]); expect(changes[2]!['targetId'], namedCategory(l, 'Groceries'));
    for (final key in choices[2]!.keys.where((k) => k != 'targetId')) { expect(changes[2]![key], choices[2]![key]); }
    changes[2]!['kind'] = 'changed detached result';
    expect(jsonEncode(choices.map((k, v) => MapEntry('$k', v))), choicesBefore);
    expect(jsonEncode(l.data), original); expect(l.data['schema'], 7);
    expect(() => review.suggestions.clear(), throwsUnsupportedError);
  });

  test('priority first-match no-op, disabled and manual-only rules retain established semantics', () {
    var l = csvRulesFixture(); final table = ruleTable(), choices = ruleChoices(l, ruleEntries(ruleTable()));
    l = l.apply('category-rule', {...ruleRequest(l, priority: 1, operation: 'first'),
      'pattern': 'rule test', 'categoryId': namedCategory(l, 'Other spending')});
    expect(ruleReview(l, table, choices).suggestions, isEmpty);
    final first = CategoryRules.ordered(l.data).first;
    l = l.apply('category-rule', {...first, 'operationId': 'disable', 'expectedRevision': l.revision,
      'expectedVersion': first['version'], 'enabled': false});
    expect(ruleReview(l, table, choices).suggestions.length, 1);
    final active = CategoryRules.ordered(l.data).last;
    l = l.apply('category-rule', {...active, 'operationId': 'manual', 'expectedRevision': l.revision,
      'expectedVersion': active['version'], 'source': 'manual'});
    expect(ruleReview(l, table, choices).suggestions, isEmpty);
    final manual = CategoryRules.ordered(l.data).last;
    l = l.apply('category-rule', {...manual, 'operationId': 'statement', 'expectedRevision': l.revision,
      'expectedVersion': manual['version'], 'source': 'statement'});
    expect(ruleReview(l, table, choices).suggestions.single.categoryName, 'Groceries');
  });

  test('account, payee mode, exact amount bounds and current-category restrictions apply to prospective entries', () {
    final l = csvRulesFixture(), table = ruleTable(); final choices = ruleChoices(l, ruleEntries(table));
    final saved = CategoryRules.ordered(l.data).single;
    for (final patch in <Json>[{'minimumMinor': 1235}, {'maximumMinor': 1233},
      {'pattern': 'RULE TEST', 'mode': 'exact'}, {'fromCategoryId': namedCategory(l, 'Housing')}]) {
      final changed = l.apply('category-rule', {...saved, ...patch, 'operationId': 'conditions',
        'expectedRevision': l.revision, 'expectedVersion': saved['version']});
      expect(ruleReview(changed, table, choices).suggestions, isEmpty);
    }
    final exact = l.apply('category-rule', {...saved, 'pattern': ' RULE TEST STORE ', 'mode': 'exact',
      'minimumMinor': 1234, 'maximumMinor': 1234, 'operationId': 'exact',
      'expectedRevision': l.revision, 'expectedVersion': saved['version']});
    expect(ruleReview(exact, table, choices).suggestions.single.rowNumber, 2);
    var other = l.apply('account', account('other', 'Fictional other account', 0));
    other = other.apply('category-rule', {...saved, 'accountId': accounts(other).last['id'], 'operationId': 'scope',
      'expectedRevision': other.revision, 'expectedVersion': saved['version']});
    expect(ruleReview(other, table, choices).suggestions, isEmpty);
  });

  test('manual choices, accepted rows, transfers, payment hints, matches, skipped and invalid rows are excluded', () {
    final l = csvRulesFixture(), table = ruleTable(), choices = ruleChoices(l, ruleEntries(ruleTable()));
    expect(ruleReview(l, table, choices, protected: {2}).suggestions, isEmpty);
    for (final patch in <Json>[{'action': 'skip'}, {'action': 'match', 'transactionId': 'existing'}, {'kind': 'transfer'}]) {
      expect(ruleReview(l, table, {...choices, 2: {...choices[2]!, ...patch}}).suggestions, isEmpty);
    }
    final hinted = ruleTable('Date,Description,Amount,Reference\n2026-10-28,Rule test payment,-12.34,hint');
    expect(ruleReview(l, hinted, ruleChoices(l, ruleEntries(hinted))).suggestions, isEmpty);
    final invalid = ruleTable('Date,Description,Amount,Reference\n2026-02-30,Rule test store,-12.34,invalid');
    expect(ruleReview(l, invalid, {}).suggestions, isEmpty);
    final changes = acceptRules(l, table, choices, ruleReview(l, table, choices));
    expect(ruleReview(l, table, {...choices, ...changes}, protected: changes.keys.toSet()).suggestions, isEmpty);
  });

  test('stale rules, workspace, file, mapping, choices or protected rows reject acceptance atomically', () {
    final l = csvRulesFixture(), table = ruleTable(), choices = ruleChoices(l, ruleEntries(ruleTable()));
    final review = ruleReview(l, table, choices), original = jsonEncode(l.data);
    expect(() => acceptRules(l, table, choices, review, confirmed: false), throwsFormatException);
    for (final ids in <List<int>>[[], [2, 2], [3], [999], List.filled(501, 2)]) {
      expect(() => acceptRules(l, table, choices, review, selected: ids), throwsFormatException);
    }
    expect(() => acceptRules(l, table, choices, review, protected: {2}), throwsFormatException);
    final changedChoice = {...choices, 2: {...choices[2]!, 'allowDuplicate': true}};
    expect(() => acceptRules(l, table, changedChoice, review), throwsFormatException);
    final changedFile = ruleTable('Date,Description,Amount,Reference\n2026-10-29,Rule test store,-12.34,new-file');
    expect(() => acceptRules(l, changedFile, choices, review), throwsFormatException);
    final saved = CategoryRules.ordered(l.data).single;
    final changedRule = l.apply('category-rule', {...saved, 'enabled': false, 'operationId': 'changed-rule',
      'expectedRevision': l.revision, 'expectedVersion': saved['version']});
    expect(() => acceptRules(changedRule, table, choices, review), throwsFormatException);
    final changedWorkspace = l.apply('account', account('unrelated', 'Fictional new account', 0));
    expect(() => acceptRules(changedWorkspace, table, choices, review), throwsFormatException);
    expect(jsonEncode(l.data), original);
  });

  test('explicit import posts the accepted category exactly once and retains rules, profiles and all existing data', () {
    var l = csvRulesFixture(); final table = ruleTable(), choices = ruleChoices(l, ruleEntries(ruleTable()));
    final before = LocalLedger.clone(l.data);
    choices.addAll(acceptRules(l, table, choices, ruleReview(l, table, choices)));
    final command = suggestedImport(l, table, choices); l = l.apply('import-csv', command);
    expect(accounts(l).single['balanceMinor'], 146766); expect(l.data['transactions'].length, 3);
    expect(l.data['imports'].length, 3); expect(l.data['schema'], before['schema']);
    for (final key in ['categoryRules', 'importProfiles', 'budgets', 'schedules', 'occurrences', 'reconciliations']) {
      expect(l.data[key], before[key], reason: key);
    }
    final expense = LocalLedger.rows(l.data['transactions']).firstWhere((t) => t['payee'] == 'Rule test store');
    expect(expense['counterpartyAccountId'], namedCategory(l, 'Groceries')); expect(expense['amountMinor'], 1234);
    expect(BudgetEngine.calculate(l.snapshot(), '2026-10').categories.firstWhere((c) => c.id == namedCategory(l, 'Groceries')).spent, 1234);
    expect(identical(l.apply('import-csv', command), l), isTrue);
    expect(ruleReview(l, table, choices).suggestions, isEmpty);
    expect(() => l.apply('import-csv', suggestedImport(l, table, choices, operation: 'repeat')), throwsFormatException);
  });

  test('duplicate approvals and existing reconciled matches cannot be bypassed through suggestions', () {
    var l = csvRulesFixture(); final table = ruleTable(), choices = ruleChoices(l, ruleEntries(ruleTable()));
    l = l.apply('import-csv', suggestedImport(l, table, choices));
    l = l.apply('reconcile', statementRequest(l, closing: 146766));
    final changedFile = ruleTable('Date,Description,Amount,Reference\n2026-10-28,Rule test store,-12.34,new-reference');
    final nextChoices = ruleChoices(l, ruleEntries(changedFile)), before = LocalLedger.clone(l.data);
    nextChoices.addAll(acceptRules(l, changedFile, nextChoices, ruleReview(l, changedFile, nextChoices)));
    expect(nextChoices[2]!['allowDuplicate'], isFalse);
    expect(() => l.apply('import-csv', suggestedImport(l, changedFile, nextChoices, operation: 'duplicate')), throwsFormatException);
    final existing = LocalLedger.rows(l.data['transactions']).first;
    final matched = {...nextChoices, 2: {...nextChoices[2]!, 'action': 'match', 'transactionId': existing['id']}};
    expect(ruleReview(l, changedFile, matched).suggestions, isEmpty); expect(l.data, before);
    final linked = l.apply('import-csv', suggestedImport(l, changedFile, matched, operation: 'match-existing'));
    expect(linked.data['transactions'], before['transactions']); expect(accounts(linked), accounts(l));
  });

  test('income suggestions use income categories; legacy schemas read without migration; all rows beyond page one are covered', () {
    var l = csvRulesFixture();
    l = l.apply('category-rule', {...ruleRequest(l, operation: 'income', priority: 20, kind: 'income'),
      'pattern': 'Fictional income', 'categoryId': namedCategory(l, 'Paycheck')});
    final table = ruleTable(), choices = ruleChoices(l, ruleEntries(ruleTable()));
    final review = ruleReview(l, table, choices);
    expect(review.suggestions.map((p) => p.rowNumber), [2, 4]);
    expect(acceptRules(l, table, choices, review, selected: [4])[4]!['targetId'], namedCategory(l, 'Paycheck'));
    final many = ruleTable('Date,Description,Amount,Reference\n${List.generate(101, (i) => '2026-10-28,Rule test $i,-1.00,row-$i').join('\n')}');
    expect(ruleReview(l, many, ruleChoices(l, ruleEntries(many))).suggestions.length, 101);
    for (final schema in [1, 2, 3, 4, 5]) {
      final data = LocalLedger.clone(l.data)..['schema'] = schema;
      data.remove('importProfiles'); data.remove('categoryRules');
      final legacy = LocalLedger(data), before = jsonEncode(data);
      expect(ruleReview(legacy, table, ruleChoices(legacy, ruleEntries(table))).suggestions, isEmpty);
      expect(jsonEncode(legacy.data), before);
    }
  });
}
