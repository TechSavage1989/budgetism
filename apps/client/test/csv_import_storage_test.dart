import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account, accounts;
import 'csv_import_test.dart' show importBatch, createRow;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed import commit is atomic; retry uses the same operation and saves once', () async {
    final store = TestStorage(), keys = TestDeviceKeys();
    final vault = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: keys);
    try {
      await vault.apply('account', account('a', 'Fictional account', 100000));
      final before = store.saved;
      final request = importBatch(vault.ledger, [createRow(vault.ledger)]);
      store.failWrite = true;
      await expectLater(vault.apply('import-csv', request), throwsStateError);
      expect(store.saved, before); expect(vault.ledger.data['schema'], LocalLedger.schema);
      expect(vault.ledger.snapshot()['imports'], isEmpty); expect(vault.ledger.snapshot()['transactions'], isEmpty);
      store.failWrite = false;
      await vault.apply('import-csv', request); await vault.apply('import-csv', request);
      expect(vault.ledger.snapshot()['transactions'].length, 1); expect(vault.ledger.snapshot()['imports'].length, 1);
      expect(vault.passwordRequired, isFalse);
    } finally { await vault.close(); }
  });
  test('actual SQLite restart, stale writes and encrypted backup restore preserve import identities', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-csv-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys();
    LocalVault? vault, stale, restored;
    try {
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await vault.apply('account', account('a', 'Fictional import account', 100000));
      stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      final request = importBatch(vault.ledger, [createRow(vault.ledger)]);
      await vault.apply('import-csv', request);
      await expectLater(stale.apply('import-csv', {...request, 'operationId': 'stale'}), throwsStateError);
      await stale.close(); stale = null;
      final backup = await vault.exportBackup(password: 'fictional import backup only');
      expect(backup, isNot(contains('Fictional shop')));
      final original = vault.ledger.data;
      await vault.close(); vault = null;
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(vault.ledger.data, original); expect(accounts(vault.ledger).single['balanceMinor'], 98000);
      await expectLater(vault.apply('import-csv', importBatch(vault.ledger, [createRow(vault.ledger)], operation: 'repeat')), throwsFormatException);
      restored = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await restored.restoreBackup(backup, 'fictional import backup only');
      expect(restored.ledger.data['imports'], original['imports']); expect(restored.passwordRequired, isFalse);
      await expectLater(restored.apply('import-csv', importBatch(restored.ledger, [createRow(restored.ledger)], operation: 'repeat-restored')), throwsFormatException);
    } finally { await restored?.close(); await stale?.close(); await vault?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
