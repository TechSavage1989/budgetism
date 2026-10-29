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
  testWidgets('native calendar selection writes only after explicit save and survives vault reopening', (tester) async {
    late Directory dir;
    late String path;
    LocalVault? vault;
    const keys = SecureDeviceKeys();
    try {
      await tester.runAsync(() async {
        dir = Directory.systemTemp.createTempSync('budgetism-date-ui-');
        path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
        await vault!.apply('account', {'operationId': 'account', 'name': 'Fictional calendar account',
          'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 100000});
        final account = LocalLedger.rows(vault!.ledger.data['accounts']).single['id'];
        final category = LocalLedger.rows(vault!.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Expense')['id'];
        await vault!.apply('transaction', {'operationId': 'expense', 'kind': 'expense', 'accountId': account,
          'counterpartyAccountId': category, 'amountMinor': 1234, 'currency': 'USD',
          'effectiveDate': '2026-10-10', 'payee': 'Fictional calendar test', 'notes': '', 'splits': <Json>[]});
      });
      final before = LocalLedger.clone(vault!.ledger.data);
      final encrypted = await tester.runAsync(() => vault!.storage.read());
      final completion = Completer<void>();
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showDialog<bool>(context: context, builder: (_) => LocalTransactionEditor(
          accounts: LocalLedger.rows(vault!.ledger.snapshot()['accounts']),
          categories: LocalLedger.rows(vault!.ledger.data['categories']),
          existing: LocalLedger.rows(vault!.ledger.data['transactions']).single,
          onSave: (input) async {
            try { await vault!.apply('transaction', input); completion.complete(); }
            catch (e, stack) { completion.completeError(e, stack); rethrow; }
          })), child: const Text('Open fictional transaction'))))));
      await tester.tap(find.text('Open fictional transaction')); await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('2026-10-10'));
      await tester.tap(find.text('2026-10-10')); await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(CalendarDatePicker), matching: find.text('15')).last);
      await tester.pumpAndSettle(); await tester.tap(find.text('Use date')); await tester.pumpAndSettle();
      expect(vault!.ledger.data, before);
      expect(await tester.runAsync(() => vault!.storage.read()), encrypted);
      await tester.tap(find.text('Save transaction'));
      await tester.runAsync(() => completion.future.timeout(const Duration(seconds: 30)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await vault!.close(); vault = null;
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        final transaction = LocalLedger.rows(vault!.ledger.data['transactions']).single;
        expect(transaction['effectiveDate'], '2026-10-15'); expect(transaction['amountMinor'], 1234);
        expect(LocalLedger.rows(vault!.ledger.snapshot()['accounts']).single['balanceMinor'], 98766);
        expect(vault!.ledger.data['schema'], before['schema']); expect(vault!.passwordRequired, isFalse);
        await vault!.setPasswordRequired(true, newPassword: 'fictional date control cleanup');
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async { await vault?.close(); if (dir.existsSync()) dir.deleteSync(recursive: true); });
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
