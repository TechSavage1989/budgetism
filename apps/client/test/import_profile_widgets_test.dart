import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/vault.dart';
import 'package:budgetism/local/csv_import_widgets.dart';
import 'package:budgetism/local/import_profile_widgets.dart';
import 'local_security_test.dart' show TestDeviceKeys, TestStorage;
import 'local_ledger_test.dart' show account;
import 'import_profiles_test.dart' show profileRequest, profileSettings;

Future<void> tapVisible(WidgetTester tester, Finder finder, {bool io = false}) async {
  await tester.ensureVisible(finder); await tester.pumpAndSettle();
  if (io) { await tester.runAsync(() async { await tester.tap(finder); }); }
  else { await tester.tap(finder); }
  await tester.pumpAndSettle();
}
Future<LocalVault> profileVault(WidgetTester tester, TestStorage store) async {
  late LocalVault v;
  await tester.runAsync(() async {
    v = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
    await v.apply('account', account('a', 'Fictional first', 100000));
    await v.apply('account', account('b', 'Fictional second', 200000));
    final settings = profileSettings(v.ledger);
    settings['columns']['reference'] = null; settings['columns']['notes'] = null;
    await v.apply('import-profile', {...profileRequest(v.ledger), 'settings': settings});
  });
  return v;
}

