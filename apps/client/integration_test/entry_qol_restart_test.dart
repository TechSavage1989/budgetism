import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/transaction_editor.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('ENTRY_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('ENTRY_TEST_DIRECTORY');
  testWidgets('quick entry saves distinct exact transactions and retains them across native processes', (tester) async {
    late Directory dir; late String path; LocalVault? vault;
    const keys = SecureDeviceKeys();
    try {
      await tester.runAsync(() async {
        dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-entry-') : Directory(directory);
        path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to replace a prior workspace.');
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await vault!.apply('account', {'operationId': 'account', 'name': 'Fictional entry account',
            'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 100000});
        } else {
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        }
      });
      if (phase != 'read') {
        var completion = Completer<void>();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () => showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => LocalTransactionEditor(
            accounts: LocalLedger.rows(vault!.ledger.snapshot()['accounts']), categories: LocalLedger.rows(vault!.ledger.data['categories']),
            onSave: (input) async {
              try { await vault!.apply('transaction', input); completion.complete(); }
              catch (e, stack) { completion.completeError(e, stack); rethrow; }
            })), child: const Text('Open quick entry'))))));
        await tester.tap(find.text('Open quick entry')); await tester.pumpAndSettle();
        final unchanged = await tester.runAsync(() => vault!.storage.read());
        await tester.ensureVisible(find.byKey(const Key('entry-amount'))); await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('entry-amount')), '1.25'); await tester.pumpAndSettle();
        expect(await tester.runAsync(() => vault!.storage.read()), unchanged);
        for (final amount in ['1.25', '2.75']) {
          completion = Completer<void>();
          await tester.ensureVisible(find.byKey(const Key('entry-amount'))); await tester.pumpAndSettle();
          await tester.enterText(find.byKey(const Key('entry-amount')), amount); await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('entry-save-another')));
          await tester.runAsync(() => completion.future.timeout(const Duration(seconds: 30)));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(find.byKey(const Key('entry-amount'))).controller!.text, '');
        }
        await tester.tap(find.text('Close')); await tester.pumpAndSettle();
        await tester.runAsync(() async { await vault!.close(); vault = null; });
        if (phase == 'write') return;
        await tester.runAsync(() async { vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys); });
      }
      final records = LocalLedger.rows(vault!.ledger.data['transactions']);
      expect(records.length, 2); expect(records.map((t) => t['operationId']).toSet().length, 2);
      expect(records.map((t) => t['amountMinor']).toList(), [125, 275]);
      expect(LocalLedger.rows(vault!.ledger.snapshot()['accounts']).single['balanceMinor'], 99600);
      expect(vault!.passwordRequired, isFalse); expect(vault!.ledger.data['schema'], 3);
      await tester.runAsync(() => vault!.setPasswordRequired(true, newPassword: 'fictional entry cleanup password'));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await vault?.close();
        if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true);
      });
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
