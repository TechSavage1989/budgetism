import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('IMPORT_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('IMPORT_TEST_DIRECTORY');
  testWidgets('CSV import receipts survive native process exit and block duplicate reimport', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Budgetism CSV validation'))));
    await tester.runAsync(() async {
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-native-import-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}import-test.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? vault;
      final table = CsvTable.parse('Date,Description,Amount\n2026-10-28,Fictional income,500\n2026-10-28,Fictional expense,-200');
      final entries = CsvImport.preview(table, const CsvMapping(dateColumn: 0, payeeColumn: 1, amountColumn: 2));
      Json request(LocalLedger ledger, String operation) => {'operationId': operation, 'expectedRevision': ledger.revision,
        'accountId': LocalLedger.rows(ledger.data['accounts']).single['id'], 'fileHash': table.digest, 'fileName': 'native-fictional.csv',
        'confirmImportUpgrade': true, 'rows': [for (final e in entries) {...e.values!, 'action': 'create',
          'kind': e.values!['signedMinor'] > 0 ? 'income' : 'expense',
          'targetId': LocalLedger.rows(ledger.data['categories']).firstWhere((c) => c['kind'] == (e.values!['signedMinor'] > 0 ? 'Income' : 'Expense'))['id']}]};
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to overwrite another test workspace.');
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await vault.apply('account', {'operationId': 'account', 'name': 'Fictional native CSV', 'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 100000});
          await vault.apply('import-csv', request(vault.ledger, 'native-import'));
          await vault.close(); vault = null;
        }
        if (phase == 'write') return;
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(vault.passwordRequired, isFalse);
        expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 130000);
        expect(vault.ledger.data['imports'].length, 2); expect(vault.ledger.data['transactions'].length, 2);
        final before = await vault.storage.read();
        await expectLater(vault.apply('import-csv', request(vault.ledger, 'duplicate-after-restart')), throwsFormatException);
        expect(await vault.storage.read(), before);
        await vault.setPasswordRequired(true, newPassword: 'fictional import cleanup only');
      } finally {
        await vault?.close();
        if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
