import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/main.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/daily_workspace.dart';
import 'package:budgetism/local/category_rule_widgets.dart';
import 'package:budgetism/local/import_profile_widgets.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'category_rules_storage_test.dart' show seedRules;
import 'reconciliation_test.dart' show statementRequest;

void main() {
  for (final width in [360.0, 1100.0]) {
    testWidgets('Home and direct Settings tools fit $width pixels and preserve encrypted data', (tester) async {
      tester.view.physicalSize = Size(width, 950); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final storage = TestStorage(); late LocalVault vault;
      await tester.runAsync(() async {
        vault = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
        await seedRules(vault);
      });
      final before = jsonEncode(vault.ledger.data), ciphertext = storage.saved;
      try {
        await tester.pumpWidget(MaterialApp(home: FinanceShell(api: LocalFinanceApi(vault), username: 'Fictional',
          onLogout: () {}, onToggleTheme: () {}, onCheckUpdates: () {})));
        await tester.pumpAndSettle();
        expect(find.byType(DailyHomePanel), findsOneWidget);
        if (width < 850) {
          expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations.length, 5);
          await tester.tap(find.text('More')); await tester.pumpAndSettle();
          final settings = find.descendant(of: find.byType(NavigationDrawer), matching: find.text('Settings'));
          await tester.ensureVisible(settings); await tester.pumpAndSettle();
          await tester.tap(settings); await tester.pumpAndSettle();
        } else {
          final settings = find.descendant(of: find.byType(NavigationRail), matching: find.text('Settings'));
          await tester.ensureVisible(settings); await tester.pumpAndSettle();
          await tester.tap(settings); await tester.pumpAndSettle();
        }
        expect(find.byType(WorkspaceToolsPanel), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('tool-rules'))); await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tool-rules'))); await tester.pumpAndSettle();
        expect(find.byType(CategoryRulesPage), findsOneWidget);
        await tester.tap(find.byTooltip('Close rules')); await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('tool-profiles'))); await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tool-profiles'))); await tester.pumpAndSettle();
        expect(find.byType(ImportProfilesManager), findsOneWidget);
        await tester.tap(find.byTooltip('Close profiles')); await tester.pumpAndSettle();
        expect(jsonEncode(vault.ledger.data), before); expect(storage.saved, ciphertext);
        expect(vault.passwordRequired, isFalse); expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(() => vault.close());
      }
    });
  }

  testWidgets('Home details preserve reconciliation protections and opening details does not write', (tester) async {
    final storage = TestStorage(); late LocalVault vault;
    await tester.runAsync(() async {
      vault = await LocalVault.open(storage, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await seedRules(vault);
      await vault.apply('reconcile', statementRequest(vault.ledger, closing: 97500));
    });
    final before = jsonEncode(vault.ledger.data), ciphertext = storage.saved;
    final id = LocalLedger.rows(vault.ledger.data['transactions']).single['id'] as String;
    var edits = 0;
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showHomeTransaction(context, LocalFinanceApi(vault), id, (_) async { edits++; }),
        child: const Text('Inspect fictional entry'))))));
      await tester.tap(find.text('Inspect fictional entry')); await tester.pumpAndSettle();
      expect(find.text('Transaction details'), findsOneWidget); expect(find.byKey(const Key('register-edit')), findsNothing);
      expect(find.textContaining('Reopen the applicable statements'), findsOneWidget);
      await tester.tap(find.text('Close')); await tester.pumpAndSettle();
      expect(edits, 0); expect(jsonEncode(vault.ledger.data), before); expect(storage.saved, ciphertext);
    } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(() => vault.close()); }
  });

  testWidgets('tools clearly gate local-only features and leave theme/update actions available', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: WorkspaceToolsPanel(
      local: false, passwordRequired: false, onAction: actions.add)))));
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('tool-rules'))).onTap, isNull);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('tool-connections'))).onTap, isNull);
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('tool-review'))).onTap, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('tool-updates'))); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tool-updates'))); await tester.pumpAndSettle();
    expect(actions, ['updates']); expect(find.textContaining('No real bank is connected'), findsOneWidget);
  });
}
