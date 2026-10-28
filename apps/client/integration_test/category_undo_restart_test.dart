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
  const phase = String.fromEnvironment('UNDO_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('UNDO_TEST_DIRECTORY');
  testWidgets('category undo and original history persist across native app processes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional category undo test'))));
    await tester.runAsync(() async {
      if (!['single', 'write', 'read'].contains(phase)) throw StateError('Unknown test phase.');
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-undo-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? v;
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace an existing test workspace.');
          v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await v.apply('account', {'operationId': 'account', 'name': 'Fictional checking', 'type': 'checking',
            'currency': 'USD', 'openingBalanceMinor': 100000});
          final a = LocalLedger.rows(v.ledger.data['accounts']).single['id'];
          final categories = LocalLedger.rows(v.ledger.data['categories']).where((c) => c['kind'] == 'Expense').toList();
          await v.apply('import-csv', {'operationId': 'import', 'expectedRevision': v.ledger.revision,
            'accountId': a, 'fileHash': List.filled(64, 'e').join(), 'fileName': 'fictional-undo.csv',
            'confirmImportUpgrade': true, 'rows': [{'rowNumber': 2, 'date': '2026-10-28', 'signedMinor': -1234,
              'payee': 'Fictional Undo Store', 'reference': 'undo-test-only', 'notes': '', 'action': 'create',
              'kind': 'expense', 'targetId': categories.first['id']}]});
          await v.apply('category-rule', {'operationId': 'rule', 'expectedRevision': v.ledger.revision,
            'name': 'Fictional store', 'pattern': 'undo', 'mode': 'contains', 'kind': 'expense',
            'priority': 10, 'enabled': true, 'source': 'statement', 'accountId': null, 'fromCategoryId': null,
            'minimumMinor': null, 'maximumMinor': null, 'categoryId': categories.last['id'], 'confirmRuleUpgrade': true});
          await v.apply('categorize', {'operationId': 'batch', 'expectedRevision': v.ledger.revision,
            'from': '2026-10-01', 'through': '2026-10-31', 'confirmReviewed': true,
            'selections': CategoryRules.preview(v.ledger.data, from: '2026-10-01', through: '2026-10-31')});
          final before = await v.storage.read(), review = CategoryHistory.preview(v.ledger.data, 'batch');
          expect(await v.storage.read(), before);
          final request = <String, dynamic>{'operationId': 'undo', 'sourceOperationId': 'batch',
            'expectedRevision': v.ledger.revision, 'previewFingerprint': review['fingerprint'],
            'reason': 'Fictional native undo test', 'confirmReviewed': true};
          await v.apply('category-undo', request); final saved = await v.storage.read();
          await v.apply('category-undo', request); expect(await v.storage.read(), saved);
          await v.close(); v = null;
        }
        if (phase == 'write') return;
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(v.passwordRequired, false); expect(v.ledger.data['schema'], 6);
        expect(LocalLedger.rows(v.ledger.snapshot()['accounts']).single['balanceMinor'], 98766);
        expect(v.ledger.data['transactions'].length, 1); expect(v.ledger.data['imports'].length, 1);
        expect(v.ledger.data['categoryRules'].length, 1);
        final t = LocalLedger.rows(v.ledger.data['transactions']).single;
        expect(t['counterpartyAccountId'], LocalLedger.rows(v.ledger.data['categories']).first['id']);
        expect(t['version'], 3);
        final saved = await v.storage.read(), review = CategoryHistory.preview(v.ledger.data, 'batch');
        expect(review['undone'], true); expect(review['canUndo'], false);
        await expectLater(v.apply('category-undo', {'operationId': 'repeat', 'sourceOperationId': 'batch',
          'expectedRevision': v.ledger.revision, 'previewFingerprint': review['fingerprint'],
          'reason': 'Attempted second undo', 'confirmReviewed': true}), throwsFormatException);
        expect(await v.storage.read(), saved); expect(saved, isNot(contains('Fictional native undo')));
        await v.setPasswordRequired(true, newPassword: 'fictional undo cleanup password');
      } finally { await v?.close(); if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
