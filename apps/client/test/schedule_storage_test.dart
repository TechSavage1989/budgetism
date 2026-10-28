import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account;
import 'schedules_test.dart' show scheduleInput, occurrenceInput;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a failed confirmation saves neither the occurrence nor its transaction; retry saves once', () async {
    final storage = TestStorage();
    final vault = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    try {
      await vault.apply('account', account('a', 'Fictional test account', 10000));
      await vault.apply('schedule', scheduleInput(vault.ledger, 'schedule'));
      final before = storage.saved;
      final command = {...occurrenceInput(vault.ledger, 'confirm', 0), 'amountMinor': 2000, 'effectiveDate': '2026-01-31'};
      storage.failWrite = true;
      await expectLater(vault.apply('schedule-confirm', command), throwsStateError);
      expect(storage.saved, before);
      expect(vault.ledger.data['occurrences'], isEmpty); expect(vault.ledger.data['transactions'], isEmpty);
      storage.failWrite = false;
      await vault.apply('schedule-confirm', command);
      await vault.apply('schedule-confirm', command);
      expect(LocalLedger.rows(vault.ledger.data['transactions']).length, 1);
    } finally { await vault.close(); }
  });
  test('SQLite reopening, stale writers and encrypted backup restore retain schedules and links', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-schedule-store-');
    final path = '${dir.path}${Platform.pathSeparator}workspace.sqlite3';
    final keys = TestDeviceKeys();
    LocalVault? vault; LocalVault? stale; LocalVault? restored;
    const backupPassword = 'fictional schedule backup password';
    try {
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await vault.apply('account', account('a', 'Fictional schedule account', 10000));
      await vault.apply('schedule', scheduleInput(vault.ledger, 'schedule'));
      stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      final command = {...occurrenceInput(vault.ledger, 'confirm', 0), 'amountMinor': 2000, 'effectiveDate': '2026-01-31'};
      await vault.apply('schedule-confirm', command);
      await expectLater(stale.apply('schedule-confirm', {...command, 'operationId': 'other-window'}), throwsStateError);
      await stale.refresh();
      await expectLater(stale.apply('schedule-confirm', {...command, 'operationId': 'new-attempt'}), throwsFormatException);
      final backup = await vault.exportBackup(password: backupPassword);
      expect(backup, isNot(contains('Fictional schedule account')));
      await vault.close(); vault = null;
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(vault.passwordRequired, isFalse);
      expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 8000);
      expect(BudgetEngine.calculate(vault.ledger.snapshot(), '2026-01').spent, 2000);
      restored = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await restored.restoreBackup(backup, backupPassword);
      expect(restored.ledger.data['schedules'], vault.ledger.data['schedules']);
      expect(restored.ledger.data['occurrences'], vault.ledger.data['occurrences']);
      expect(restored.passwordRequired, isFalse);
      await expectLater(restored.apply('schedule-confirm', {...command, 'operationId': 'after-restore'}), throwsFormatException);
    } finally {
      await restored?.close(); await stale?.close(); await vault?.close(); dir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
