import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/report_widgets.dart';
import 'local_ledger_test.dart' show accounts;
import 'reports_test.dart' show reportFixture;

Widget screen(LocalLedger ledger, {ReportSaver? save}) => MaterialApp(home: Scaffold(body:
  SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: ReportPanel(
    readSnapshot: () => ledger.snapshot(includeVoided: true), today: '2026-10-28', saveCsv: save)))));

void main() {
  for (final width in [430.0, 1100.0]) {
    testWidgets('all report views and category detail fit $width pixels without changing records', (tester) async {
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final ledger = reportFixture();
      final original = jsonEncode(ledger.data);
      await tester.pumpWidget(screen(ledger)); await tester.pumpAndSettle();
      expect(find.text('Financial reports'), findsOneWidget);
      expect(find.text('\$500.00'), findsOneWidget); expect(find.text('\$230.00'), findsOneWidget);
      for (final view in ['Categories', 'Monthly', 'Balances', 'Overview']) {
        final target = find.byKey(ValueKey('report-view-$view'));
        await tester.ensureVisible(target); await tester.tap(target); await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('report-view-Categories'))); await tester.pumpAndSettle();
      final cat = LocalLedger.rows(ledger.data['categories']).firstWhere((c) => c['name'] == 'Housing');
      final row = find.byKey(ValueKey('report-category-${cat['id']}'));
      await tester.ensureVisible(row); await tester.tap(row); await tester.pumpAndSettle();
      expect(find.text('Category contribution: \$140.00'), findsOneWidget);
      expect(find.text('Whole transaction: \$200.00'), findsOneWidget);
      await tester.tap(find.text('Close')); await tester.pumpAndSettle();
      expect(jsonEncode(ledger.data), original); expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('account selection and date presets change only the report', (tester) async {
    final ledger = reportFixture(); final original = jsonEncode(ledger.data);
    await tester.pumpWidget(screen(ledger)); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-accounts'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Clear selection')); await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply accounts')).onPressed, isNull);
    await tester.tap(find.text(accounts(ledger).first['name'] as String)); await tester.pumpAndSettle();
    await tester.tap(find.text('Apply accounts')); await tester.pumpAndSettle();
    expect(find.text('\$200.00'), findsOneWidget); expect(find.text('\$300.00'), findsOneWidget);
    await tester.tap(find.text('Last month')); await tester.pumpAndSettle();
    expect(find.text('No income or expenses in this selection.'), findsOneWidget);
    expect(jsonEncode(ledger.data), original); expect(tester.takeException(), isNull);
  });
  testWidgets('CSV export needs consent, handles cancellation and failure, and retries without financial writes', (tester) async {
    final ledger = reportFixture();
    final savedLedger = jsonEncode(ledger.data); var calls = 0; var mode = 'failure'; String? output;
    await tester.pumpWidget(screen(ledger, save: (name, csv) async {
      calls++; output = csv; expect(name.endsWith('.csv'), isTrue);
      if (mode == 'failure') throw StateError('Fictional export error');
      return mode == 'success';
    })); await tester.pumpAndSettle();
    Future<void> begin() async {
      final export = find.byKey(const ValueKey('export-report'));
      await tester.ensureVisible(export); await tester.tap(export); await tester.pumpAndSettle();
    }
    await begin(); expect(calls, 0); expect(find.text('Export an unencrypted report?'), findsOneWidget);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(calls, 0);
    await begin(); await tester.tap(find.byKey(const ValueKey('confirm-report-export'))); await tester.pumpAndSettle();
    expect(calls, 1); expect(find.textContaining('could not be saved'), findsOneWidget);
    mode = 'cancel'; await begin(); await tester.tap(find.byKey(const ValueKey('confirm-report-export'))); await tester.pumpAndSettle();
    expect(calls, 2); expect(find.text('Export cancelled.'), findsOneWidget);
    mode = 'success'; await begin(); await tester.tap(find.byKey(const ValueKey('confirm-report-export'))); await tester.pumpAndSettle();
    expect(calls, 3); expect(output, contains('500.00')); expect(output, contains('230.00'));
    expect(find.text('CSV report saved. Your workspace was not changed.'), findsOneWidget);
    expect(jsonEncode(ledger.data), savedLedger);
  });
  testWidgets('export is single-flight and no account data is changed', (tester) async {
    final ledger = reportFixture(), pending = Completer<bool>(); var calls = 0;
    await tester.pumpWidget(screen(ledger, save: (_, __) { calls++; return pending.future; })); await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('export-report'));
    await tester.ensureVisible(button); await tester.tap(button); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-report-export'))); await tester.pumpAndSettle();
    expect(calls, 1); expect(tester.widget<FilledButton>(button).onPressed, isNull);
    pending.complete(true); await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull); expect(calls, 1);
  });
  testWidgets('empty workspace is explained without export or a crash', (tester) async {
    await tester.pumpWidget(screen(LocalLedger.empty())); await tester.pumpAndSettle();
    expect(find.text('Create an account to start reporting.'), findsOneWidget);
    expect(find.byKey(const ValueKey('export-report')), findsNothing); expect(tester.takeException(), isNull);
  });
}
