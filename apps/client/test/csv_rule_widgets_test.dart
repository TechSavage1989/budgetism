import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/csv_import_widgets.dart';
import 'package:budgetism/local/csv_rule_widgets.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'csv_rule_suggestions_test.dart';

const sample = 'Date,Description,Amount,Reference\n2026-10-28,Rule test store,-12.34,rule-1';

// Vault reads run in the real async zone. A dialog can complete during a
// simulated route animation, so drain its real-zone continuation before the
// next interaction. Otherwise a test can tap the still-disabled parent.
Future<void> tapVisible(WidgetTester tester, Finder finder, {bool io = false}) async {
  await tester.ensureVisible(finder); await tester.pumpAndSettle();
  if (io) { await tester.runAsync(() async { await tester.tap(finder); }); }
  else { await tester.tap(finder); }
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}
Future<LocalVault> widgetVault(WidgetTester tester, TestStorage storage) async {
  late LocalVault v;
  await tester.runAsync(() async {
    v = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    await seedCsvRules(v);
  });
  return v;
}
Future<void> openCsv(WidgetTester tester, LocalVault v, {LocalFinanceApi? api}) async {
  // cross_file's native fromData ignores name and derives it from path.
  // Retain in-memory bytes while providing the metadata a real picker supplies.
  final file = XFile.fromData(Uint8List.fromList(utf8.encode(sample)),
    name: 'fictional-rules.csv', path: 'fictional-rules.csv');
  expect(file.name, 'fictional-rules.csv');
  await tester.pumpWidget(MaterialApp(home: CsvImportScreen(api: api ?? LocalFinanceApi(v), chooseFile: () async => file)));
  await tapVisible(tester, find.text('Choose CSV file'), io: true);
  await tapVisible(tester, find.text('Preview transactions'), io: true);
}
// Observe the real import operation without mocking storage or ledger behavior.
// Awaiting this future keeps encryption and the injected disk failure in the
// real async zone, rather than inferring completion from rendered animations.
class ObservedImportApi extends LocalFinanceApi {
  ObservedImportApi(super.vault);
  final requests = <Json>[];
  Future<void>? pendingImport;
  @override
  Future<void> importCsv(Json data) {
    requests.add(LocalLedger.clone(data));
    return pendingImport = super.importCsv(data);
  }
}
Future<Object?> commitCsv(WidgetTester tester, ObservedImportApi api) async {
  final button = find.byKey(const Key('commit-import'));
  await tester.ensureVisible(button); await tester.pumpAndSettle();
  expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  final previous = api.requests.length;
  Object? failure;
  await tester.runAsync(() async {
    await tester.tap(button);
    expect(api.requests.length, previous + 1,
      reason: tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join(' | '));
    try { await api.pendingImport!; } catch (error) { failure = error; }
  });
  await tester.pumpAndSettle();
  return failure;
}
Future<void> reviewCsv(WidgetTester tester) => tapVisible(tester, find.byKey(const Key('review-csv-rules')), io: true);
Future<void> acceptFirst(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const Key('csv-rule-row-2')));
  await tapVisible(tester, find.byKey(const Key('csv-rules-reviewed')));
  await tapVisible(tester, find.byKey(const Key('csv-rules-accept')), io: true);
}
void main() {
  for (final width in [430.0, 1100.0]) {
    testWidgets('suggestions fit $width pixels, select nothing by default, and cancel without saving', (tester) async {
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final storage = TestStorage(); final v = await widgetVault(tester, storage);
      final original = storage.saved, before = LocalLedger.clone(v.ledger.data);
      try {
        await openCsv(tester, v); await reviewCsv(tester);
        expect(find.text('1 suggestions | 0 selected'), findsOneWidget);
        expect(find.textContaining('Other spending to Groceries'), findsOneWidget);
        expect(tester.widget<FilledButton>(find.byKey(const Key('csv-rules-accept'))).onPressed, isNull);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tapVisible(tester, find.byTooltip('Close suggestions'));
        expect(find.byKey(ValueKey('Category for row 2:${namedCategory(v.ledger, 'Other spending')}')), findsOneWidget);
        expect(v.ledger.data, before); expect(storage.saved, original); expect(tester.takeException(), isNull);
      } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
    });
  }
  testWidgets('accepted suggestions stay unsaved, clear final review, and manual overrides are not replaced', (tester) async {
    final storage = TestStorage(); final v = await widgetVault(tester, storage); final saved = storage.saved;
    try {
      await openCsv(tester, v);
      await tapVisible(tester, find.byKey(const Key('import-reviewed')));
      await reviewCsv(tester); await acceptFirst(tester);
      expect(find.byKey(ValueKey('Category for row 2:${namedCategory(v.ledger, 'Groceries')}')), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('import-reviewed'))).value, false);
      expect(find.byKey(const Key('csv-rule-applied-2')), findsOneWidget); expect(storage.saved, saved);
      await reviewCsv(tester); expect(find.textContaining('No category changes are suggested'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Close suggestions'));
      final categoryField = find.byKey(ValueKey('Category for row 2:${namedCategory(v.ledger, 'Groceries')}'));
      expect(tester.widget<DropdownButtonFormField<String>>(categoryField).onChanged, isNotNull);
      await tapVisible(tester, categoryField);
      await tapVisible(tester, find.text('Other spending').last);
      await reviewCsv(tester); expect(find.textContaining('No category changes are suggested'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Close suggestions'));
      expect(find.byKey(const Key('csv-rule-applied-2')), findsNothing); expect(storage.saved, saved);
      expect(tester.takeException(), isNull);
    } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
  });
  testWidgets('only final import persists the accepted category; failed write retains choices for a single retry', (tester) async {
    final storage = TestStorage(); final v = await widgetVault(tester, storage); final saved = storage.saved; final api = ObservedImportApi(v);
    try {
      await openCsv(tester, v, api: api); await reviewCsv(tester); await acceptFirst(tester);
      expect(find.byType(CsvRuleSuggestionsDialog), findsNothing);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('import-reviewed'))).onChanged, isNotNull);
      storage.failWrite = true;
      await tapVisible(tester, find.byKey(const Key('import-reviewed')));
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('import-reviewed'))).value, true);
      final failed = await commitCsv(tester, api);
      expect(api.requests.single['fileName'], 'fictional-rules.csv');
      expect(failed, isA<StateError>());
      expect(failed.toString(), contains('Disk unavailable'));
      expect(v.ledger.data['transactions'], isEmpty); expect(storage.saved, saved);
      expect(find.textContaining('Disk unavailable'), findsOneWidget);
      expect(find.byKey(ValueKey('Category for row 2:${namedCategory(v.ledger, 'Groceries')}')), findsOneWidget);
      storage.failWrite = false;
      expect(await commitCsv(tester, api), isNull);
      expect(api.requests.length, 2); expect(api.requests.last, api.requests.first);
      expect(v.ledger.data['transactions'].length, 1); expect(v.ledger.data['imports'].length, 1);
      final t = LocalLedger.rows(v.ledger.data['transactions']).single;
      expect(t['counterpartyAccountId'], namedCategory(v.ledger, 'Groceries')); expect(t['amountMinor'], 1234);
      expect(LocalLedger.rows(v.ledger.snapshot()['accounts']).single['balanceMinor'], 98766);
      expect(tester.takeException(), isNull);
    } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
  });
  testWidgets('rules changed in another window block acceptance while retaining review selections', (tester) async {
    final storage = TestStorage(); final v = await widgetVault(tester, storage);
    try {
      await openCsv(tester, v); await reviewCsv(tester);
      final r = CategoryRules.ordered(v.ledger.data).single;
      await tester.runAsync(() => v.apply('category-rule', {...r, 'operationId': 'changed',
        'expectedRevision': v.ledger.revision, 'expectedVersion': r['version'], 'enabled': false}));
      final changed = storage.saved;
      await acceptFirst(tester);
      expect(find.textContaining('Workspace or import choices changed'), findsOneWidget);
      expect(find.byType(CsvRuleSuggestionsDialog), findsOneWidget);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('csv-rule-row-2'))).value, true);
      expect(v.ledger.data['transactions'], isEmpty); expect(storage.saved, changed);
      await tapVisible(tester, find.byTooltip('Close suggestions'));
      await tapVisible(tester, find.text('Back to mapping'));
      await tapVisible(tester, find.text('Preview transactions'), io: true);
      await reviewCsv(tester); expect(find.textContaining('No category changes are suggested'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
  });
  testWidgets('pending acceptance is single-flight, disables close, and failure retains selection', (tester) async {
    final l = csvRulesFixture(), table = ruleTable();
    final review = ruleReview(l, table, ruleChoices(l, ruleEntries(table)));
    final pending = Completer<void>(); var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CsvRuleSuggestionsDialog(review: review, onAccept: (_) async {
      calls++; await pending.future; throw StateError('Fictional read failure');
    })));
    await tapVisible(tester, find.byKey(const Key('csv-rule-row-2')));
    await tapVisible(tester, find.byKey(const Key('csv-rules-reviewed')));
    await tester.tap(find.byKey(const Key('csv-rules-accept'))); await tester.pump();
    await tester.tap(find.byKey(const Key('csv-rules-accept'))); await tester.pump();
    expect(calls, 1); expect(tester.widget<IconButton>(find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Close suggestions')).onPressed, isNull);
    pending.complete(); await tester.pumpAndSettle();
    expect(find.textContaining('Fictional read failure'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('csv-rule-row-2'))).value, true);
    expect(tester.takeException(), isNull);
  });
}
