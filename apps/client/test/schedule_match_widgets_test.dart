import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/schedules.dart';
import 'package:budgetism/local/schedule_match_dialog.dart';
import 'schedule_matching_test.dart' show matchingFixture;
import 'schedules_test.dart' show onlySchedule;

Widget matchHost(LocalLedger ledger, Future<void> Function(Json) save) => MaterialApp(home: Scaffold(
  body: Builder(builder: (context) => TextButton(onPressed: () => showDialog<bool>(context: context,
    builder: (_) => ScheduleMatchDialog(occurrence: ScheduledOccurrence(onlySchedule(ledger), 0, '2026-10-28', null),
      snapshot: ledger.snapshot(), onSave: save)), child: const Text('Open matching')))));

Future<void> selectAndReview(WidgetTester tester, String id) async {
  final candidate = find.byKey(ValueKey('match-candidate-$id'));
  await tester.ensureVisible(candidate); await tester.tap(candidate); await tester.pumpAndSettle();
  final review = find.byKey(const ValueKey('match-review'));
  await tester.ensureVisible(review); await tester.tap(review); await tester.pumpAndSettle();
}

void main() {
  testWidgets('matching requires explicit selection and review and keeps inputs on failure', (tester) async {
    final ledger = matchingFixture(imported: true); final sent = <Json>[];
    final before = LocalLedger.clone(ledger.data);
    await tester.pumpWidget(matchHost(ledger, (command) async { sent.add(command); throw StateError('Disk unavailable'); }));
    await tester.tap(find.text('Open matching')); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('match-save'))); await tester.pumpAndSettle();
    expect(sent, isEmpty); expect(find.textContaining('Select one transaction and confirm'), findsOneWidget);
    final id = LocalLedger.rows(ledger.data['transactions']).single['id'] as String;
    await selectAndReview(tester, id);
    await tester.tap(find.byKey(const ValueKey('match-save'))); await tester.pumpAndSettle();
    expect(sent.length, 1); expect(sent.single['transactionId'], id);
    expect(sent.single['confirmMatch'], isTrue); expect(sent.single['expectedRevision'], ledger.revision);
    expect(find.textContaining('Disk unavailable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('match-save'))); await tester.pumpAndSettle();
    expect(sent.length, 2); expect(sent.last, sent.first); expect(ledger.data, before);
  });

  testWidgets('single-flight matching closes only after successful save', (tester) async {
    final ledger = matchingFixture(); final completer = Completer<void>(); var calls = 0;
    await tester.pumpWidget(matchHost(ledger, (_) { calls++; return completer.future; }));
    await tester.tap(find.text('Open matching')); await tester.pumpAndSettle();
    await selectAndReview(tester, LocalLedger.rows(ledger.data['transactions']).single['id'] as String);
    await tester.tap(find.byKey(const ValueKey('match-save'))); await tester.pump();
    await tester.tap(find.byKey(const ValueKey('match-save'))); await tester.pump();
    expect(calls, 1); expect(find.byType(ScheduleMatchDialog), findsOneWidget);
    completer.complete(); await tester.pumpAndSettle(); expect(find.byType(ScheduleMatchDialog), findsNothing);
  });

  testWidgets('narrow layout shows variable-amount review and search clears selection', (tester) async {
    tester.view.physicalSize = const Size(430, 800); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final ledger = matchingFixture(amount: 2345, date: '2026-10-30'); var calls = 0;
    await tester.pumpWidget(matchHost(ledger, (_) async { calls++; }));
    await tester.tap(find.text('Open matching')); await tester.pumpAndSettle();
    expect(find.textContaining('No eligible transactions.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('match-different-amounts')));
    await tester.tap(find.byKey(const ValueKey('match-different-amounts'))); await tester.pumpAndSettle();
    await selectAndReview(tester, LocalLedger.rows(ledger.data['transactions']).single['id'] as String);
    expect(find.textContaining('actual amount differs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('match-search')));
    await tester.enterText(find.byKey(const ValueKey('match-search')), 'unrelated'); await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('match-review')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('match-save'))); await tester.pumpAndSettle();
    expect(calls, 0); expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(find.byType(ScheduleMatchDialog), findsNothing);
  });
}
