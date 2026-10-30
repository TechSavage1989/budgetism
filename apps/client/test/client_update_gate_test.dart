import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/main.dart';
import 'package:budgetism/release_feed.dart';
import 'package:budgetism/update_actions.dart';
import 'package:budgetism/update_pending.dart';

const digest = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, Object> pending() => {'updateProtocol': 1, 'clientApiContract': 1, 'version': '0.1.0-dev.999', 'sha256': digest};
ReleaseFeed fakeFeed(SharedPreferences prefs) => ReleaseFeed(prefs: prefs, client: MockClient((_) async => http.Response(jsonEncode([{
  'tag_name': 'v0.1.0-dev.999', 'prerelease': true, 'draft': false,
  'html_url': 'https://github.com/TechSavage1989/budgetism/releases/tag/v0.1.0-dev.999',
  'body': 'Fictional update', 'assets': [{'name': 'Budgetism-Windows-x64.zip',
    'browser_download_url': 'https://github.com/TechSavage1989/budgetism/releases/download/v0.1.0-dev.999/Budgetism-Windows-x64.zip',
    'digest': 'sha256:$digest'}],
}]), 200)));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('pending identity excludes arbitrary paths and fails closed on unknown contracts', () {
    final value = PendingClientUpdate.parse(pending());
    expect(value.identity, '0.1.0-dev.999-$digest'); expect(value.toJson(), pending());
    for (final bad in [
      {...pending(), 'installDir': 'C:/Other'}, {...pending(), 'clientApiContract': 2},
      {...pending(), 'updateProtocol': 2}, {...pending(), 'version': '../other'},
      {...pending(), 'sha256': 'wrong'}, {...pending(), 'version': '0.1.0-dev.999/evil'},
    ]) { expect(() => PendingClientUpdate.parse(bad), throwsFormatException); }
  });
  test('stale or changed feed identity never arms downloaded archive', () {
    const old = ReleaseInfo(version: '0.1.0-dev.28', url: 'https://github.com/TechSavage1989/budgetism/releases/tag/v0.1.0-dev.28',
      notes: '', isPrerelease: true, archiveUrl: 'https://github.com/TechSavage1989/budgetism/releases/download/v0.1.0-dev.28/Budgetism-Windows-x64.zip', sha256: digest);
    const newer = ReleaseInfo(version: '0.1.0-dev.29', url: 'https://github.com/TechSavage1989/budgetism/releases/tag/v0.1.0-dev.29',
      notes: '', isPrerelease: true, archiveUrl: 'https://github.com/TechSavage1989/budgetism/releases/download/v0.1.0-dev.29/Budgetism-Windows-x64.zip', sha256: digest);
    expect(isCurrentDownloadSelection(old, const ReleaseCheckResult(ReleaseCheckStatus.updateAvailable, '', latest: old)), isTrue);
    expect(isCurrentDownloadSelection(old, const ReleaseCheckResult(ReleaseCheckStatus.updateAvailable, '', latest: newer)), isFalse);
    expect(isCurrentDownloadSelection(old, const ReleaseCheckResult(ReleaseCheckStatus.unavailable, '', latest: old)), isFalse);
    expect(isCurrentDownloadSelection(old, const ReleaseCheckResult(ReleaseCheckStatus.noReleases, '')), isFalse);
    final changed = ReleaseInfo(version: old.version, url: old.url, notes: '', isPrerelease: true,
      archiveUrl: old.archiveUrl, sha256: 'b' * 64);
    expect(isCurrentDownloadSelection(old, ReleaseCheckResult(ReleaseCheckStatus.updateAvailable, '', latest: changed)), isFalse);
  });
  testWidgets('trial process cannot create financial UI until helper commits', (tester) async {
    final receipt = Completer<bool>(); var created = 0;
    await tester.pumpWidget(UpdateCommitGate(acknowledge: () => receipt.future,
      builder: () { created++; return const MaterialApp(home: Text('Financial session')); }));
    await tester.pump();
    expect(created, 0);
    expect(find.text('Financial session'), findsNothing);
    receipt.complete(true); await tester.pumpAndSettle();
    expect(created, 1);
    expect(find.text('Financial session'), findsOneWidget);
  });
  testWidgets('failed trial stays inert rather than opening a session during rollback', (tester) async {
    var created = 0;
    await tester.pumpWidget(UpdateCommitGate(acknowledge: () async => false,
      builder: () { created++; return const MaterialApp(home: Text('Financial session')); }));
    await tester.pumpAndSettle();
    expect(created, 0);
    expect(find.textContaining('Keep this window open'), findsOneWidget);
  });

  testWidgets('startup admission blocks mounting every financial/session screen', (tester) async {
    final wait = Completer<UpdateStartupResult>(); Widget? mounted;
    final starting = startBudgetism(startup: () => wait.future, mount: (widget) => mounted = widget);
    await tester.pump();
    expect(mounted, isNull); expect(find.byType(ConnectionScreen), findsNothing);
    wait.complete(const UpdateStartupResult(message: 'Fictional safe refusal'));
    await starting;
    expect((mounted! as BudgetismApp).startupMessage, 'Fictional safe refusal');
  });
  testWidgets('startup failure mounts old app with explicit refusal rather than retrying', (tester) async {
    var calls = 0; Widget? mounted;
    await startBudgetism(startup: () async { calls++; throw StateError('fictional'); }, mount: (widget) => mounted = widget);
    expect(calls, 1); expect((mounted! as BudgetismApp).startupMessage, contains('failed'));
  });
  testWidgets('opt-out during automatic download cannot arm pending install or restart session', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final downloaded = Completer<String>(); var downloads = 0, cancellations = 0; var armed = false;
    final actions = ClientUpdateActions(supported: true,
      download: (_, _) { downloads++; return downloaded.future; },
      prepare: (_, _, _, queue) async { armed = queue; }, cancel: () async { cancellations++; armed = false; },
      attempted: (_) async => false,
      savePreference: (enabled) async => (await SharedPreferences.getInstance()).setBool(automaticUpdatesPreference, enabled));
    await tester.pumpWidget(BudgetismApp(updateActions: actions, releaseFeedFactory: fakeFeed)); await tester.pumpAndSettle();
    expect(downloads, 0); // Off by default even with an eligible release.
    await tester.ensureVisible(find.text('Explore with sample data'));
    await tester.tap(find.text('Explore with sample data')); await tester.pumpAndSettle();
    final activeSession = tester.state(find.byType(FinanceShell));
    await tester.tap(find.text('Update settings').first); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automatic-client-updates'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Save update settings')); await tester.pump(); await tester.pump(const Duration(milliseconds: 400));
    expect(downloads, 1);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Download')).onPressed, isNull);
    await tester.tap(find.text('Update settings').first); await tester.pump(); await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('automatic-client-updates'))); await tester.pump(); await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Save update settings')); await tester.pump(); await tester.pump(const Duration(milliseconds: 400));
    expect(cancellations, 1);
    downloaded.complete('fictional-archive'); await tester.pumpAndSettle();
    expect(downloads, 1); expect(armed, isFalse); expect(cancellations, greaterThanOrEqualTo(2));
    expect((await SharedPreferences.getInstance()).getBool(automaticUpdatesPreference), isFalse);
    expect(find.byType(ConnectionScreen), findsNothing); expect(find.byType(FinanceShell), findsOneWidget);
    expect(identical(tester.state(find.byType(FinanceShell)), activeSession), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('failed preference save retains off state and does not download', (tester) async {
    var downloads = 0;
    final actions = ClientUpdateActions(supported: true, download: (_, _) async { downloads++; return 'unused'; },
      prepare: (_, _, _, _) async {}, cancel: () async {}, attempted: (_) async => false, savePreference: (_) async => false);
    await tester.pumpWidget(BudgetismApp(updateActions: actions, releaseFeedFactory: fakeFeed)); await tester.pumpAndSettle();
    await tester.tap(find.text('Update settings').first); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('automatic-client-updates'))); await tester.pumpAndSettle();
    await tester.tap(find.text('Save update settings')); await tester.pumpAndSettle();
    expect(downloads, 0); expect(find.textContaining('could not be saved'), findsOneWidget);
    await tester.tap(find.text('Update settings').first); await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('automatic-client-updates'))).value, isFalse);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
