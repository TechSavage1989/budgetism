import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/budgets.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/schedules.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('SCHEDULE_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('SCHEDULE_TEST_DIRECTORY');
  testWidgets('scheduled confirmations, postponements and skips survive separate native processes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: Text('Budgetism scheduled activity validation')))));
    await tester.runAsync(() async {
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-native-schedules-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}scheduled-test.sqlite3';
      const keys = SecureDeviceKeys();
      LocalVault? vault;
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to overwrite a prior test workspace.');
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await vault.apply('account', {'operationId': 'account', 'name': 'Fictional schedule test account',
            'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 10000});
          final a = LocalLedger.rows(vault.ledger.data['accounts']).single['id'];
          final c = LocalLedger.rows(vault.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Expense')['id'];
          await vault.apply('budget', {'operationId': 'budget', 'categoryId': c, 'month': '2026-01',
            'amountMinor': 10000, 'rollover': 'all', 'expectedVersion': 0});
          await vault.apply('schedule', {'operationId': 'schedule', 'expectedVersion': 0, 'name': 'Fictional weekly bill',
            'kind': 'expense', 'accountId': a, 'counterpartyAccountId': c, 'currency': 'USD', 'amountMinor': 2000,
            'payee': 'Fictional', 'notes': '', 'startDate': '2026-01-31', 'frequency': 'weekly', 'endDate': null});
          expect(BudgetEngine.calculate(vault.ledger.snapshot(), '2026-01').spent, 0);
          final s = LocalLedger.rows(vault.ledger.data['schedules']).single['id'];
          final base = <String, dynamic>{'scheduleId': s, 'expectedScheduleVersion': 1, 'expectedOccurrenceVersion': 0};
          await vault.apply('schedule-confirm', {...base, 'operationId': 'confirm', 'index': 0,
            'amountMinor': 2500, 'effectiveDate': '2026-01-31'});
          await vault.apply('schedule-postpone', {...base, 'operationId': 'postpone', 'index': 1, 'dueDate': '2026-02-09'});
          await vault.apply('schedule-skip', {...base, 'operationId': 'skip', 'index': 2});
          await vault.close(); vault = null;
        }
        if (phase == 'write') return;
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(vault.passwordRequired, isFalse);
        expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 7500);
        expect(LocalLedger.rows(vault.ledger.data['transactions']).length, 1);
        expect(BudgetEngine.calculate(vault.ledger.snapshot(), '2026-01').remaining, 7500);
        final upcoming = ScheduleEngine.upcoming(vault.ledger.snapshot(), today: '2026-02-01');
        expect(upcoming.items.first.dueDate, '2026-02-09');
        expect(upcoming.items.any((o) => o.index == 0 || o.index == 2), isFalse);
        final id = LocalLedger.rows(vault.ledger.data['schedules']).single['id'];
        await expectLater(vault.apply('schedule-confirm', {'operationId': 'duplicate-after-restart', 'scheduleId': id,
          'index': 0, 'expectedScheduleVersion': 1, 'expectedOccurrenceVersion': 1,
          'amountMinor': 2500, 'effectiveDate': '2026-01-31'}), throwsFormatException);
        // Delete this test's OS credential through the normal security conversion.
        await vault.setPasswordRequired(true, newPassword: 'fictional native schedule password');
      } finally {
        await vault?.close();
        if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
