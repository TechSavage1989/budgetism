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
  const phase = String.fromEnvironment('RECONCILE_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('RECONCILE_TEST_DIRECTORY');
  testWidgets('statement and protected transactions survive separate native processes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional reconciliation test'))));
    await tester.runAsync(() async {
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-reconcile-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? v;
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace a prior test workspace.');
          v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await v.apply('account', {'operationId': 'account', 'name': 'Fictional checking', 'type': 'checking',
            'currency': 'USD', 'openingBalanceMinor': 100000});
          final account = LocalLedger.rows(v.ledger.data['accounts']).single['id'];
          final category = LocalLedger.rows(v.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Expense')['id'];
          await v.apply('import-csv', {'operationId': 'import', 'expectedRevision': v.ledger.revision,
            'accountId': account, 'fileHash': List.filled(64, 'f').join(), 'fileName': 'fictional-statement.csv',
            'confirmImportUpgrade': true, 'rows': [{'rowNumber': 2, 'date': '2026-10-28', 'signedMinor': -10000,
              'payee': 'Fictional bill', 'reference': 'reconciliation-test-only', 'notes': '', 'action': 'create',
              'kind': 'expense', 'targetId': category}]});
          await v.apply('reconcile', {'operationId': 'statement', 'expectedRevision': v.ledger.revision,
            'accountId': account, 'endDate': '2026-10-31', 'closingMinor': 90000,
            'transactionIds': [LocalLedger.rows(v.ledger.data['transactions']).single['id']],
            'confirmReviewed': true, 'confirmReconciliationUpgrade': true});
          await v.close(); v = null;
        }
        if (phase == 'write') return;
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(v.passwordRequired, isFalse); expect(v.ledger.data['schema'], 5);
        expect(LocalLedger.rows(v.ledger.snapshot()['accounts']).single['balanceMinor'], 90000);
        expect(v.ledger.data['transactions'].length, 1); expect(v.ledger.data['imports'].length, 1);
        final t = LocalLedger.rows(v.ledger.data['transactions']).single;
        final saved = await v.storage.read();
        await expectLater(v.apply('void', {'operationId': 'protected', 'id': t['id'], 'expectedVersion': t['version']}), throwsFormatException);
        expect(await v.storage.read(), saved);
        final s = LocalLedger.rows(v.ledger.data['reconciliations']).single;
        await v.apply('reconcile-reopen', {'operationId': 'reopen', 'id': s['id'], 'expectedVersion': s['version'],
          'expectedRevision': v.ledger.revision, 'confirmReopen': true, 'reason': 'Fictional test correction'});
        await v.close(); v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(Reconciliation.locked(v.ledger.data, t['id']), isFalse);
        expect(v.ledger.data['reconciliations'][0]['reopened'], isTrue);
        expect(v.ledger.data['imports'].length, 1);
        await v.setPasswordRequired(true, newPassword: 'fictional reconciliation cleanup');
      } finally { await v?.close(); if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
