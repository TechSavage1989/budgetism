import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/csv_profiles.dart';
import 'local_ledger_test.dart' show account, accounts, category;
import 'csv_import_test.dart' show createRow, importBatch;
import 'category_history_test.dart' show appliedFixture, undoRequest;
import 'reconciliation_test.dart' show statementRequest;

CsvTable profileTable() => CsvTable.parse('Date,Description,Amount,Reference,Notes\n2026-10-28,Fictional private row,-12.34,fictional-id,Fictional private note');
Json profileSettings(LocalLedger l) => CsvProfiles.capture(profileTable(),
  const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2, referenceColumn: 3, notesColumn: 4),
  delimiter: ',', categories: LocalLedger.rows(l.data['categories']),
  expenseCategoryId: category(l, 'Expense'), incomeCategoryId: category(l, 'Income'));
Json profileRequest(LocalLedger l, {String operation = 'profile', String name = 'Fictional bank'}) => {
  'operationId': operation, 'expectedRevision': l.revision, 'name': name,
  'settings': profileSettings(l), 'confirmProfileUpgrade': true};
Json profileState(LocalLedger l, bool archived, {String operation = 'profile-state'}) {
  final p = ImportProfiles.list(l.data, includeArchived: true).single;
  return {'operationId': operation, 'expectedRevision': l.revision, 'id': p['id'],
    'expectedVersion': p['version'], 'archived': archived, 'confirmReviewed': true};
}

