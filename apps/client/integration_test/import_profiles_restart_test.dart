import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/csv_profiles.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('PROFILE_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('PROFILE_TEST_DIRECTORY');
  testWidgets('saved import profiles survive separate native processes without duplicate posting', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional import profile test'))));
    await tester.runAsync(() async {
      if (!['single', 'write', 'read'].contains(phase)) throw StateError('Unknown profile test phase.');
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-profile-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? v;
      final table = CsvTable.parse('Date,Description,Amount,Reference\n2026-10-28,Fictional profile store,-12.34,profile-unique');
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace an existing test workspace.');
          v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await v.apply('account', {'operationId': 'account', 'name': 'Fictional profile account', 'type': 'checking',
            'currency': 'USD', 'openingBalanceMinor': 100000});
          final categories = LocalLedger.rows(v.ledger.data['categories']);
          final settings = CsvProfiles.capture(table, const CsvMapping(dateColumn: 0, payeeColumn: 1,
            amountColumn: 2, referenceColumn: 3), delimiter: ',', categories: categories,
            expenseCategoryId: categories.firstWhere((c) => c['kind'] == 'Expense')['id'],
            incomeCategoryId: categories.firstWhere((c) => c['kind'] == 'Income')['id']);
          await v.apply('import-profile', {'operationId': 'profile', 'expectedRevision': v.ledger.revision,
            'name': 'Fictional bank profile', 'settings': settings, 'confirmProfileUpgrade': true});
          expect(v.ledger.data['transactions'], isEmpty);
          final profile = ImportProfiles.list(v.ledger.data).single;
          final row = CsvImport.preview(table, CsvProfiles.resolve(profile, table, categories)).single.values!;
          await v.apply('import-csv', {'operationId': 'import', 'expectedRevision': v.ledger.revision,
            'accountId': LocalLedger.rows(v.ledger.data['accounts']).single['id'], 'fileHash': table.digest,
            'fileName': 'fictional-profile.csv', 'rows': [{...row, 'action': 'create', 'kind': 'expense',
              'targetId': settings['expenseCategoryId']}]});
          await v.close(); v = null;
        }
        if (phase == 'write') return;
        v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(v.passwordRequired, false); expect(v.ledger.data['schema'], 7);
        final snapshot = v.ledger.snapshot(), profile = ImportProfiles.list(v.ledger.data).single;
        final account = LocalLedger.rows(snapshot['accounts']).single;
        expect(account['balanceMinor'], 98766); expect(snapshot['transactions'].length, 1); expect(snapshot['imports'].length, 1);
        final saved = await v.storage.read();
        final reordered = CsvTable.parse('Reference,Amount,Description,Date\nprofile-unique,-12.34,Fictional profile store,2026-10-28');
        final mapping = CsvProfiles.resolve(profile, reordered, LocalLedger.rows(snapshot['categories']));
        final row = CsvImport.preview(reordered, mapping).single.values!;
        expect(row['signedMinor'], -1234); expect(CsvImport.consumed(snapshot, account['id'], reordered.digest, row), true);
        await expectLater(v.apply('import-csv', {'operationId': 'duplicate', 'expectedRevision': v.ledger.revision,
          'accountId': account['id'], 'fileHash': reordered.digest, 'fileName': 'fictional-reordered.csv',
          'rows': [{...row, 'action': 'create', 'kind': 'expense', 'targetId': profile['settings']['expenseCategoryId']}]}), throwsFormatException);
        expect(await v.storage.read(), saved); expect(saved, isNot(contains('Fictional bank profile')));
        await v.setPasswordRequired(true, newPassword: 'fictional profile cleanup password');
      } finally { await v?.close(); if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
