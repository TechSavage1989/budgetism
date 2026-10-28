import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/transaction_register.dart';
import 'package:budgetism/local/transaction_register_widgets.dart';
import 'package:budgetism/main.dart' show FinanceShell;
import 'reports_test.dart' show reportFixture;
import 'reconciliation_test.dart' show reconcileFixture, statementRequest;
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'category_rules_storage_test.dart' show seedRules;

Future<void> showRegister(WidgetTester tester, Json Function() read, {
  RegisterFilter filter = const RegisterFilter(), Future<void> Function(Json)? edit,
  ValueChanged<RegisterFilter>? changed}) => tester.pumpWidget(MaterialApp(home: Scaffold(
    body: SingleChildScrollView(key: const Key('register-scroll'), child: Padding(
      padding: const EdgeInsets.all(20), child: TransactionRegisterPanel(readSnapshot: read,
        initialFilter: filter, onEdit: edit, onFilterChanged: changed))))));
Future<void> visible(WidgetTester tester, Finder finder) async {
  final scrollable = find.descendant(of: find.byKey(const Key('register-scroll')), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(finder, 400, scrollable: scrollable, maxScrolls: 150);
  await tester.ensureVisible(finder); await tester.pumpAndSettle();
}
void main() {
  for (final width in [430.0, 1100.0]) {
    testWidgets('register filters and details fit $width pixels without writes', (tester) async {
      tester.view.physicalSize = Size(width, 900); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final ledger = reportFixture(), before = jsonEncode(ledger.data);
      final data = ledger.snapshot(includeVoided: true);
      final cats = LocalLedger.rows(data['categories']).where((c) => c['kind'] == 'Expense').toList();
      await showRegister(tester, () => ledger.snapshot(includeVoided: true),
        filter: RegisterFilter(categoryId: cats[1]['id'], minimum: '200', maximum: '200'));
      await tester.pumpAndSettle();
      expect(find.text('1 matching transactions'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('register-expenses'))).data, '\$140.00');
      final id = TransactionRegister.calculate(data, RegisterFilter(categoryId: cats[1]['id'])).entries.single.id;
      final row = find.byKey(ValueKey('register-entry-$id'));
      await visible(tester, row); await tester.tap(row); await tester.pumpAndSettle();
      expect(find.text('Transaction details'), findsOneWidget);
      expect(find.text('Whole transaction: \$200.00 USD'), findsOneWidget);
      expect(find.text('Housing: \$140.00'), findsOneWidget);
      expect(find.byKey(const Key('register-edit')), findsNothing);
      expect(tester.takeException(), isNull); expect(jsonEncode(ledger.data), before);
    });
  }

  testWidgets('invalid input hides stale results, reset clears visible fields and notifies session owner', (tester) async {
    final ledger = reportFixture(); RegisterFilter? last;
    await showRegister(tester, () => ledger.snapshot(includeVoided: true), changed: (v) => last = v);
    await tester.enterText(find.byKey(const Key('register-query')), '"unclosed'); await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-error')), findsOneWidget);
    expect(find.byKey(const Key('register-count')), findsNothing);
    await visible(tester, find.byKey(const Key('register-reset')));
    await tester.tap(find.byKey(const Key('register-reset'))); await tester.pumpAndSettle();
    expect(last!.query, ''); expect(tester.widget<TextField>(find.byKey(const Key('register-query'))).controller!.text, '');
    expect(find.text('6 matching transactions'), findsOneWidget);
    await visible(tester, find.byKey(const Key('register-filters')));
    await tester.tap(find.text('Filters (0 active)')); await tester.pumpAndSettle();
    await visible(tester, find.byKey(const Key('register-minimum')));
    await tester.enterText(find.byKey(const Key('register-minimum')), '1.001'); await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-count')), findsNothing);
    expect(find.textContaining('two decimal places'), findsOneWidget);
    await visible(tester, find.byKey(const Key('register-reset')));
    await tester.tap(find.byKey(const Key('register-reset'))); await tester.pumpAndSettle();
    expect(last!.advancedCount, 0); expect(last!.sort, 'newest'); expect(find.text('6 matching transactions'), findsOneWidget);
  });

  testWidgets('details require explicit edit and recheck protection before handing off', (tester) async {
    var ledger = reconcileFixture(); var edits = 0;
    final id = LocalLedger.rows(ledger.data['transactions']).last['id'] as String;
    await showRegister(tester, () => ledger.snapshot(includeVoided: true), edit: (_) async { edits++; });
    final row = find.byKey(ValueKey('register-entry-$id'));
    await visible(tester, row); await tester.tap(row); await tester.pumpAndSettle();
    expect(edits, 0); expect(find.byKey(const Key('register-edit')), findsOneWidget);
    ledger = ledger.apply('reconcile', statementRequest(ledger));
    final before = jsonEncode(ledger.data);
    await tester.tap(find.byKey(const Key('register-edit'))); await tester.pumpAndSettle();
    expect(edits, 0); expect(find.textContaining('now protected or unavailable'), findsOneWidget);
    expect(jsonEncode(ledger.data), before);
    await visible(tester, row); await tester.tap(row); await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-edit')), findsNothing);
    expect(find.textContaining('Reopen the applicable statements'), findsOneWidget);
  });

  testWidgets('eligible explicit edit hands off the original full transaction without modifying it', (tester) async {
    final ledger = reconcileFixture(), before = jsonEncode(ledger.data); Json? submitted;
    final t = LocalLedger.rows(ledger.data['transactions']).last;
    await showRegister(tester, () => ledger.snapshot(includeVoided: true), edit: (v) async { submitted = v; });
    final row = find.byKey(ValueKey('register-entry-${t['id']}'));
    await visible(tester, row); await tester.tap(row); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('register-edit'))); await tester.pumpAndSettle();
    expect(submitted, t); expect(jsonEncode(ledger.data), before);
  });

  testWidgets('all matching totals include rows beyond the first 100 and loading more changes no records', (tester) async {
    final data = reconcileFixture().snapshot(includeVoided: true), seed = LocalLedger.rows(reconcileFixture().data['transactions']).first;
    // Keep account/category identifiers from this snapshot, not a second random fixture.
    final first = LocalLedger.rows(data['transactions']).first;
    data['transactions'] = [for (var i = 0; i < 101; i++) {...first, 'id': 'row-${i.toString().padLeft(3, '0')}', 'amountMinor': seed['amountMinor']}];
    final before = jsonEncode(data);
    await showRegister(tester, () => data); await tester.pumpAndSettle();
    expect(find.text('101 matching transactions'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('register-income'))).data, '\$50,500.00');
    expect(find.byKey(const ValueKey('register-entry-row-100')), findsNothing);
    await visible(tester, find.byKey(const Key('register-more')));
    await tester.tap(find.byKey(const Key('register-more'))); await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('register-entry-row-100')), findsOneWidget);
    expect(jsonEncode(data), before); expect(tester.takeException(), isNull);
  });

  testWidgets('voided details offer no edit, unknown selections stay visible instead of silently selecting all', (tester) async {
    final ledger = reportFixture();
    await showRegister(tester, () => ledger.snapshot(includeVoided: true), filter: const RegisterFilter(status: 'voided'), edit: (_) async {});
    final id = LocalLedger.rows(ledger.data['transactions']).last['id'];
    final row = find.byKey(ValueKey('register-entry-$id'));
    await visible(tester, row); await tester.tap(row); await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-edit')), findsNothing);
    expect(find.textContaining('Voided record.'), findsOneWidget);
    await tester.tap(find.text('Close')); await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await showRegister(tester, () => ledger.snapshot(includeVoided: true), filter: const RegisterFilter(accountId: 'missing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-error')), findsOneWidget);
    expect(find.byKey(const Key('register-count')), findsNothing); expect(tester.takeException(), isNull);
  });

  testWidgets('real shell preserves register search across navigation without persisting it', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    late LocalVault vault;
    await tester.runAsync(() async {
      vault = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await seedRules(vault);
    });
    final before = jsonEncode(vault.ledger.data);
    try {
      await tester.pumpWidget(MaterialApp(home: FinanceShell(api: LocalFinanceApi(vault), username: 'Fictional',
        onLogout: () {}, onToggleTheme: () {}, onCheckUpdates: () {})));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transactions').first); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('register-query')), 'corner'); await tester.pumpAndSettle();
      expect(find.text('1 matching transactions'), findsOneWidget);
      await tester.tap(find.text('Dashboard').first); await tester.pumpAndSettle();
      await tester.tap(find.text('Transactions').first); await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const Key('register-query'))).controller!.text, 'corner');
      expect(jsonEncode(vault.ledger.data), before); expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(() => vault.close());
    }
  });
}
