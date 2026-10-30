import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/planning_widgets.dart';
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
  testWidgets('native custom scenario apply cancel reset never writes encrypted workspace', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    late Directory dir;
    late LocalVault vault;
    late Object? before;
    late String original;
    await tester.runAsync(() async {
      dir = Directory.systemTemp.createTempSync('budgetism-forecast-controls-');
      vault = await LocalVault.open(SqliteVaultStorage('${dir.path}${Platform.pathSeparator}test.sqlite3'),
        'fictional scenario password', create: true);
      await vault.apply('account', {'operationId': 'account', 'name': 'Fictional scenario cash',
        'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 100000});
      final a = LocalLedger.rows(vault.ledger.data['accounts']).single['id'];
      final category = LocalLedger.rows(vault.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Expense')['id'];
      await vault.apply('schedule', {'operationId': 'bill', 'expectedVersion': 0,
        'name': 'Fictional scenario bill', 'kind': 'expense', 'accountId': a, 'counterpartyAccountId': category,
        'currency': 'USD', 'amountMinor': 120001, 'payee': '', 'notes': '',
        'startDate': '2026-10-28', 'frequency': 'monthly', 'endDate': null});
      before = await vault.storage.read(); original = jsonEncode(vault.ledger.data);
    });
    try {
      await tester.pumpWidget(MaterialApp(home: RepaintBoundary(key: capture, child: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(16), child: PlanningPanel(api: LocalFinanceApi(vault), calendar: false,
          today: '2026-10-28', onOpenTransaction: (_) async {}, onOpenScheduled: () {})))))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('configure-forecast')));
      await tester.tap(find.byKey(const ValueKey('configure-forecast'))); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), '1');
      await tester.tap(find.byKey(const ValueKey('forecast-exclude-all')));
      await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:30')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('configure-forecast'))); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), '1');
      await tester.tap(find.byKey(const ValueKey('forecast-exclude-all')));
      await tester.tap(find.byKey(const ValueKey('apply-forecast-configuration'))); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:1')), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('What-if scenario: 1 schedule(s) excluded.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('configure-forecast')));
      await tester.tap(find.byKey(const ValueKey('configure-forecast'))); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), '45');
      await tester.tap(find.byKey(const ValueKey('apply-forecast-configuration'))); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:45')), findsOneWidget);
      final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await tester.runAsync(() => File('build/forecast-scenario-dev25-native.png')
        .writeAsBytes(bytes!.buffer.asUint8List()));
      await tester.ensureVisible(find.byKey(const ValueKey('reset-forecast')));
      await tester.tap(find.byKey(const ValueKey('reset-forecast'))); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:30')), findsOneWidget);
      expect(find.text('Baseline: all active unresolved schedules. No what-if exclusions.'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await vault.storage.read(), before);
        expect(jsonEncode(vault.ledger.data), original);
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async { await vault.close(); dir.deleteSync(recursive: true); });
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

}
