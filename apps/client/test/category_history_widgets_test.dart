import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/category_history_widgets.dart';
import 'package:budgetism/local/category_rule_widgets.dart';
import 'category_history_test.dart' show appliedFixture, undoRequest;
import 'reconciliation_test.dart' show statementRequest;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final root = find.byKey(const Key('category-undo-scroll'));
  final scroll = find.descendant(of: root, matching: find.byType(Scrollable)).first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0); await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 180, scrollable: scroll, maxScrolls: 100);
  await tester.ensureVisible(finder); await tester.pumpAndSettle();
}
Future<void> consent(WidgetTester tester) async {
  final reason = find.byKey(const Key('category-undo-reason'));
  await reveal(tester, reason); await tester.enterText(reason, 'Correct fictional batch');
  final review = find.byKey(const Key('category-undo-review'));
  await reveal(tester, review); await tester.tap(review); await tester.pumpAndSettle();
}
Future<void> dialog(WidgetTester tester, Json review, Future<void> Function(Json) save) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
    onPressed: () => showDialog<bool>(context: context, barrierDismissible: false,
      builder: (_) => CategoryUndoDialog(review: review, onUndo: save)), child: const Text('Open review'))))));
  await tester.tap(find.text('Open review')); await tester.pumpAndSettle();
}
void main() {
  for (final width in [430.0, 1100.0]) {
    testWidgets('history and batch review fit $width pixels without writes', (tester) async {
      tester.view.physicalSize = Size(width, 850); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final l = appliedFixture(); var writes = 0;
      final original = LocalLedger.clone(l.data);
      await tester.pumpWidget(MaterialApp(home: CategoryHistoryPage(readData: () => LocalLedger.clone(l.data),
        onUndo: (_) async { writes++; })));
      await tester.tap(find.byKey(const ValueKey('category-batch-categorize'))); await tester.pumpAndSettle();
      expect(find.text('Review categorization batch'), findsOneWidget);
      expect(find.text('Original category: Groceries'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('category-undo-reason')));
      expect(tester.takeException(), isNull); expect(writes, 0); expect(l.data, original);
      await tester.tap(find.text('Close')); await tester.pumpAndSettle();
      expect(find.text('1 applied batches'), findsOneWidget);
    });
  }
  testWidgets('undo needs reason and review; failed save retains inputs and stable retry identity', (tester) async {
    var l = appliedFixture(); final before = LocalLedger.clone(l.data), sent = <Json>[]; var fail = true;
    await dialog(tester, CategoryHistory.preview(l.data, 'categorize'), (input) async {
      sent.add(LocalLedger.clone(input)); final result = l.apply('category-undo', input);
      if (fail) throw StateError('Fictional disk unavailable'); l = result;
    });
    await tester.tap(find.byKey(const Key('category-undo-submit'))); await tester.pumpAndSettle();
    expect(sent, isEmpty); expect(find.textContaining('Enter a reason'), findsOneWidget);
    await consent(tester);
    await tester.tap(find.byKey(const Key('category-undo-submit'))); await tester.pumpAndSettle();
    expect(l.data, before); expect(sent.length, 1);
    expect(find.textContaining('Fictional disk unavailable'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('category-undo-review'))).value, true);
    expect(tester.widget<TextField>(find.byKey(const Key('category-undo-reason'))).controller!.text, 'Correct fictional batch');
    fail = false; await tester.tap(find.byKey(const Key('category-undo-submit'))); await tester.pumpAndSettle();
    expect(sent.length, 2); expect(sent.last, sent.first); expect(find.byType(CategoryUndoDialog), findsNothing);
    expect(CategoryHistory.batches(l.data).single['undone'], true);
  });
  testWidgets('changed or already-undone batches explain status without a usable undo control', (tester) async {
    final original = appliedFixture();
    final states = [original.apply('reconcile', statementRequest(original, closing: 97500)),
      original.apply('category-undo', undoRequest(original))];
    for (final l in states) {
      var calls = 0; final before = LocalLedger.clone(l.data);
      await dialog(tester, CategoryHistory.preview(l.data, 'categorize'), (_) async { calls++; });
      expect(find.byKey(const Key('category-undo-submit')), findsNothing);
      expect(find.byKey(const Key('category-undo-reason')), findsNothing);
      expect(find.textContaining(CategoryHistory.batches(l.data).single['undone'] == true ?
        'cannot be undone twice' : 'Undo is blocked'), findsOneWidget);
      await tester.tap(find.text('Close')); await tester.pumpAndSettle();
      expect(calls, 0); expect(l.data, before);
    }
  });
  testWidgets('save is single-flight and all close/input controls are disabled until it finishes', (tester) async {
    var l = appliedFixture(); final pending = Completer<void>(); var calls = 0;
    await dialog(tester, CategoryHistory.preview(l.data, 'categorize'), (input) async {
      calls++; await pending.future; l = l.apply('category-undo', input);
    });
    await consent(tester); await tester.tap(find.byKey(const Key('category-undo-submit'))); await tester.pump();
    await tester.tap(find.byKey(const Key('category-undo-submit'))); await tester.pump();
    expect(calls, 1); expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Close')).onPressed, isNull);
    expect(tester.widget<TextField>(find.byKey(const Key('category-undo-reason'))).enabled, false);
    pending.complete(); await tester.pumpAndSettle(); expect(find.byType(CategoryUndoDialog), findsNothing);
  });
  testWidgets('stale review fails visibly without changing categories or losing entered reason', (tester) async {
    var l = appliedFixture(); final review = CategoryHistory.preview(l.data, 'categorize');
    l = l.apply('category', {'operationId': 'unrelated', 'name': 'Fictional change', 'kind': 'Expense'});
    final before = LocalLedger.clone(l.data);
    await dialog(tester, review, (input) async { l = l.apply('category-undo', input); });
    await consent(tester); await tester.tap(find.byKey(const Key('category-undo-submit'))); await tester.pumpAndSettle();
    expect(find.textContaining('Workspace changed'), findsOneWidget); expect(l.data, before);
    expect(tester.widget<TextField>(find.byKey(const Key('category-undo-reason'))).controller!.text, 'Correct fictional batch');
  });
  testWidgets('returning from history refreshes the rule page and invalidates any previous preview', (tester) async {
    var l = appliedFixture(); var historyCalls = 0;
    await tester.pumpWidget(MaterialApp(home: CategoryRulesPage(snapshot: () => l.snapshot(),
      onSave: (_) async {}, onApply: (_) async {}, onHistory: () async {
        historyCalls++; l = l.apply('category-undo', undoRequest(l));
      })));
    await tester.tap(find.text('History')); await tester.pumpAndSettle();
    expect(historyCalls, 1); expect(find.byKey(const Key('rules-review')), findsNothing);
    expect(find.text('Add rule'), findsOneWidget); expect(tester.takeException(), isNull);
  });
  testWidgets('empty and incomplete audit states are explained without undo or reset', (tester) async {
    final l = LocalLedger.empty(); var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CategoryHistoryPage(readData: () => l.data,
      onUndo: (_) async { calls++; })));
    expect(find.textContaining('No categorization batches yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: CategoryHistoryPage(readData: () => {...l.data, 'audit': [false]},
      onUndo: (_) async { calls++; })));
    expect(find.textContaining('history is incomplete'), findsOneWidget); expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
