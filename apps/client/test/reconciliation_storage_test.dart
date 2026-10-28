import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'reconciliation_test.dart' show statementRequest, reopenRequest;

Future<void> seedStatement(LocalVault v) async {
  await v.apply('account', account('a', 'Fictional reconciliation', 100000));
  await v.apply('transaction', tx('t', 'expense', accounts(v.ledger).first['id'], category(v.ledger, 'Expense'), 10000));
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed completion or reopening leaves saved data unchanged; retry is idempotent', () async {
    final store = TestStorage(), keys = TestDeviceKeys();
    final v = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: keys);
    try {
      await seedStatement(v); final before = store.saved;
      final request = statementRequest(v.ledger, closing: 90000);
      store.failWrite = true;
      await expectLater(v.apply('reconcile', request), throwsStateError); expect(store.saved, before);
      expect(v.ledger.data['schema'], 3);
      store.failWrite = false;
      await v.apply('reconcile', request); await v.apply('reconcile', request);
      expect(v.ledger.data['reconciliations'].length, 1);
      final reopen = reopenRequest(v.ledger, v.ledger.data['reconciliations'][0]);
      final saved = store.saved; store.failWrite = true;
      await expectLater(v.apply('reconcile-reopen', reopen), throwsStateError); expect(store.saved, saved);
      store.failWrite = false; await v.apply('reconcile-reopen', reopen);
      expect(accounts(v.ledger).first['balanceMinor'], 90000);
    } finally { await v.close(); }
  });
  test('SQLite reopening, stale writers and encrypted restore preserve statements and locks', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-statements-'); final keys = TestDeviceKeys();
    final path = '${dir.path}/fictional.sqlite3'; LocalVault? v, stale, restored;
    try {
      v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await seedStatement(v);
      stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      final request = statementRequest(v.ledger, closing: 90000);
      await v.apply('reconcile', request);
      await expectLater(stale.apply('reconcile', {...request, 'operationId': 'stale'}), throwsStateError);
      final backup = await v.exportBackup(password: 'fictional backup password');
      await v.close(); v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(v.ledger.data['schema'], 5); expect(v.passwordRequired, isFalse);
      restored = await LocalVault.open(SqliteVaultStorage('${dir.path}/restored.sqlite3'), '',
        create: true, requirePassword: false, deviceKeys: keys);
      await restored.restoreBackup(backup, 'fictional backup password');
      expect(restored.ledger.data['reconciliations'], v.ledger.data['reconciliations']);
      final t = LocalLedger.rows(restored.ledger.data['transactions']).single;
      expect(Reconciliation.locked(restored.ledger.data, t['id']), isTrue);
      expect(accounts(restored.ledger).first['balanceMinor'], 90000);
    } finally { await restored?.close(); await stale?.close(); await v?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
