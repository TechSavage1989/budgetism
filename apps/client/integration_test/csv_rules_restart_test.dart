import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/csv_rule_suggestions.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('CSV_RULE_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('CSV_RULE_TEST_DIRECTORY');
  testWidgets('reviewed import categories survive separate native processes without extra posting', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional CSV rule test'))));
    await tester.runAsync(() async {
      if (!['single', 'write', 'read'].contains(phase)) throw StateError('Unknown test phase.');
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-csv-rules-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? v;
      final table = CsvTable.parse('Date,Description,Amount,Reference\n2026-10-28,Fictional rule shop,-12.34,unique-csv-rule');
      final entries = CsvImport.preview(table, const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2, referenceColumn: 3));
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace a test workspace.');
          v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await v.apply('account', {'operationId': 'account', 'name': 'Fictional CSV account', 'type': 'checking',
            'currency': 'USD', 'openingBalanceMinor': 100000});
          final categories = LocalLedger.rows(v.ledger.data['categories']);
          final from = categories.firstWhere((c) => c['name'] == 'Other spending')['id'];
          final to = categories.firstWhere((c) => c['name'] == 'Groceries')['id'];
          await v.apply('category-rule', {'operationId': 'rule', 'expectedRevision': v.ledger.revision,
            'name': 'Fictional import rule', 'pattern': 'Fictional rule', 'mode': 'contains', 'kind': 'expense',
            'priority': 10, 'source': 'statement', 'enabled': true, 'accountId': null, 'fromCategoryId': from,
            'categoryId': to, 'minimumMinor': null, 'maximumMinor': null, 'confirmRuleUpgrade': true});
          final snapshot = v.ledger.snapshot(), accountId = LocalLedger.rows(v.ledger.data['accounts']).single['id'] as String;
          final saved = await v.storage.read();
          final choices = <int, Json>{2: {'action': 'create', 'kind': 'expense', 'targetId': from, 'allowDuplicate': false}};
          final review = CsvRuleSuggestions.preview(snapshot: snapshot, accountId: accountId, fileHash: table.digest,
            entries: entries, choices: choices);
          expect(review.suggestions.single.categoryName, 'Groceries');
          choices.addAll(CsvRuleSuggestions.accept(review: review, snapshot: snapshot, accountId: accountId,
            fileHash: table.digest, entries: entries, choices: choices, selectedRows: [2], confirmed: true));
          expect(await v.storage.read(), saved); expect(v.ledger.data['transactions'], isEmpty);
          await v.apply('import-csv', {'operationId': 'import', 'expectedRevision': v.ledger.revision,
            'accountId': accountId, 'fileHash': table.digest, 'fileName': 'fictional-csv-rule.csv',
            'rows': [{...entries.single.values!, ...choices[2]!}]});
          await v.close(); v = null;
        }
        if (phase == 'write') return;
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        final snapshot = v.ledger.snapshot(), account = LocalLedger.rows(v.ledger.snapshot()['accounts']).single;
        expect(v.passwordRequired, false); expect(v.ledger.data['schema'], 6);
        expect(account['balanceMinor'], 98766); expect(snapshot['transactions'].length, 1); expect(snapshot['imports'].length, 1);
        final rule = CategoryRules.ordered(snapshot).single, transaction = LocalLedger.rows(snapshot['transactions']).single;
        expect(transaction['counterpartyAccountId'], rule['categoryId']); expect(transaction['amountMinor'], 1234);
        final saved = await v.storage.read();
        final choices = <int, Json>{2: {'action': 'create', 'kind': 'expense', 'targetId': rule['fromCategoryId'], 'allowDuplicate': false}};
        expect(CsvRuleSuggestions.preview(snapshot: snapshot, accountId: account['id'], fileHash: table.digest,
          entries: entries, choices: choices).suggestions, isEmpty);
        await expectLater(v.apply('import-csv', {'operationId': 'duplicate', 'expectedRevision': v.ledger.revision,
          'accountId': account['id'], 'fileHash': table.digest, 'fileName': 'fictional-csv-rule.csv',
          'rows': [{...entries.single.values!, ...choices[2]!}]}), throwsFormatException);
        expect(await v.storage.read(), saved); expect(saved, isNot(contains('Fictional import rule')));
        await v.setPasswordRequired(true, newPassword: 'fictional CSV rules cleanup password');
      } finally { await v?.close(); if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
