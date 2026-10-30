// Fictional native UI acceptance. No network, package download or installer calls.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/main.dart';
import 'package:budgetism/release_feed.dart';
import 'package:budgetism/update_actions.dart';
import 'package:budgetism/update_pending.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native update settings cancel and save preserve the active fictional session', (tester) async {
    final capture = GlobalKey();
    final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
    final original = prefs.getBool(automaticUpdatesPreference);
    var downloads = 0, preparations = 0, cancellations = 0;
    final actions = ClientUpdateActions(supported: true,
      download: (_, _) async { downloads++; throw StateError('No fixture downloads'); },
      prepare: (_, _, _, _) async { preparations++; },
      cancel: () async { cancellations++; }, attempted: (_) async => false,
      savePreference: (enabled) => prefs.setBool(automaticUpdatesPreference, enabled));
    Future<void> openSettings() async {
      await tester.tap(find.text('Update settings').first);
      await tester.pumpAndSettle();
      expect(find.text('Budgetism updates'), findsOneWidget);
    }
    final toggle = find.byKey(const ValueKey('automatic-client-updates'));
    try {
      await tester.runAsync(() async { expect(await prefs.setBool(automaticUpdatesPreference, false), isTrue); });
      await tester.pumpWidget(RepaintBoundary(key: capture, child: BudgetismApp(
        startupMessage: 'Fictional native update-settings acceptance; no published package is used.',
        updateActions: actions,
        // A failed mock response neither contacts GitHub nor changes release caches.
        releaseFeedFactory: (p) => ReleaseFeed(prefs: p,
          client: MockClient((_) async => http.Response('Fictional offline fixture', 503))),
      )));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore with sample data'));
      await tester.tap(find.text('Explore with sample data'));
      await tester.pumpAndSettle();
      final session = tester.state(find.byType(FinanceShell));
      await openSettings();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle); await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
      expect(prefs.getBool(automaticUpdatesPreference), isFalse);
      await openSettings();
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle); await tester.pumpAndSettle();
      expect(find.textContaining('Your active session is never automatically closed.'), findsOneWidget);
      expect(find.textContaining('not publisher signatures'), findsOneWidget);
      final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await tester.runAsync(() async {
        final file = File('build/update-settings-dev27-native.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
      await tester.tap(find.text('Save update settings')); await tester.pumpAndSettle();
      expect(prefs.getBool(automaticUpdatesPreference), isTrue);
      await openSettings();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle); await tester.pumpAndSettle();
      await tester.tap(find.text('Save update settings')); await tester.pumpAndSettle();
      expect(prefs.getBool(automaticUpdatesPreference), isFalse);
      expect(cancellations, 1);
      expect(downloads, 0); expect(preparations, 0);
      expect(find.byType(ConnectionScreen), findsNothing);
      expect(identical(tester.state(find.byType(FinanceShell)), session), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        final restored = original == null
          ? await prefs.remove(automaticUpdatesPreference)
          : await prefs.setBool(automaticUpdatesPreference, original);
        expect(restored, isTrue);
        await prefs.reload();
        expect(prefs.getBool(automaticUpdatesPreference), original);
      });
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
