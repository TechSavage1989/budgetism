import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account, accounts;
import 'csv_import_test.dart' show importBatch, createRow;
import 'schedules_test.dart' show scheduleInput;
import 'schedule_matching_test.dart' show matchRequest;

Future<void> seedMatch(LocalVault vault) async {
  await vault.apply('account', account('a', 'Fictional matching', 100000));
  await vault.apply('schedule', scheduleInput(vault.ledger, 'schedule', start: '2026-10-28'));
  await vault.apply('import-csv', importBatch(vault.ledger, [{...createRow(vault.ledger), 'date': '2026-10-28'}]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed link commits neither side or audit; unchanged retry links once', () async {
    final storage = TestStorage();
    final vault = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    try {
      await seedMatch(vault);
      final saved = storage.saved, before = LocalLedger.clone(vault.ledger.data);
      final command = matchRequest(vault.ledger, 'link');
      storage.failWrite = true;
      await expectLater(vault.apply('schedule-match', command), throwsStateError);
      expect(storage.saved, saved); expect(vault.ledger.data, before);
      storage.failWrite = false;
      await vault.apply('schedule-match', command); await vault.apply('schedule-match', command);
      expect(vault.ledger.data['transactions'].length, 1); expect(vault.ledger.data['occurrences'].length, 1);
      expect(vault.ledger.data['imports'], before['imports']);
      expect(accounts(vault.ledger).single['balanceMinor'], 98000);
    } finally { await vault.close(); }
  });

  test('real SQLite reopen, stale writers and encrypted backups preserve links and receipts', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-match-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys(); LocalVault? vault, stale, restored;
    const password = 'fictional matching backup only';
    try {
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await seedMatch(vault);
      stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      final command = matchRequest(vault.ledger, 'link');
      await vault.apply('schedule-match', command);
      await expectLater(stale.apply('schedule-match', {...command, 'operationId': 'stale-window'}), throwsStateError);
      await stale.close(); stale = null;
      final backup = await vault.exportBackup(password: password);
      expect(backup, isNot(contains('Fictional matching')));
      final before = LocalLedger.clone(vault.ledger.data);
      await vault.close(); vault = null;
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(vault.passwordRequired, isFalse); expect(vault.ledger.data, before);
      await expectLater(vault.apply('schedule-match', matchRequest(vault.ledger, 'again')), throwsFormatException);
      restored = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await restored.restoreBackup(backup, password);
      for (final key in ['accounts', 'transactions', 'imports', 'schedules', 'occurrences']) {
        expect(restored.ledger.data[key], before[key]);
      }
      expect(restored.passwordRequired, isFalse);
      await expectLater(restored.apply('schedule-match', matchRequest(restored.ledger, 'restored-again')), throwsFormatException);
    } finally { await restored?.close(); await stale?.close(); await vault?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
