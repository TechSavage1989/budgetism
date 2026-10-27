import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';
import 'local_ledger_test.dart' show account;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'test-only long local passphrase';
  test('encrypted disk reopen, wrong password, tamper, backup restore and stale writer', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-test-');
    final path = '${dir.path}${Platform.pathSeparator}workspace.sqlite3';
    LocalVault? current;
    LocalVault? second;
    try {
      current = await LocalVault.open(SqliteVaultStorage(path), password, create: true);
      await current.apply('account', account('create', 'Sensitive test account', 12345));
      final backup = await current.exportBackup();
      expect(backup, isNot(contains('Sensitive test account')));
      expect(utf8.decode(File(path).readAsBytesSync(), allowMalformed: true), isNot(contains('Sensitive test account')));
      await current.close(); current = null;
      final wrongStore = SqliteVaultStorage(path);
      await expectLater(LocalVault.open(wrongStore, 'wrong test password', create: false), throwsFormatException);
      await wrongStore.close();
      current = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
      expect(LocalLedger.rows(current.ledger.snapshot()['accounts']).single['balanceMinor'], 12345);
      second = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
      await current.apply('account', account('another', 'Second account', 100));
      await expectLater(second.apply('account', account('stale', 'Stale writer', 1)), throwsStateError);
      expect(LocalLedger.rows(second.ledger.snapshot()['accounts']).length, 1);
      await second.refresh();
      expect(LocalLedger.rows(second.ledger.snapshot()['accounts']).length, 2);
      final modified = Map<String, dynamic>.from(jsonDecode(backup) as Map);
      final cipher = base64Decode(modified['data'] as String); cipher[0] ^= 1;
      modified['data'] = base64Encode(cipher);
      await expectLater(current.restoreBackup(jsonEncode(modified), password), throwsFormatException);
      expect(LocalLedger.rows(current.ledger.snapshot()['accounts']).length, 2);
      await current.restoreBackup(backup, password);
      expect(LocalLedger.rows(current.ledger.snapshot()['accounts']).length, 1);
      expect(current.ledger.revision, 3);
      await current.close(); current = null;
      current = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
      expect(LocalLedger.rows(current.ledger.snapshot()['accounts']).single['name'], 'Sensitive test account');
    } finally {
      await current?.close(); await second?.close();
      dir.deleteSync(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('unknown database schema is never reset', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-schema-');
    try {
      final path = '${dir.path}${Platform.pathSeparator}not-a-workspace.sqlite3';
      File(path).writeAsStringSync('not a database');
      expect(() => SqliteVaultStorage(path), throwsA(anything));
      expect(File(path).readAsStringSync(), 'not a database');
    } finally { dir.deleteSync(recursive: true); }
  });
}
