import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/csv_import.dart';
import 'package:budgetism/local/csv_profiles.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account, accounts;
import 'import_profiles_test.dart' show profileRequest, profileState, profileTable;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed migration and archive leave ciphertext and financial data unchanged; retry saves once', () async {
    final storage = TestStorage();
    final v = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    try {
      await v.apply('account', account('account', 'Fictional profile account', 100000));
      for (final action in ['import-profile', 'import-profile-state']) {
        final input = action == 'import-profile' ? profileRequest(v.ledger) : profileState(v.ledger, true);
        final before = LocalLedger.clone(v.ledger.data), saved = storage.saved;
        storage.failWrite = true;
        await expectLater(v.apply(action, input), throwsStateError);
        expect(v.ledger.data, before); expect(storage.saved, saved);
        storage.failWrite = false; await v.apply(action, input); final committed = storage.saved;
        await v.apply(action, input); expect(storage.saved, committed);
      }
      expect(accounts(v.ledger).single['balanceMinor'], 100000); expect(v.ledger.data['transactions'], isEmpty);
      expect(storage.saved, isNot(contains('Fictional bank')));
    } finally { await v.close(); }
  });

  test('SQLite reopen, stale writers and independently encrypted backups preserve profiles and security', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-profiles-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys(); LocalVault? v, stale, target;
    const password = 'fictional import profile backup password';
    try {
      v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await v.apply('account', account('account', 'Fictional profile account', 100000));
      stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      await v.apply('import-profile', profileRequest(v.ledger));
      await expectLater(stale.apply('import-profile', profileRequest(stale.ledger, operation: 'stale')), throwsStateError);
      await stale.close(); stale = null;
      final before = LocalLedger.clone(v.ledger.data), backup = await v.exportBackup(password: password);
      expect(backup, isNot(contains('Fictional bank')));
      await v.close(); v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(v.passwordRequired, false); expect(v.ledger.data, before);
      final encrypted = await v.storage.read();
      final table = profileTable();
      final mapping = CsvProfiles.resolve(ImportProfiles.list(v.ledger.data).single, table, LocalLedger.rows(v.ledger.data['categories']));
      expect(CsvImport.preview(table, mapping).single.values!['signedMinor'], -1234);
      expect(await v.storage.read(), encrypted);
      target = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await target.restoreBackup(backup, password);
      expect(target.ledger.data['importProfiles'], before['importProfiles']);
      expect(target.ledger.data['transactions'], before['transactions']); expect(target.passwordRequired, false);
    } finally { await target?.close(); await stale?.close(); await v?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
