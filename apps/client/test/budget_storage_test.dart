import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'budgets_test.dart' show plan, row;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('legacy budget upgrade is atomic, keeps password, survives SQLite reopen and backup restore', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-budgets-');
    final path = '${dir.path}${Platform.pathSeparator}budget-test.sqlite3';
    final seed = SqliteVaultStorage(path);
    final legacy = File('test/fixtures/legacy_password_v1.json').readAsStringSync();
    await seed.write(legacy, expectedRevision: -1);
    await seed.close();
    const password = 'legacy testing password only';
    const backupPassword = 'fictional budget backup password';
    LocalVault? vault;
    LocalVault? stale;
    LocalVault? destination;
    try {
      vault = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
      // The independent v1 fixture deliberately has no categories. Add one
      // through the legacy finance path before exercising the budget upgrade.
      expect(vault.ledger.data['categories'], isEmpty);
      await vault.apply('category', {'operationId': 'fixture-expense-category',
        'name': 'Fictional legacy groceries', 'kind': 'Expense'});
      expect(vault.ledger.data['schema'], LocalLedger.legacySchema);
      final legacyWithCategory = await vault.storage.read();
      stale = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
      final categories = LocalLedger.rows(vault.ledger.data['categories']);
      final id = categories.firstWhere((c) => c['kind'] == 'Expense')['id'] as String;
      final original = vault.ledger.snapshot();
      await expectLater(vault.apply('budget', plan('upgrade', id, '2026-10', 10000)), throwsFormatException);
      expect(await vault.storage.read(), legacyWithCategory);
      await vault.apply('budget', plan('upgrade', id, '2026-10', 10000, rollover: 'all', upgrade: true));
      expect(vault.passwordRequired, true);
      expect(vault.ledger.snapshot()['accounts'], original['accounts']);
      expect(vault.ledger.snapshot()['transactions'], original['transactions']);
      expect(LocalVault.header((await vault.storage.read())!)['salt'], LocalVault.header(legacy)['salt']);
      await expectLater(stale.apply('budget', plan('stale', id, '2026-11', 100)), throwsFormatException);
      // A confirmed stale writer passes the schema gate but fails SQLite revision CAS.
      await expectLater(stale.apply('budget', plan('stale', id, '2026-11', 100, upgrade: true)), throwsStateError);
      await stale.close(); stale = null;
      final backup = await vault.exportBackup(password: backupPassword);
      expect(backup, isNot(contains('amountMinor')));
      expect(utf8.decode(File(path).readAsBytesSync(), allowMalformed: true), isNot(contains('Legacy checking')));
      await vault.close(); vault = null;
      vault = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
      expect(row(vault.ledger, '2026-10', id).allocated, 10000);
      expect(vault.ledger.data['schema'], LocalLedger.schema);
      destination = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await destination.restoreBackup(backup, backupPassword);
      expect(destination.passwordRequired, false);
      expect(destination.ledger.snapshot()['budgets'], vault.ledger.snapshot()['budgets']);
      expect(BudgetEngine.calculate(destination.ledger.snapshot(), '2026-11').carried, 10000);
      await destination.restoreBackup(legacy, password);
      expect(destination.ledger.data['schema'], LocalLedger.legacySchema);
      expect(destination.ledger.snapshot()['budgets'], isEmpty);
      expect(destination.passwordRequired, false);
    } finally {
      await destination?.close(); await stale?.close(); await vault?.close();
      dir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('failed budget save leaves encrypted data and displayed ledger unchanged', () async {
    final store = TestStorage();
    final vault = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    try {
      final id = LocalLedger.rows(vault.ledger.data['categories']).first['id'] as String;
      final before = store.saved;
      store.failWrite = true;
      await expectLater(vault.apply('budget', plan('fail', id, '2026-10', 10000)), throwsStateError);
      expect(store.saved, before);
      expect(vault.ledger.snapshot()['budgets'], isEmpty);
      store.failWrite = false;
      await vault.apply('budget', plan('fail', id, '2026-10', 10000));
      expect(row(vault.ledger, '2026-10', id).allocated, 10000);
    } finally { await vault.close(); }
  });
}
