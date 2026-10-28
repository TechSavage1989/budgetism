import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account, accounts, category, tx;
import 'category_rules_test.dart' show ruleRequest, categorizeRequest;

Future<void> seedRules(LocalVault v) async {
  await v.apply('account', account('account', 'Fictional rules', 100000));
  await v.apply('transaction', {...tx('expense', 'expense', accounts(v.ledger).first['id'], category(v.ledger, 'Expense'), 2500),
    'payee': 'Fictional Corner Shop'});
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed rule migration and category batch are atomic; unchanged retries save once', () async {
    final storage = TestStorage();
    final v = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    try {
      await seedRules(v);
      for (final action in ['category-rule', 'categorize']) {
        final input = action == 'category-rule' ? ruleRequest(v.ledger) : categorizeRequest(v.ledger);
        final before = LocalLedger.clone(v.ledger.data), encrypted = storage.saved;
        storage.failWrite = true;
        await expectLater(v.apply(action, input), throwsStateError);
        expect(v.ledger.data, before); expect(storage.saved, encrypted);
        storage.failWrite = false;
        await v.apply(action, input); final committed = storage.saved;
        await v.apply(action, input); expect(storage.saved, committed);
      }
      expect(v.ledger.data['transactions'].length, 1); expect(accounts(v.ledger).first['balanceMinor'], 97500);
      expect(storage.saved, isNot(contains('Fictional rule')));
    } finally { await v.close(); }
  });
  test('SQLite restart, stale windows and encrypted backup restoration retain rules and categories', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-rules-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    final keys = TestDeviceKeys(); LocalVault? v, stale, target;
    const password = 'fictional rules backup password';
    try {
      v = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
      await seedRules(v); await v.apply('category-rule', ruleRequest(v.ledger));
      stale = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      final input = categorizeRequest(v.ledger); await v.apply('categorize', input);
      await expectLater(stale.apply('categorize', {...input, 'operationId': 'stale'}), throwsStateError);
      await stale.close(); stale = null;
      final backup = await v.exportBackup(password: password), before = LocalLedger.clone(v.ledger.data);
      expect(backup, isNot(contains('corner')));
      await v.close(); v = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(v.ledger.data, before); expect(v.passwordRequired, isFalse);
      target = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await target.restoreBackup(backup, password);
      for (final key in ['accounts', 'transactions', 'categoryRules', 'imports', 'reconciliations']) {
        expect(target.ledger.data[key], before[key]);
      }
      expect(target.passwordRequired, isFalse);
    } finally { await target?.close(); await stale?.close(); await v?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
