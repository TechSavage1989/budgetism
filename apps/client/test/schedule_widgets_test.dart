import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/schedules.dart';
import 'package:budgetism/local/schedule_widgets.dart';
import 'local_security_test.dart' show TestStorage, TestDeviceKeys;

void main() {
  const account = <String, dynamic>{'id': 'checking', 'name': 'Fictional checking'};
  const category = <String, dynamic>{'id': 'food', 'name': 'Fictional food', 'kind': 'Expense'};
  final schedule = <String, dynamic>{'id': 'schedule', 'name': 'Fictional bill', 'kind': 'expense',
    'accountId': 'checking', 'counterpartyAccountId': 'food', 'amountMinor': 2000, 'currency': 'USD',
    'notes': '', 'payee': 'Test', 'frequency': 'monthly', 'startDate': '2026-01-31', 'endDate': null, 'version': 1, 'paused': false};
  testWidgets('upgrade is explicit and failed schedule save preserves entered values', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScheduleEditor(accounts: const [account], categories: const [category],
      requiresUpgrade: true, onSave: (_) async { calls++; throw StateError('Disk unavailable'); }))));
    await tester.enterText(find.byKey(const ValueKey('schedule-name')), 'My test bill');
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-amount')));
    await tester.enterText(find.byKey(const ValueKey('schedule-amount')), '20.00');
    await tester.tap(find.text('Save schedule')); await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('confirm the recurring-schedule format upgrade.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('schedule-upgrade')));
    await tester.tap(find.byKey(const ValueKey('schedule-upgrade'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Save schedule')); await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Disk unavailable'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('schedule-amount'))).controller!.text, '20.00');
  });
  testWidgets('record is single-flight and sends exact amount and occurrence identity', (tester) async {
    final completion = Completer<void>(); Json? sent; var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<bool>(context: context, builder: (_) => OccurrenceDialog(
        occurrence: ScheduledOccurrence(schedule, 0, '2026-01-31', null), action: 'confirm',
        onSave: (value) { calls++; sent = value; return completion.future; })), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('occurrence-amount')), '23.45');
    await tester.tap(find.text('Record transaction')); await tester.pump();
    await tester.tap(find.text('Record transaction')); await tester.pump();
    expect(calls, 1); expect(sent!['amountMinor'], 2345); expect(sent!['index'], 0); expect(sent!['scheduleId'], 'schedule');
    completion.complete(); await tester.pumpAndSettle();
    expect(find.byType(OccurrenceDialog), findsNothing);
  });
  testWidgets('postpone rejects unchanged due date without submitting', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OccurrenceDialog(
      occurrence: ScheduledOccurrence(schedule, 0, '2026-01-31', null), action: 'postpone',
      onSave: (_) async { calls++; }))));
    await tester.tap(find.text('Save due date')); await tester.pumpAndSettle();
    expect(calls, 0); expect(find.textContaining('Choose a later due date.'), findsOneWidget);
  });
  testWidgets('scheduled panel renders narrow layout and disposes its date-only timer', (tester) async {
    tester.view.physicalSize = const Size(430, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    late LocalVault vault;
    await tester.runAsync(() async { vault = await LocalVault.open(TestStorage(), '', create: true,
      requirePassword: false, deviceKeys: TestDeviceKeys()); });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.all(12), child: SchedulePanel(api: LocalFinanceApi(vault),
        onChanged: () async {}, onOpenTransaction: (_) async {}))))));
    await tester.pumpAndSettle();
    expect(find.text('Scheduled bills and income'), findsOneWidget); expect(tester.takeException(), isNull);
    await tester.tap(find.text('Schedules')); await tester.pumpAndSettle();
    expect(find.text('No schedules yet.'), findsOneWidget); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(vault.close);
  });
}
