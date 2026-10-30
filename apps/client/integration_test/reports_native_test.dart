import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/reports.dart';
import 'package:budgetism/local/report_widgets.dart';
import 'package:budgetism/local/storage_native.dart';
import 'package:budgetism/local/vault.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native configurable graphs preserve encrypted payload and exact selected values', (tester) async {
    final capture = GlobalKey();
    final dir = Directory.systemTemp.createTempSync('budgetism-graphs-');
    final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
    LocalVault? vault;
    Object? encoded;
    var original = '';
    var revision = 0;
    try {
      await tester.runAsync(() async {
        vault = await LocalVault.open(SqliteVaultStorage(path), 'fictional graph test only', create: true);
        await vault!.apply('account', {'operationId': 'graph-account', 'name': 'Fictional graph checking',
          'type': 'checking', 'currency': 'USD', 'openingBalanceMinor': 100000});
        final account = LocalLedger.rows(vault!.ledger.data['accounts']).single['id'];
        final category = LocalLedger.rows(vault!.ledger.data['categories']).firstWhere((c) => c['kind'] == 'Income')['id'];
        await vault!.apply('transaction', {'operationId': 'graph-income', 'kind': 'income', 'accountId': account,
          'counterpartyAccountId': category, 'currency': 'USD', 'amountMinor': 12345,
          'effectiveDate': '2026-10-27', 'payee': 'Fictional graph income', 'notes': ''});
        encoded = await vault!.storage.read(); original = jsonEncode(vault!.ledger.data); revision = vault!.ledger.revision;
      });
      await tester.pumpWidget(RepaintBoundary(key: capture, child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(16), child: ReportPanel(
          readSnapshot: () => vault!.ledger.snapshot(includeVoided: true), today: '2026-10-28')))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-view-Graphs'))); await tester.pumpAndSettle();
      expect(find.text('Income: \$123.45'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('report-chart-bars')));
      await tester.tap(find.byKey(const ValueKey('report-chart-bars'))); await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-chart-table'))); await tester.pumpAndSettle();
      expect(find.text('Exact monthly values (same selected accounts and dates)'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('report-chart-metric')));
      await tester.tap(find.byKey(const ValueKey('report-chart-metric'))); await tester.pumpAndSettle();
      await tester.tap(find.text('Recorded net balance').last); await tester.pumpAndSettle();
      expect(find.text('Recorded net balance: \$1,123.45'), findsWidgets);
      final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await tester.runAsync(() => File('build/report-graphs-dev25-native.png').writeAsBytes(bytes!.buffer.asUint8List()));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        expect(await vault!.storage.read(), encoded); expect(jsonEncode(vault!.ledger.data), original);
        expect(vault!.ledger.revision, revision);
      });
    } finally {
      await tester.runAsync(() async { await vault?.close(); dir.deleteSync(recursive: true); });
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
  testWidgets('native reports and CSV saving preserve encrypted data and statement locks after reopen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Fictional reporting test'))));
    await tester.runAsync(() async {
      final dir = Directory.systemTemp.createTempSync('budgetism-reports-');
      final path = '${dir.path}${Platform.pathSeparator}fictional.sqlite3';
      const password = 'fictional report test only'; LocalVault? v;
      try {
        v = await LocalVault.open(SqliteVaultStorage(path), password, create: true);
        await v.apply('account', {'operationId': 'account', 'name': 'Fictional checking', 'type': 'checking',
          'currency': 'USD', 'openingBalanceMinor': 100000});
        final account = LocalLedger.rows(v.ledger.data['accounts']).single['id'];
        final cats = LocalLedger.rows(v.ledger.data['categories']);
        for (final kind in ['income', 'expense']) {
          await v.apply('transaction', {'operationId': kind, 'kind': kind, 'accountId': account,
            'counterpartyAccountId': cats.firstWhere((c) => c['kind'] == (kind == 'income' ? 'Income' : 'Expense'))['id'],
            'currency': 'USD', 'amountMinor': kind == 'income' ? 50000 : 20000,
            'effectiveDate': '2026-10-27', 'payee': 'Fictional $kind', 'notes': ''});
        }
        await v.apply('reconcile', {'operationId': 'statement', 'expectedRevision': v.ledger.revision,
          'accountId': account, 'endDate': '2026-10-28', 'closingMinor': 130000,
          'transactionIds': LocalLedger.rows(v.ledger.data['transactions']).map((t) => t['id']).toList(),
          'confirmReviewed': true, 'confirmReconciliationUpgrade': true});
        final encoded = await v.storage.read(), original = jsonEncode(v.ledger.data), revision = v.ledger.revision;
        FinanceReport read() => ReportEngine.calculate(v!.ledger.snapshot(includeVoided: true),
          from: '2026-10-01', through: '2026-10-28', today: '2026-10-28');
        final report = read();
        expect(report.income, 50000); expect(report.expense, 20000); expect(report.closing, 130000);
        for (final type in ReportExport.values) {
          final content = ReportCsv.encode(report, type);
          final target = '${dir.path}${Platform.pathSeparator}${type.name}.csv';
          await XFile.fromData(Uint8List.fromList(utf8.encode(content)), mimeType: 'text/csv').saveTo(target);
          expect(await File(target).readAsBytes(), utf8.encode(content));
        }
        expect(await v.storage.read(), encoded); expect(jsonEncode(v.ledger.data), original);
        expect(v.ledger.revision, revision);
        await v.close(); v = null;
        v = await LocalVault.open(SqliteVaultStorage(path), password, create: false);
        expect(read().closing, report.closing); expect(read().income, report.income); expect(v.passwordRequired, isTrue);
        expect(await v.storage.read(), encoded); expect(v.ledger.revision, revision);
        final t = LocalLedger.rows(v.ledger.data['transactions']).first;
        expect(Reconciliation.locked(v.ledger.data, t['id']), isTrue);
        await expectLater(v.apply('void', {'operationId': 'blocked', 'id': t['id'], 'expectedVersion': t['version']}), throwsFormatException);
        expect(await v.storage.read(), encoded);
      } finally { await v?.close(); dir.deleteSync(recursive: true); }
    });
  }, timeout: const Timeout(Duration(minutes: 6)));
}
