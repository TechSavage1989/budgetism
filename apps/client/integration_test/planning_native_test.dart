import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/planning.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native forecast leaves encrypted bytes intact and reproduces results after reopen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Budgetism forecast validation'))));
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('budgetism-planning-');
      final path = '${dir.path}${Platform.pathSeparator}test.sqlite3';
      const password = 'fictional planning test password';
      LocalVault? vault;
      try {
        vault = await LocalVault.open(SqliteVaultStorage(path), password, create: true);
        await vault.apply('account', {'operationId': 'account', 'name': 'Fictional forecast account',
          'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 100000});
        final a = LocalLedger.rows(vault.ledger.data['accounts']).single['id'];
        final cats = LocalLedger.rows(vault.ledger.data['categories']);
        for (final kind in ['income', 'expense']) {
          await vault.apply('schedule', {'operationId': kind, 'expectedVersion': 0, 'name': 'Fictional $kind',
            'kind': kind, 'accountId': a, 'counterpartyAccountId': cats.firstWhere((c) => c['kind'] == (kind == 'income' ? 'Income' : 'Expense'))['id'],
            'currency': 'USD', 'amountMinor': kind == 'income' ? 50000 : 20000, 'payee': '', 'notes': '',
            'startDate': kind == 'income' ? '2026-10-29' : '2026-10-30', 'frequency': 'monthly', 'endDate': null});
        }
        final before = await vault.storage.read();
        final original = jsonEncode(vault.ledger.data);
        final forecast = PlanningEngine.forecast(vault.ledger.snapshot(), today: '2026-10-28', days: 3);
        expect(forecast.days.map((d) => d.projected[a]), [100000, 150000, 130000]);
        PlanningEngine.calendar(vault.ledger.snapshot(), from: '2026-10-01', through: '2026-10-31', today: '2026-10-28');
        expect(await vault.storage.read(), before); expect(jsonEncode(vault.ledger.data), original);
        await vault.close(); vault = null;
        vault = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
        expect(PlanningEngine.forecast(vault.ledger.snapshot(), today: '2026-10-28', days: 3).days.last.projected[a], 130000);
        expect(await vault.storage.read(), before); expect(vault.passwordRequired, isTrue);
      } finally { await vault?.close(); dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
