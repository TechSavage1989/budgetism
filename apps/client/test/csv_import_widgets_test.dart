import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/csv_import_widgets.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account;

void main() {
  testWidgets('example preview is read-only, requires consent and retains review after a failed save', (tester) async {
    tester.view.physicalSize = const Size(430, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    late LocalVault vault; final store = TestStorage();
    await tester.runAsync(() async {
      vault = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await vault.apply('account', account('a', 'Fictional UI account', 100000));
    });
    final original = store.saved;
    await tester.pumpWidget(MaterialApp(home: CsvImportScreen(api: LocalFinanceApi(vault))));
    await tester.tap(find.text('Use fictional example CSV')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Preview transactions'));
    await tester.runAsync(() async { await tester.tap(find.text('Preview transactions')); });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); expect(store.saved, original);
    await tester.ensureVisible(find.byKey(const ValueKey('commit-import')));
    await tester.tap(find.byKey(const ValueKey('commit-import'))); await tester.pumpAndSettle();
    expect(store.saved, original);
    await tester.ensureVisible(find.byKey(const ValueKey('import-reviewed')));
    await tester.tap(find.byKey(const ValueKey('import-reviewed'))); await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('commit-import')));
    await tester.runAsync(() async { await tester.tap(find.byKey(const ValueKey('commit-import'))); });
    await tester.pumpAndSettle();
    expect(store.saved, original); // Upgrade consent still absent.
    final upgrade = find.text('I have a backup and understand this workspace will require dev.7 or newer');
    await tester.ensureVisible(upgrade); await tester.tap(upgrade); await tester.pumpAndSettle();
    store.failWrite = true;
    await tester.ensureVisible(find.byKey(const ValueKey('commit-import')));
    await tester.runAsync(() async { await tester.tap(find.byKey(const ValueKey('commit-import'))); });
    await tester.pumpAndSettle();
    expect(store.saved, original); expect(find.text('Import 2 selected rows'), findsOneWidget);
    store.failWrite = false;
    await tester.runAsync(() async { await tester.tap(find.byKey(const ValueKey('commit-import'))); });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-success')), findsOneWidget);
    expect(vault.ledger.snapshot()['imports'].length, 2); expect(vault.ledger.snapshot()['transactions'].length, 2);
    expect(LocalLedger.rows(vault.ledger.snapshot()['accounts']).single['balanceMinor'], 130000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(vault.close);
  });
}
