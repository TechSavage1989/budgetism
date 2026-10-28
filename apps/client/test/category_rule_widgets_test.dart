import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/category_rule_widgets.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/workspace_dialogs.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'category_rules_test.dart' show rulesFixture, ruleRequest, ruleTarget;

Future<void> reveal(WidgetTester tester, Finder finder, {bool editor = false}) async {
  final root = find.byKey(Key(editor ? 'rule-editor-scroll' : 'rules-scroll'));
  final scrollable = find.descendant(of: root, matching: find.byType(Scrollable)).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 180, scrollable: scrollable, maxScrolls: 100);
  await tester.ensureVisible(finder); await tester.pumpAndSettle();
}
Future<void> preview(WidgetTester tester) async {
  for (final entry in {'rules-from': '2026-01-01', 'rules-through': '2026-12-31'}.entries) {
    await reveal(tester, find.byKey(Key(entry.key)));
    await tester.enterText(find.byKey(Key(entry.key)), entry.value);
  }
  await reveal(tester, find.text('Generate preview'));
  await tester.tap(find.text('Generate preview')); await tester.pumpAndSettle();
}
Future<void> choose(WidgetTester tester, String id) async {
  final proposal = find.byKey(ValueKey('proposal-$id'));
  await reveal(tester, proposal); await tester.tap(proposal); await tester.pumpAndSettle();
  final confirm = find.byKey(const Key('rules-review'));
  await reveal(tester, confirm); await tester.tap(confirm); await tester.pumpAndSettle();
}
void main() {
  testWidgets('category management opens rules without modifying the workspace', (tester) async {
    late LocalVault vault;
    await tester.runAsync(() async {
      vault = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    });
    final before = LocalLedger.clone(vault.ledger.data);
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => manageLocalCategories(context, LocalFinanceApi(vault)), child: const Text('Manage categories'))))));
      await tester.tap(find.text('Manage categories')); await tester.pumpAndSettle();
      await tester.tap(find.text('Categorization rules')); await tester.pumpAndSettle();
      expect(find.byType(CategoryRulesPage), findsOneWidget); expect(vault.ledger.data, before);
      await tester.tap(find.byTooltip('Close rules')); await tester.pumpAndSettle();
      expect(find.byType(CategoryRulesPage), findsNothing); expect(find.text('Categories'), findsOneWidget);
      expect(vault.ledger.data, before); expect(tester.takeException(), isNull);
    } finally { await tester.runAsync(() => vault.close()); }
  });

  testWidgets('new rule needs migration consent and retains fields and operation across failed-save retry', (tester) async {
    var ledger = rulesFixture(); final before = LocalLedger.clone(ledger.data), sent = <Json>[];
    var failWrite = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<bool>(context: context, builder: (_) => CategoryRuleEditor(
        data: ledger.snapshot(), onSave: (input) async {
          sent.add(LocalLedger.clone(input)); final changed = ledger.apply('category-rule', input);
          if (failWrite) throw StateError('Disk unavailable');
          ledger = changed;
        })), child: const Text('Open editor'))))));
    await tester.tap(find.text('Open editor')); await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rule-name')), 'Fictional rule');
    await reveal(tester, find.byKey(const Key('rule-pattern')), editor: true);
    await tester.enterText(find.byKey(const Key('rule-pattern')), 'corner');
    final dropdown = find.byKey(const ValueKey('rule-category:'));
    await reveal(tester, dropdown, editor: true); await tester.tap(dropdown); await tester.pumpAndSettle();
    await tester.tap(find.text('Other spending').last); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-save'))); await tester.pumpAndSettle();
    expect(ledger.data, before); expect(find.textContaining('confirm the saved-rules format upgrade'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('rule-upgrade')), editor: true);
    await tester.tap(find.byKey(const Key('rule-upgrade'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rule-save'))); await tester.pumpAndSettle();
    expect(find.textContaining('Disk unavailable'), findsOneWidget); expect(ledger.data, before);
    final last = sent.last; failWrite = false;
    await tester.tap(find.byKey(const Key('rule-save'))); await tester.pumpAndSettle();
    expect(sent.last, last); expect(find.byType(CategoryRuleEditor), findsNothing);
    expect(ledger.data['transactions'], before['transactions']); expect(ledger.data['categoryRules'].length, 1);
    expect(CategoryRules.ordered(ledger.data).single['categoryId'], ruleTarget(ledger));
  });

  testWidgets('review selects nothing by default and failed batch retains reviewed selection for retry', (tester) async {
    var ledger = rulesFixture(); ledger = ledger.apply('category-rule', ruleRequest(ledger));
    final before = LocalLedger.clone(ledger.data), sent = <Json>[]; var failWrite = true;
    await tester.pumpWidget(MaterialApp(home: CategoryRulesPage(snapshot: () => ledger.snapshot(),
      onSave: (_) async {}, onApply: (input) async {
        sent.add(LocalLedger.clone(input)); final changed = ledger.apply('categorize', input);
        if (failWrite) throw StateError('Disk unavailable'); ledger = changed;
      })));
    await preview(tester);
    await reveal(tester, find.byKey(const Key('rules-apply')));
    await tester.tap(find.byKey(const Key('rules-apply'))); await tester.pumpAndSettle();
    expect(sent, isEmpty); expect(ledger.data, before);
    await choose(tester, LocalLedger.rows(ledger.data['transactions']).single['id']);
    await reveal(tester, find.byKey(const Key('rules-apply')));
    await tester.tap(find.byKey(const Key('rules-apply'))); await tester.pumpAndSettle();
    expect(sent.length, 1); expect(ledger.data, before);
    await reveal(tester, find.byKey(const Key('rules-review')));
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('rules-review'))).value, isTrue);
    failWrite = false;
    await reveal(tester, find.byKey(const Key('rules-apply')));
    await tester.tap(find.byKey(const Key('rules-apply'))); await tester.pumpAndSettle();
    expect(sent.length, 2); expect(sent.last, sent.first);
    expect(ledger.data['transactions'].length, 1);
    expect(LocalLedger.rows(ledger.data['transactions']).single['counterpartyAccountId'], ruleTarget(ledger));
    expect(find.byKey(const Key('rules-review')), findsNothing);
  });

  testWidgets('narrow preview resets on filter change and applies single-flight', (tester) async {
    tester.view.physicalSize = const Size(430, 800); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var ledger = rulesFixture(); ledger = ledger.apply('category-rule', ruleRequest(ledger));
    var calls = 0; final completer = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: CategoryRulesPage(snapshot: () => ledger.snapshot(),
      onSave: (_) async {}, onApply: (input) async {
        calls++; await completer.future; ledger = ledger.apply('categorize', input);
      })));
    await preview(tester); await choose(tester, LocalLedger.rows(ledger.data['transactions']).single['id']);
    await reveal(tester, find.byKey(const Key('rules-from')));
    await tester.enterText(find.byKey(const Key('rules-from')), '2026-02-01'); await tester.pumpAndSettle();
    expect(find.byKey(const Key('rules-review')), findsNothing);
    await preview(tester); await choose(tester, LocalLedger.rows(ledger.data['transactions']).single['id']);
    await reveal(tester, find.byKey(const Key('rules-apply')));
    await tester.tap(find.byKey(const Key('rules-apply'))); await tester.pump();
    await tester.tap(find.byKey(const Key('rules-apply'))); await tester.pump(); expect(calls, 1);
    expect(tester.takeException(), isNull);
    completer.complete(); await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
  });

  testWidgets('narrow editor rejects fractional cents without submitting', (tester) async {
    tester.view.physicalSize = const Size(430, 800); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0; final ledger = rulesFixture();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CategoryRuleEditor(
      data: ledger.snapshot(), onSave: (_) async { calls++; }))));
    await reveal(tester, find.byKey(const Key('rule-minimum')), editor: true);
    await tester.enterText(find.byKey(const Key('rule-minimum')), '1.001');
    await tester.tap(find.byKey(const Key('rule-save'))); await tester.pumpAndSettle();
    expect(calls, 0); expect(find.textContaining('two decimal places'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
