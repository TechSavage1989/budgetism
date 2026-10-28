import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/reconciliation_widgets.dart';
import 'local_ledger_test.dart' show accounts;
import 'reconciliation_test.dart' show reconcileFixture;

void main() {
  testWidgets('statement review preserves inputs after failed save and requires exact review consent', (tester) async {
    final l = reconcileFixture(); final a = accounts(l).first['id'] as String;
    var calls = 0; Json? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatementReview(snapshot: l.snapshot(), accountId: a,
      onSave: (request) async { calls++; saved = request; throw StateError('Simulated write failure'); }))));
    await tester.enterText(find.byKey(const ValueKey('statement-date')), '2026-10-31');
    await tester.enterText(find.byKey(const ValueKey('statement-closing')), '1300.00');
    await tester.ensureVisible(find.text('Review statement'));
    await tester.tap(find.text('Review statement')); await tester.pumpAndSettle();
    expect(calls, 0);
    for (final t in LocalLedger.rows(l.data['transactions'])) {
      final row = find.byKey(ValueKey('statement-row:${t['id']}'));
      await tester.ensureVisible(row); await tester.tap(row); await tester.pumpAndSettle();
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('statement-difference'))).data, 'Statement difference: \$0.00');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish reconciliation')).onPressed, isNull);
    for (final key in ['statement-upgrade', 'statement-reviewed']) {
      final box = find.byKey(ValueKey(key)); await tester.ensureVisible(box); await tester.tap(box); await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Finish reconciliation')); await tester.pumpAndSettle();
    expect(calls, 1); expect(find.textContaining('Simulated write failure'), findsOneWidget);
    expect(saved!['closingMinor'], 130000); expect(saved!['transactionIds'].length, 2);
    final operation = saved!['operationId'];
    await tester.tap(find.text('Finish reconciliation')); await tester.pumpAndSettle();
    expect(calls, 2); expect(saved!['operationId'], operation);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow statement view and invalid precision render without overflow', (tester) async {
    tester.view.physicalSize = const Size(430, 850); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final l = reconcileFixture();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatementReview(snapshot: l.snapshot(),
      accountId: accounts(l).first['id'], onSave: (_) async {}))));
    await tester.enterText(find.byKey(const ValueKey('statement-closing')), '1300.001');
    await tester.tap(find.text('Review statement')); await tester.pumpAndSettle();
    expect(find.textContaining('two decimal places'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('reopening requires both reason and confirmation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ReopenStatementDialog())));
    final finish = find.widgetWithText(FilledButton, 'Reopen statement');
    expect(tester.widget<FilledButton>(finish).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Correct my selection');
    expect(tester.widget<FilledButton>(finish).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile)); await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(finish).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
