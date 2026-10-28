import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/device_keys.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/planning.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('MATCH_TEST_PHASE', defaultValue: 'single');
  const directory = String.fromEnvironment('MATCH_TEST_DIRECTORY');
  testWidgets('matched imported payment survives native process exit without duplicate posting', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Budgetism matching validation'))));
    await tester.runAsync(() async {
      final dir = directory.isEmpty ? Directory.systemTemp.createTempSync('budgetism-native-match-') : Directory(directory);
      final path = '${dir.path}${Platform.pathSeparator}matching-test.sqlite3';
      const keys = SecureDeviceKeys(); LocalVault? vault;
      Json request(LocalLedger ledger, String operation) {
        final schedule = LocalLedger.rows(ledger.data['schedules']).single;
        final transaction = LocalLedger.rows(ledger.data['transactions']).single;
        final occurrences = LocalLedger.rows(ledger.data['occurrences']);
        return {'operationId': operation, 'scheduleId': schedule['id'], 'index': 0,
          'expectedScheduleVersion': schedule['version'], 'expectedOccurrenceVersion': occurrences.isEmpty ? 0 : occurrences.single['version'],
          'expectedRevision': ledger.revision, 'transactionId': transaction['id'],
          'expectedTransactionVersion': transaction['version'], 'confirmMatch': true};
      }
      try {
        if (phase != 'read') {
          await dir.create(recursive: true);
          if (File(path).existsSync()) throw StateError('Refusing to overwrite an existing test workspace.');
          vault = await LocalVault.open(SqliteVaultStorage(path), '', create: true, requirePassword: false, deviceKeys: keys);
          await vault.apply('account', {'operationId': 'account', 'name': 'Fictional native match', 'type': 'checking',
            'currency': 'USD', 'openingBalanceMinor': 100000});
          final account = LocalLedger.rows(vault.ledger.data['accounts']).single['id'];
          final category = LocalLedger.rows(vault.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Expense')['id'];
          await vault.apply('schedule', {'operationId': 'schedule', 'expectedVersion': 0, 'name': 'Fictional bill',
            'kind': 'expense', 'accountId': account, 'counterpartyAccountId': category, 'amountMinor': 2000, 'currency': 'USD',
            'payee': 'Fictional shop', 'notes': '', 'startDate': '2026-10-28', 'frequency': 'monthly', 'endDate': null});
          await vault.apply('import-csv', {'operationId': 'import', 'expectedRevision': vault.ledger.revision,
            'accountId': account, 'fileHash': List.filled(64, 'b').join(), 'fileName': 'fictional-match.csv',
            'confirmImportUpgrade': true, 'rows': [{'rowNumber': 2, 'date': '2026-10-28', 'signedMinor': -2000,
              'payee': 'Fictional shop', 'reference': 'fictional-native-id', 'notes': '', 'action': 'create',
              'kind': 'expense', 'targetId': category}]});
          await vault.apply('schedule-match', request(vault.ledger, 'match'));
          await vault.close(); vault = null;
        }
        if (phase == 'write') return;
        vault = await LocalVault.open(SqliteVaultStorage(path), '', create: false, deviceKeys: keys);
        expect(vault.passwordRequired, isFalse);
        expect(vault.ledger.data['schema'], 4);
        final account = LocalLedger.rows(vault.ledger.snapshot()['accounts']).single;
        expect(account['balanceMinor'], 98000);
        expect(vault.ledger.data['transactions'].length, 1); expect(vault.ledger.data['imports'].length, 1);
        expect(vault.ledger.data['occurrences'].length, 1);
        final forecast = PlanningEngine.forecast(vault.ledger.snapshot(), today: '2026-10-27', days: 2);
        expect(forecast.days.firstWhere((d) => d.date == '2026-10-28').projected[account['id']], 98000);
        final saved = await vault.storage.read();
        await expectLater(vault.apply('schedule-match', request(vault.ledger, 'repeat-after-restart')), throwsFormatException);
        expect(await vault.storage.read(), saved);
        await vault.setPasswordRequired(true, newPassword: 'fictional matching cleanup only');
      } finally {
        await vault?.close(); if (phase != 'write' && dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
