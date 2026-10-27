import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/security_dialogs.dart';
import 'package:budgetism/local/workspace_dialogs.dart';
import 'package:budgetism/local/ledger.dart';
import 'local_ledger_test.dart' show account;

class TestDeviceKeys implements DeviceKeyStore {
  final values = <String, String>{};
  bool failWrite = false;
  bool failDelete = false;
  bool badRead = false;
  @override
  Future<String?> read(String name) async => badRead ? null : values[name];
  @override
  Future<void> write(String name, String value) async {
    if (failWrite) throw StateError('OS store unavailable');
    values[name] = value;
  }
  @override
  Future<void> delete(String name) async {
    if (failDelete) throw StateError('OS store cleanup unavailable');
    values.remove(name);
  }
}
class TestStorage implements VaultStorage {
  String? saved;
  bool failWrite = false;
  @override
  String get location => 'test-memory-only';
  @override
  Future<String?> read() async => saved;
  @override
  Future<void> close() async {}
  @override
  Future<void> write(String value, {required int expectedRevision}) async {
    if (failWrite) throw StateError('Disk unavailable');
    final revision = saved == null ? -1 : LocalVault.header(saved!)['revision'];
    if (revision != expectedRevision) throw StateError('Concurrent write');
    saved = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const oldPassword = 'legacy testing password only';
  const newPassword = 'new testing password only';
  const backupPassword = 'portable backup testing only';

  test('legacy workspace stays protected; explicit off/on preserves data and rejects stale windows', () async {
    final dir = Directory.systemTemp.createTempSync('budgetism-security-');
    final path = '${dir.path}${Platform.pathSeparator}workspace.sqlite3';
    final keys = TestDeviceKeys();
    final seed = SqliteVaultStorage(path);
    final fixture = File('test/fixtures/legacy_password_v1.json').readAsStringSync();
    await seed.write(fixture, expectedRevision: -1);
    await seed.close();
    LocalVault? vault;
    LocalVault? stale;
    try {
      vault = await LocalVault.open(SqliteVaultStorage(path), oldPassword, create: false, deviceKeys: keys);
      expect(vault.passwordRequired, isTrue);
      expect(await vault.storage.read(), fixture); // No automatic conversion.
      stale = await LocalVault.open(SqliteVaultStorage(path), oldPassword, create: false, deviceKeys: keys);
      await expectLater(vault.setPasswordRequired(false, currentPassword: 'incorrect'), throwsFormatException);
      expect(await vault.storage.read(), fixture);
      expect(keys.values, isEmpty);
      await vault.setPasswordRequired(false, currentPassword: oldPassword);
      expect(vault.passwordRequired, isFalse);
      expect(keys.values.length, 1);
      expect(jsonEncode(vault.ledger.data), isNot(contains(oldPassword)));
      await expectLater(stale.refresh(), throwsStateError);
      await expectLater(stale.apply('account', account('stale', 'Must not be saved', 1)), throwsStateError);
      await stale.close(); stale = null;
      await vault.close(); vault = null;
      vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
      expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 10000);
      final before = await vault.storage.read();
      await expectLater(vault.setPasswordRequired(true, newPassword: 'short'), throwsFormatException);
      expect(await vault.storage.read(), before);
      await vault.setPasswordRequired(true, newPassword: newPassword);
      expect(keys.values, isEmpty);
      await vault.close(); vault = null;
      final bad = SqliteVaultStorage(path);
      await expectLater(LocalVault.open(bad, '', create: false, deviceKeys: keys), throwsFormatException);
      await bad.close();
      vault = await LocalVault.open(SqliteVaultStorage(path), newPassword, create: false, deviceKeys: keys);
      expect(vault.passwordRequired, isTrue);
      expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 10000);
      expect(vault.ledger.revision, 2);
    } finally { await vault?.close(); await stale?.close(); dir.deleteSync(recursive: true); }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('password-free creation persists ciphertext, reopens and exports a portable protected backup', () async {
    final store = TestStorage(); final keys = TestDeviceKeys();
    var vault = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: keys);
    await vault.apply('account', account('a', 'Private test account', 12345));
    expect(store.saved, isNot(contains('Private test account')));
    expect(LocalVault.header(store.saved!)['unlock'], 'device');
    await expectLater(vault.exportBackup(), throwsStateError);
    final backup = await vault.exportBackup(password: backupPassword);
    expect(LocalVault.header(backup)['version'], 1);
    expect(backup, isNot(contains('Private test account')));
    expect(backup, isNot(contains(keys.values.values.single)));
    await vault.close();
    vault = await LocalVault.open(store, '', create: false, deviceKeys: keys);
    expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 12345);
    final target = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    await expectLater(target.restoreBackup(backup, 'wrong'), throwsFormatException);
    expect(LocalLedger.rows(target.ledger.snapshot()['accounts']), isEmpty);
    await target.restoreBackup(backup, backupPassword);
    expect(target.passwordRequired, isFalse);
    expect(LocalLedger.rows(target.ledger.snapshot()['accounts']).single['balanceMinor'], 12345);
    await target.close(); await vault.close();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('missing key, tampered mode and failed key writes never reset or downgrade data', () async {
    final store = TestStorage(); final keys = TestDeviceKeys();
    var vault = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: keys);
    final saved = store.saved;
    await vault.close();
    await expectLater(LocalVault.open(store, '', create: false, deviceKeys: TestDeviceKeys()), throwsStateError);
    expect(store.saved, saved);
    final changed = LocalVault.header(saved!);
    changed['unlock'] = 'password'; changed['kdf'] = 'PBKDF2-SHA256'; changed['iterations'] = vaultIterations;
    store.saved = jsonEncode(changed);
    await expectLater(LocalVault.open(store, newPassword, create: false, deviceKeys: keys), throwsFormatException);
    store.saved = saved;
    vault = await LocalVault.open(store, '', create: false, deviceKeys: keys);
    await vault.close();
    final empty = TestStorage();
    final fail = TestDeviceKeys()..failWrite = true;
    await expectLater(LocalVault.open(empty, '', create: true, requirePassword: false, deviceKeys: fail), throwsStateError);
    expect(empty.saved, isNull);
    final unverified = TestDeviceKeys()..badRead = true;
    await expectLater(LocalVault.open(empty, '', create: true, requirePassword: false, deviceKeys: unverified), throwsStateError);
    expect(empty.saved, isNull);
    expect(unverified.values, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('failed disk commit leaves the original password and data usable', () async {
    final store = TestStorage(); final keys = TestDeviceKeys();
    store.saved = File('test/fixtures/legacy_password_v1.json').readAsStringSync();
    var vault = await LocalVault.open(store, oldPassword, create: false, deviceKeys: keys);
    final before = store.saved;
    store.failWrite = true;
    await expectLater(vault.setPasswordRequired(false, currentPassword: oldPassword), throwsStateError);
    expect(vault.passwordRequired, isTrue); expect(store.saved, before); expect(keys.values, isEmpty);
    store.failWrite = false;
    await vault.close();
    vault = await LocalVault.open(store, oldPassword, create: false, deviceKeys: keys);
    expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['name'], 'Legacy checking');
    await vault.close();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('failed obsolete-key cleanup reports a warning after a successful mode change', () async {
    final store = TestStorage(); final keys = TestDeviceKeys();
    var vault = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: keys);
    keys.failDelete = true;
    expect(await vault.setPasswordRequired(true, newPassword: newPassword), contains('obsolete device credential'));
    expect(vault.passwordRequired, isTrue);
    await vault.close();
    vault = await LocalVault.open(store, newPassword, create: false, deviceKeys: keys);
    expect(vault.passwordRequired, isTrue);
    await vault.close();
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('new local workspace defaults to no password; password fields are optional', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LocalWorkspaceAccessDialog(
      storage: TestStorage(), creating: true, deviceKeys: TestDeviceKeys())));
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byType(SwitchListTile)); await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.byType(SwitchListTile)); await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('security dialog refuses mismatched new passwords without changing mode', (tester) async {
    final vault = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    await tester.pumpWidget(MaterialApp(home: WorkspaceSecurityDialog(vault: vault)));
    await tester.tap(find.byType(SwitchListTile)); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, newPassword);
    await tester.enterText(find.byType(TextField).last, 'different testing password');
    await tester.tap(find.text('Save')); await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(vault.passwordRequired, isFalse);
    await tester.pumpWidget(const SizedBox.shrink()); await vault.close();
  });
}
