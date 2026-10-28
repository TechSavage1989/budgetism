import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

/// Run write/read in separate native app processes to verify the actual OS key
/// store across process exit, not a mocked MethodChannel or in-memory key map.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('SECURITY_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('SECURITY_TEST_DIRECTORY');
  testWidgets('native budgets and device key survive process exit and password mode changes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: Text('Budgetism security validation')))));
    await tester.runAsync(() async {
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-native-security-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}native-security-test.sqlite3';
      const keys = SecureDeviceKeys();
      LocalVault? vault;
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to overwrite a prior test workspace.');
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await vault.apply('account', {'operationId': 'native-fixture', 'name': 'Fictional native account',
            'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 12345});
          final cat = LocalLedger.rows(vault.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Expense')['id'];
          final accountId = LocalLedger.rows(vault.ledger.data['accounts']).single['id'];
          await vault.apply('budget', {'operationId': 'native-budget', 'month': '2026-10',
            'categoryId': cat, 'amountMinor': 6000, 'rollover': 'all', 'expectedVersion': 0});
          await vault.apply('transaction', {'operationId': 'native-spending', 'kind': 'expense',
            'accountId': accountId, 'counterpartyAccountId': cat, 'amountMinor': 2345,
            'currency': 'USD', 'effectiveDate': '2026-10-27', 'payee': 'Fictional budget test', 'notes': ''});
          await vault.close(); vault = null;
        }
        if (phase == 'write') return;
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(vault.passwordRequired, isFalse);
        expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 10000);
        final budget = BudgetEngine.calculate(vault.ledger.snapshot(), '2026-10');
        expect([budget.allocated, budget.spent, budget.remaining], [6000, 2345, 3655]);
        expect(BudgetEngine.calculate(vault.ledger.snapshot(), '2026-11').carried, 3655);
        const password = 'native-test password only';
        await vault.setPasswordRequired(true, newPassword: password);
        await vault.close(); vault = null;
        final wrong = SqliteVaultStorage(path);
        await expectLater(LocalVault.open(wrong, '', create: false, deviceKeys: keys), throwsFormatException);
        await wrong.close();
        vault = await LocalVault.open(SqliteVaultStorage(path), password, create: false, deviceKeys: keys);
        await vault.setPasswordRequired(false, currentPassword: password);
        await vault.close(); vault = null;
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 10000);
        expect(BudgetEngine.calculate(vault.ledger.snapshot(), '2026-10').remaining, 3655);
        // Finish in password mode so this test deletes its OS credential.
        await vault.setPasswordRequired(true, newPassword: password);
      } finally {
        await vault?.close();
        if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