void main() {
  testWidgets('profile editor requires consent and preserves name and operation on failed-write retry', (tester) async {
    var l = LocalLedger.empty(); final before = LocalLedger.clone(l.data), sent = <Json>[];
    var fail = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => ImportProfileEditor(
        data: l.snapshot(), settings: profileSettings(l), onSave: (input) async {
          sent.add(LocalLedger.clone(input)); final changed = l.apply('import-profile', input);
          if (fail) throw StateError('Disk unavailable'); l = changed;
        })), child: const Text('Open'))))));
    await tapVisible(tester, find.text('Open'));
    await tester.enterText(find.byKey(const Key('profile-name')), 'Fictional UI profile');
    await tapVisible(tester, find.byKey(const Key('profile-save')));
    expect(l.data, before); expect(find.textContaining('confirm the import-profile format upgrade'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('profile-upgrade')));
    await tapVisible(tester, find.byKey(const Key('profile-save')));
    expect(l.data, before); expect(find.textContaining('Disk unavailable'), findsOneWidget);
    final last = sent.last; fail = false;
    await tapVisible(tester, find.byKey(const Key('profile-save')));
    expect(sent.last, last); expect(l.data['schema'], 7); expect(l.data['transactions'], isEmpty);
    expect(find.byType(ImportProfileEditor), findsNothing); expect(tester.takeException(), isNull);
  });

  for (final width in [430.0, 1100.0]) {
    testWidgets('profile apply on reordered file fits $width pixels, preserves destination and writes nothing', (tester) async {
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final store = TestStorage(); final v = await profileVault(tester, store);
      final original = await v.storage.read();
      try {
        await tester.pumpWidget(MaterialApp(home: CsvImportScreen(api: LocalFinanceApi(v), chooseFile: () async =>
          XFile.fromData(Uint8List.fromList(utf8.encode('Amount,Description,Date\n-12.34,Fictional profile store,2026-10-28')), name: 'fictional-reordered.csv'))));
        final accounts = LocalLedger.rows(v.ledger.data['accounts']);
        await tapVisible(tester, find.byKey(ValueKey('Destination account:${accounts.first['id']}')));
        await tapVisible(tester, find.text('Fictional second (checking)').last);
        await tapVisible(tester, find.text('Choose CSV file'), io: true);
        await tapVisible(tester, find.byKey(const ValueKey('Saved profile:')));
        await tapVisible(tester, find.text('Fictional bank').last);
        final preview = find.widgetWithText(FilledButton, 'Preview transactions');
        expect(tester.widget<FilledButton>(preview).onPressed, isNull);
        await tapVisible(tester, find.byKey(const Key('apply-profile')), io: true);
        expect(find.byKey(ValueKey('Destination account:${accounts.last['id']}')), findsOneWidget);
        expect(find.byKey(const ValueKey('Date column:2')), findsOneWidget);
        expect(find.byKey(const ValueKey('Signed amount column:0')), findsOneWidget);
        await tapVisible(tester, find.text('Preview transactions'), io: true);
        expect(find.textContaining('Fictional profile store'), findsOneWidget);
        expect(find.textContaining('-\$12.34'), findsOneWidget);
        expect(await v.storage.read(), original); expect(v.ledger.data['transactions'], isEmpty); expect(store.saved, original);
        expect(tester.takeException(), isNull);
      } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
    });
  }

  testWidgets('missing headers block preview until explicit manual mapping and never modify stored profiles', (tester) async {
    final store = TestStorage(); final v = await profileVault(tester, store);
    final original = await v.storage.read(), profiles = LocalLedger.clone(v.ledger.data)['importProfiles'];
    try {
      await tester.pumpWidget(MaterialApp(home: CsvImportScreen(api: LocalFinanceApi(v), chooseFile: () async =>
        XFile.fromData(Uint8List.fromList(utf8.encode('Changed,Description,Amount\n2026-10-28,Fictional store,-12.34')), name: 'fictional-changed.csv'))));
      await tapVisible(tester, find.text('Choose CSV file'), io: true);
      await tapVisible(tester, find.byKey(const ValueKey('Saved profile:')));
      await tapVisible(tester, find.text('Fictional bank').last);
      await tapVisible(tester, find.byKey(const Key('apply-profile')), io: true);
      expect(find.textContaining('missing or appears more than once'), findsOneWidget);
      expect(find.text('Preview transactions'), findsNothing);
      await tapVisible(tester, find.text('Use manual mapping'));
      expect(find.text('Preview transactions'), findsOneWidget);
      expect(v.ledger.data['importProfiles'], profiles); expect(await v.storage.read(), original); expect(store.saved, original);
      expect(tester.takeException(), isNull);
    } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
  });

  testWidgets('save current mapping through import screen is independent from importing the file', (tester) async {
    late LocalVault v; final store = TestStorage();
    await tester.runAsync(() async {
      v = await LocalVault.open(store, '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
      await v.apply('account', account('account', 'Fictional saving', 100000));
    });
    try {
      await tester.pumpWidget(MaterialApp(home: CsvImportScreen(api: LocalFinanceApi(v))));
      await tapVisible(tester, find.text('Use fictional example CSV'));
      await tapVisible(tester, find.text('Save as new profile'));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Save as new profile')).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('profile-name')), 'Example profile');
      await tapVisible(tester, find.byKey(const Key('profile-upgrade')));
      await tapVisible(tester, find.byKey(const Key('profile-save')), io: true);
      expect(v.ledger.data['transactions'], isEmpty); expect(v.ledger.data['imports'], isEmpty);
      expect(ImportProfiles.list(v.ledger.data).single['name'], 'Example profile');
      final saved = store.saved;
      await tapVisible(tester, find.text('Preview transactions'), io: true);
      expect(find.text('Import 2 selected rows'), findsOneWidget); expect(store.saved, saved);
      expect(tester.takeException(), isNull);
    } finally { await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(v.close); }
  });

  testWidgets('manager archives only after confirmation, hides profile and restores original settings', (tester) async {
    var l = LocalLedger.empty(); l = l.apply('import-profile', profileRequest(l));
    final profiles = LocalLedger.clone(l.data)['importProfiles'];
    await tester.pumpWidget(MaterialApp(home: ImportProfilesManager(snapshot: () => l.snapshot(),
      onSave: (request) async { l = l.apply('import-profile', request); },
      onState: (request) async { l = l.apply('import-profile-state', request); }, onRefresh: () async {})));
    await tapVisible(tester, find.text('Archive'));
    await tapVisible(tester, find.text('Cancel'));
    expect(l.data['importProfiles'], profiles);
    await tapVisible(tester, find.text('Archive'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Archive'));
    expect(ImportProfiles.list(l.data), isEmpty); expect(find.text('Archived'), findsOneWidget);
    await tapVisible(tester, find.text('Restore'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Restore'));
    expect(ImportProfiles.list(l.data).single['settings'], profiles[0]['settings']);
    expect(l.data['transactions'], isEmpty); expect(tester.takeException(), isNull);
  });

  testWidgets('pending profile save disables cancellation and submits once', (tester) async {
    final l = LocalLedger.empty(), pending = Completer<void>(); var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ImportProfileEditor(data: l.snapshot(), settings: profileSettings(l),
      onSave: (_) async { calls++; await pending.future; throw StateError('Fictional test failure'); }))));
    await tester.enterText(find.byKey(const Key('profile-name')), 'Fictional pending');
    await tester.tap(find.byKey(const Key('profile-save'))); await tester.pump();
    await tester.tap(find.byKey(const Key('profile-save'))); await tester.pump();
    expect(calls, 1); expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel')).onPressed, isNull);
    pending.complete(); await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
  });
}
