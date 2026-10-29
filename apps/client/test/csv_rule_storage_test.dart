import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestStorage, TestDeviceKeys;
import 'local_ledger_test.dart' show accounts;
import 'csv_rule_suggestions_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('suggestions never write; failed import is atomic; accepted choice can retry without duplicate posting', () async {
    final storage = TestStorage(); final keys = TestDeviceKeys();
    final v = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: keys);
    try {
      await seedCsvRules(v);
      final table = ruleTable(), choices = ruleChoices(v.ledger, ruleEntries(ruleTable()));
      final original = storage.saved, before = LocalLedger.clone(v.ledger.data);
      choices.addAll(acceptRules(v.ledger, table, choices, ruleReview(v.ledger, table, choices)));
      expect(storage.saved, original); expect(v.ledger.data, before);
      final request = suggestedImport(v.ledger, table, choices);
      storage.failWrite = true; await expectLater(v.apply('import-csv', request), throwsStateError);
      expect(storage.saved, original); expect(v.ledger.data, before);
      storage.failWrite = false; await v.apply('import-csv', request);
      final saved = storage.saved; await v.apply('import-csv', request);
      expect(storage.saved, saved); expect(accounts(v.ledger).single['balanceMinor'], 146766);
    } finally { await v.close(); }
  });

  test('saved suggested categories persist through SQLite reopen and independently encrypted backup restoration', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-csv-rules-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys(); LocalVault? v, target;
    try {
      v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await seedCsvRules(v);
      final table = ruleTable(), choices = ruleChoices(v.ledger, ruleEntries(ruleTable()));
      choices.addAll(acceptRules(v.ledger, table, choices, ruleReview(v.ledger, table, choices)));
      await v.apply('import-csv', suggestedImport(v.ledger, table, choices));
      final before = LocalLedger.clone(v.ledger.data), backup = await v.exportBackup(password: 'fictional result backup password');
      final ciphertext = await v.storage.read();
      expect(ciphertext, isNot(contains('Rule test store')));
      await v.close(); v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(v.ledger.data, before); expect(v.passwordRequired, false);
      target = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await target.restoreBackup(backup, 'fictional result backup password');
      for (final key in ['transactions', 'imports', 'categoryRules', 'importProfiles']) { expect(target.ledger.data[key], before[key]); }
      expect(target.passwordRequired, false);
    } finally { await target?.close(); await v?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
