import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'category_rules_storage_test.dart' show seedRules;
import 'category_rules_test.dart' show ruleRequest, categorizeRequest;
import 'category_history_test.dart' show undoRequest;

Future<void> seedHistory(LocalVault v) async {
  await seedRules(v); await v.apply('category-rule', ruleRequest(v.ledger));
  await v.apply('categorize', categorizeRequest(v.ledger));
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed undo commits neither categories nor audit; unchanged retry commits once', () async {
    final storage = TestStorage();
    final v = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    try {
      await seedHistory(v); final input = undoRequest(v.ledger);
      final original = LocalLedger.clone(v.ledger.data), encrypted = storage.saved;
      storage.failWrite = true; await expectLater(v.apply('category-undo', input), throwsStateError);
      expect(v.ledger.data, original); expect(storage.saved, encrypted);
      storage.failWrite = false; await v.apply('category-undo', input); final committed = storage.saved;
      await v.apply('category-undo', input); expect(storage.saved, committed);
      expect(CategoryHistory.batches(v.ledger.data).single['undone'], true);
      expect(storage.saved, isNot(contains('Correct a fictional')));
    } finally { await v.close(); }
  });
  test('SQLite reopen, stale writers and independent encrypted restore preserve history and undo state', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-history-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys(); LocalVault? v, stale, target;
    const password = 'fictional undo backup password';
    try {
      v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await seedHistory(v); stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      final input = undoRequest(v.ledger); await v.apply('category-undo', input);
      await expectLater(stale.apply('category-undo', {...input, 'operationId': 'stale'}), throwsStateError);
      await stale.close(); stale = null;
      final before = LocalLedger.clone(v.ledger.data), backup = await v.exportBackup(password: password);
      expect(backup, isNot(contains('Correct a fictional')));
      await v.close(); v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(v.ledger.data, before); expect(v.passwordRequired, false);
      final encoded = await v.storage.read(); CategoryHistory.preview(v.ledger.data, 'categorize');
      expect(await v.storage.read(), encoded);
      target = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await target.restoreBackup(backup, password);
      for (final key in ['transactions', 'categoryRules', 'accounts', 'imports', 'reconciliations']) {
        expect(target.ledger.data[key], before[key]);
      }
      expect(CategoryHistory.batches(target.ledger.data).single['undone'], true);
      await expectLater(target.apply('category-undo', undoRequest(target.ledger, operation: 'undo-after-restore')), throwsFormatException);
      expect(target.passwordRequired, false);
    } finally { await target?.close(); await stale?.close(); await v?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
