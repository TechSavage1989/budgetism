import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/transaction_register.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native register filtering preserves encrypted workspace and protections after reopening', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional register preservation test'))));
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('budgetism-register-');
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? v;
      try {
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
        await v.apply('account', {'operationId': 'account', 'name': 'Fictional checking', 'type': 'checking',
          'currency': 'USD', 'openingBalanceMinor': 100000});
        final a = LocalLedger.rows(v.ledger.data['accounts']).single['id'];
        final cats = LocalLedger.rows(v.ledger.data['categories']).where((c) => c['kind'] == 'Expense').toList();
        await v.apply('import-csv', {'operationId': 'import', 'expectedRevision': v.ledger.revision,
          'accountId': a, 'fileHash': List.filled(64, 'd').join(), 'fileName': 'fictional-register.csv',
          'confirmImportUpgrade': true, 'rows': [{'rowNumber': 2, 'date': '2026-10-28', 'signedMinor': -1234,
            'payee': 'Fictional register shop', 'reference': 'register-fixture-only', 'notes': '', 'action': 'create',
            'kind': 'expense', 'targetId': cats.first['id']}]});
        await v.apply('category-rule', {'operationId': 'rule', 'expectedRevision': v.ledger.revision,
          'name': 'Fictional rule', 'pattern': 'register', 'mode': 'contains', 'kind': 'expense', 'priority': 10,
          'enabled': false, 'source': 'all', 'accountId': null, 'fromCategoryId': null,
          'minimumMinor': null, 'maximumMinor': null, 'categoryId': cats.last['id'], 'confirmRuleUpgrade': true});
        final t = LocalLedger.rows(v.ledger.data['transactions']).single;
        await v.apply('reconcile', {'operationId': 'statement', 'expectedRevision': v.ledger.revision,
          'accountId': a, 'endDate': '2026-10-28', 'closingMinor': 98766, 'transactionIds': [t['id']], 'confirmReviewed': true});
        final encoded = await v.storage.read(), data = jsonEncode(v.ledger.data), revision = v.ledger.revision;
        RegisterResult read() => TransactionRegister.calculate(v!.ledger.snapshot(includeVoided: true),
          RegisterFilter(query: '"register shop" -missing', accountId: a, kind: 'expense',
            status: 'reconciled', source: 'statement', minimum: '12.34', maximum: '12.34',
            from: '2026-10-28', through: '2026-10-28'));
        expect(read().entries.single.canEdit, isFalse); expect(read().expenses, 1234);
        for (final order in TransactionRegister.sorts.keys) {
          final result = TransactionRegister.calculate(v.ledger.snapshot(includeVoided: true), RegisterFilter(sort: order));
          expect(result.entries.single.id, t['id']); expect(result.entries.single.receipts.length, 1);
        }
        expect(() => TransactionRegister.calculate(v!.ledger.snapshot(), const RegisterFilter(minimum: '1.001')), throwsFormatException);
        expect(await v.storage.read(), encoded); expect(jsonEncode(v.ledger.data), data); expect(v.ledger.revision, revision);
        await v.close(); v = null;
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(v.passwordRequired, isFalse); expect(v.ledger.data['schema'], 6); expect(v.ledger.data['categoryRules'].length, 1);
        expect(read().expenses, 1234); expect(read().entries.single.canEdit, isFalse);
        expect(await v.storage.read(), encoded); expect(jsonEncode(v.ledger.data), data);
        await expectLater(v.apply('void', {'operationId': 'blocked', 'id': t['id'], 'expectedVersion': t['version']}), throwsFormatException);
        expect(await v.storage.read(), encoded);
        await v.setPasswordRequired(true, newPassword: 'fictional register cleanup');
      } finally { await v?.close(); dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
