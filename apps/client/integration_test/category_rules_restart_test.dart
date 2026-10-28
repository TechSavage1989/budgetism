import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('RULE_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('RULE_TEST_DIRECTORY');
  testWidgets('saved rules and reviewed categories survive separate native processes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional categorization test'))));
    await tester.runAsync(() async {
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-rules-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? v;
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace a prior test workspace.');
          v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await v.apply('account', {'operationId': 'account', 'name': 'Fictional checking', 'type': 'checking',
            'currency': 'USD', 'openingBalanceMinor': 100000});
          final a = LocalLedger.rows(v.ledger.data['accounts']).single['id'];
          final categories = LocalLedger.rows(v.ledger.data['categories']).where((c) => c['kind'] == 'Expense').toList();
          await v.apply('import-csv', {'operationId': 'import', 'expectedRevision': v.ledger.revision,
            'accountId': a, 'fileHash': List.filled(64, 'e').join(), 'fileName': 'fictional-rules.csv',
            'confirmImportUpgrade': true, 'rows': [{'rowNumber': 2, 'date': '2026-10-28', 'signedMinor': -2500,
              'payee': 'Fictional Corner Shop', 'reference': 'rule-test-only', 'notes': '', 'action': 'create',
              'kind': 'expense', 'targetId': categories.first['id']}]});
          await v.apply('category-rule', {'operationId': 'rule', 'expectedRevision': v.ledger.revision,
            'name': 'Fictional store', 'pattern': 'corner', 'mode': 'contains', 'kind': 'expense',
            'priority': 10, 'enabled': true, 'source': 'statement', 'accountId': null, 'fromCategoryId': null,
            'minimumMinor': null, 'maximumMinor': null, 'categoryId': categories.last['id'], 'confirmRuleUpgrade': true});
          await v.apply('categorize', {'operationId': 'apply', 'expectedRevision': v.ledger.revision,
            'from': '2026-10-01', 'through': '2026-10-31', 'confirmReviewed': true,
            'selections': CategoryRules.preview(v.ledger.snapshot(), from: '2026-10-01', through: '2026-10-31')});
          await v.close(); v = null;
        }
        if (phase == 'write') return;
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(v.passwordRequired, isFalse); expect(v.ledger.data['schema'], 6);
        expect(LocalLedger.rows(v.ledger.snapshot()['accounts']).single['balanceMinor'], 97500);
        expect(v.ledger.data['transactions'].length, 1); expect(v.ledger.data['imports'].length, 1);
        final rule = CategoryRules.ordered(v.ledger.data).single;
        expect(LocalLedger.rows(v.ledger.data['transactions']).single['counterpartyAccountId'], rule['categoryId']);
        expect(CategoryRules.preview(v.ledger.snapshot(), from: '2026-10-01', through: '2026-10-31'), isEmpty);
        final saved = await v.storage.read();
        expect(saved, isNot(contains('Fictional store'))); expect(saved, isNot(contains('corner')));
        await expectLater(v.apply('categorize', {'operationId': 'empty', 'expectedRevision': v.ledger.revision,
          'from': '2026-10-01', 'through': '2026-10-31', 'confirmReviewed': true, 'selections': []}), throwsFormatException);
        expect(await v.storage.read(), saved);
        await v.setPasswordRequired(true, newPassword: 'fictional category rule cleanup');
      } finally { await v?.close(); if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