void main() {
  test('profile save requires consent, stores settings only and preserves all prior financial records', () {
    final l = appliedFixture(); final before = jsonEncode(l.data), request = profileRequest(l);
    expect(() => l.apply('import-profile', {...request, 'confirmProfileUpgrade': false}), throwsFormatException);
    expect(jsonEncode(l.data), before);
    var saved = l.apply('import-profile', request);
    expect(saved.data['schema'], 7); expect(saved.apply('import-profile', request).data, saved.data);
    for (final key in ['accounts', 'categories', 'transactions', 'budgets', 'schedules', 'occurrences', 'imports', 'reconciliations', 'categoryRules']) {
      expect(saved.data[key], l.data[key], reason: key);
    }
    expect(jsonEncode(saved.data), isNot(contains('Fictional private row')));
    expect(jsonEncode(saved.data), isNot(contains('fictional-id')));
    expect(jsonEncode(saved.data), isNot(contains('Fictional private note')));
    final originalProfile = ImportProfiles.list(saved.data).single;
    saved = saved.apply('category-undo', undoRequest(saved));
    expect(ImportProfiles.list(saved.data).single, originalProfile);
    expect(CategoryHistory.batches(saved.data).single['undone'], true);
    expect(accounts(saved), accounts(l));
  });

  test('all old financial schemas migrate only on explicit profile save', () {
    for (var schema = 1; schema <= 6; schema++) {
      final data = LocalLedger.clone(LocalLedger.empty().data)..['schema'] = schema;
      if (schema < 2) data.remove('budgets');
      if (schema < 3) { data.remove('schedules'); data.remove('occurrences'); }
      if (schema >= 4) data['imports'] = <Json>[];
      if (schema >= 5) data['reconciliations'] = <Json>[];
      if (schema >= 6) data['categoryRules'] = <Json>[];
      final l = LocalLedger(data), before = jsonEncode(data);
      expect(ImportProfiles.list(l.snapshot()), isEmpty); expect(jsonEncode(l.data), before);
      final saved = l.apply('import-profile', profileRequest(l));
      expect(saved.data['schema'], 7); expect(l.data['schema'], schema);
      for (final key in data.keys.where((k) => !['schema', 'audit', 'revision', 'operations'].contains(k))) {
        expect(saved.data[key], data[key], reason: key);
      }
    }
  });

  test('header names survive reordered and additional columns; preview keeps exact cents and identity', () {
    final seed = LocalLedger.empty();
    final l = seed.apply('import-profile', profileRequest(seed));
    // A profile without defaults can also be used with a different category set.
    final p = ImportProfiles.list(l.data).single, table = profileTable();
    final cats = LocalLedger.rows(l.data['categories']);
    final before = jsonEncode(l.data);
    final expected = CsvImport.preview(table, CsvProfiles.resolve(p, table, cats)).single.values!;
    final reordered = CsvTable.parse('Ignored,Notes,amount,Description,Reference, DATE \nignore,Fictional private note,-12.34,Fictional private row,fictional-id,2026-10-28');
    final actual = CsvImport.preview(reordered, CsvProfiles.resolve(p, reordered, cats)).single.values!;
    expect(actual, expected); expect(jsonEncode(l.data), before);
    expect(actual['signedMinor'], -1234);
    final detached = ImportProfiles.list(l.data).single; detached['settings']['columns']['date'] = 'Changed copy';
    expect(jsonEncode(l.data), before);
  });

  test('ambiguous or missing mapped headers never fall back to old column positions', () {
    final l = LocalLedger.empty(); final saved = l.apply('import-profile', profileRequest(l));
    final p = ImportProfiles.list(saved.data).single, cats = LocalLedger.rows(saved.data['categories']);
    for (final raw in ['Date,Description,Amount,Reference\n2026-10-28,Test,-1,x',
      'Date,Description,Amount,Reference,Notes, date\n2026-10-28,Test,-1,x,n,2026-10-28',
      'Changed,Description,Amount,Reference,Notes\n2026-10-28,Test,-1,x,n']) {
      expect(() => CsvProfiles.resolve(p, CsvTable.parse(raw), cats), throwsFormatException);
    }
    final duplicate = CsvTable.parse('Date,Description,Amount, amount\n2026-10-28,Test,-1,-1');
    expect(() => CsvProfiles.capture(duplicate, const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2),
      delimiter: ',', categories: cats), throwsFormatException);
    expect(() => CsvProfiles.resolve({...p, 'archived': true}, profileTable(), cats), throwsFormatException);
  });

  test('separator, dates, split columns, optional fields and reversed signs are retained explicitly', () {
    final cats = LocalLedger.rows(LocalLedger.empty().data['categories']);
    for (final separator in [',', ';', '\t']) {
      final table = CsvTable.parse(['When${separator}Memo${separator}Out${separator}In',
        '28/10/2026${separator}Fictional debit${separator}10.01$separator',
        '29/10/2026${separator}Fictional credit$separator${separator}20.00'].join('\n'), delimiter: separator);
      final settings = CsvProfiles.capture(table, const CsvMapping(dateColumn: 0, payeeColumn: 1,
        debitColumn: 2, creditColumn: 3, dateFormat: 'dmy', reverseSign: true), delimiter: separator, categories: cats);
      expect(settings['reverseSign'], false); expect(settings['columns']['amount'], isNull);
      final mapping = CsvProfiles.resolve({'settings': settings, 'archived': false}, table, cats);
      expect(CsvImport.preview(table, mapping).map((e) => e.values!['signedMinor']), [-1001, 2000]);
      expect(mapping.dateFormat, 'dmy'); expect(mapping.referenceColumn, -1); expect(mapping.notesColumn, -1);
    }
    final signed = CsvTable.parse('When,Memo,Value\n10/28/2026,Fictional debit,0.10');
    final settings = CsvProfiles.capture(signed, const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2,
      dateFormat: 'mdy', reverseSign: true), delimiter: ',', categories: cats);
    expect(CsvImport.preview(signed, CsvProfiles.resolve({'settings': settings, 'archived': false}, signed, cats)).single.values!['signedMinor'], -10);
  });

  test('rename, update, archive and restore preserve identities, settings and append-only audit', () {
    var l = LocalLedger.empty(); l = l.apply('import-profile', profileRequest(l));
    final p = ImportProfiles.list(l.data).single;
    final request = {...profileRequest(l, operation: 'rename', name: 'Renamed fictional bank'),
      'id': p['id'], 'expectedVersion': p['version']};
    l = l.apply('import-profile', request); expect(ImportProfiles.list(l.data).single['id'], p['id']);
    expect(() => l.apply('import-profile', profileRequest(l, operation: 'duplicate', name: 'RENAMED FICTIONAL BANK')), throwsFormatException);
    final archive = profileState(l, true); l = l.apply('import-profile-state', archive);
    expect(l.apply('import-profile-state', archive).data, l.data); expect(ImportProfiles.list(l.data), isEmpty);
    final archived = ImportProfiles.list(l.data, includeArchived: true).single;
    expect(archived['settings'], p['settings']);
    expect(() => l.apply('import-profile', {...request, 'operationId': 'edit-archived',
      'expectedRevision': l.revision, 'expectedVersion': archived['version']}), throwsFormatException);
    expect(() => l.apply('import-profile', profileRequest(l, operation: 'duplicate-archived', name: 'Renamed fictional bank')), throwsFormatException);
    l = l.apply('import-profile-state', profileState(l, false, operation: 'restore'));
    expect(ImportProfiles.list(l.data).single['version'], 4);
    expect(l.data['transactions'], isEmpty); expect(l.data['audit'].length, 4);
  });

  test('stale revisions, versions, unknown profiles and missing archive consent fail atomically', () {
    var l = LocalLedger.empty(); l = l.apply('import-profile', profileRequest(l));
    final p = ImportProfiles.list(l.data).single, before = jsonEncode(l.data);
    for (final patch in <Json>[{'expectedRevision': -1}, {'id': 'missing'}, {'id': p['id'], 'expectedVersion': -1}, {'name': ' '}]) {
      expect(() => l.apply('import-profile', {...profileRequest(l, operation: 'bad'), ...patch}), throwsFormatException);
      expect(jsonEncode(l.data), before);
    }
    for (final patch in <Json>[{'confirmReviewed': false}, {'expectedRevision': -1}, {'expectedVersion': -1}, {'archived': false}, {'archived': 'yes'}]) {
      expect(() => l.apply('import-profile-state', {...profileState(l, true), ...patch}), throwsFormatException);
      expect(jsonEncode(l.data), before);
    }
    expect(() => l.apply('import-profile', {...profileRequest(l), 'name': 'Changed replay'}), throwsFormatException);
  });

  test('invalid or corrupt settings and profiles are rejected without storing arbitrary row data', () {
    final l = LocalLedger.empty(); final s = profileSettings(l);
    for (final patch in <Json>[{'delimiter': '|'}, {'dateFormat': 'guess'}, {'amountMode': 'guess'}, {'reverseSign': 'yes'},
      {'csvRows': ['not allowed']}, {'accountId': 'not allowed'}, {'columns': {}},
      {'expenseCategoryId': 'missing'}, {'incomeCategoryId': category(l, 'Expense')},
      {'columns': {...s['columns'] as Json, 'date': null}},
      {'columns': {...s['columns'] as Json, 'payee': ' DATE '}}]) {
      expect(() => l.apply('import-profile', {...profileRequest(l), 'settings': {...s, ...patch}}), throwsFormatException);
    }
    final saved = l.apply('import-profile', profileRequest(l));
    for (final patch in <Json>[{'version': 0}, {'archived': 'no'}, {'operationId': 'unknown'}, {'name': ' '},
      {'settings': {}}, {'id': category(l, 'Expense')}]) {
      final data = LocalLedger.clone(saved.data); data['importProfiles'][0].addAll(patch);
      expect(() => LocalLedger(data), throwsFormatException);
    }
    expect(() => LocalLedger({...saved.data, 'schema': 6}), throwsFormatException);
    expect(() => LocalLedger({...saved.data}..remove('importProfiles')), throwsFormatException);
    expect(() => LocalLedger({...saved.data, 'importProfiles': [false]}), throwsFormatException);
  });

  test('imports keep profile definitions and deduplication; reconciliation still protects transactions', () {
    var l = LocalLedger.empty().apply('account', account('a', 'Fictional account', 100000));
    l = l.apply('import-profile', profileRequest(l)); final profiles = LocalLedger.clone(l.data)['importProfiles'];
    l = l.apply('import-csv', importBatch(l, [createRow(l)], upgrade: false));
    expect(l.data['schema'], 7); expect(l.data['importProfiles'], profiles);
    expect(() => l.apply('import-csv', importBatch(l, [createRow(l)], operation: 'again')), throwsFormatException);
    l = l.apply('reconcile', statementRequest(l, closing: 98000));
    final t = LocalLedger.rows(l.data['transactions']).single;
    expect(Reconciliation.locked(l.data, t['id']), true);
    expect(l.data['importProfiles'], profiles); expect(l.data['schema'], 7);
  });

  test('profile count includes archived definitions and duplicate identifiers are rejected', () {
    var l = LocalLedger.empty(); l = l.apply('import-profile', profileRequest(l));
    final p = ImportProfiles.list(l.data).single, data = LocalLedger.clone(l.data);
    data['importProfiles'] = [for (var i = 0; i < ImportProfiles.maxProfiles; i++)
      {...p, 'id': 'profile-$i', 'name': 'Fictional $i', 'archived': i.isEven}];
    l = LocalLedger(data);
    expect(() => l.apply('import-profile', profileRequest(l, operation: 'over-limit', name: 'Another')), throwsFormatException);
    final duplicate = LocalLedger.clone(l.data); duplicate['importProfiles'][1]['id'] = 'profile-0';
    expect(() => LocalLedger(duplicate), throwsFormatException);
  });
}
