import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/local/local_api.dart';
import 'package:budgetism/local/planning_widgets.dart';
import 'package:budgetism/local/vault.dart';
import 'local_security_test.dart' show TestStorage, TestDeviceKeys;
import 'planning_test.dart' show planningFixture;

void main() {
  for (final calendar in [true, false]) {
    for (final width in [430.0, 1100.0]) {
      testWidgets('${calendar ? 'calendar' : 'forecast'} works at $width pixels without writing finances', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 1100); tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
        late LocalVault vault;
        await tester.runAsync(() async {
          vault = await LocalVault.open(TestStorage(), '', create: true, requirePassword: false, deviceKeys: TestDeviceKeys());
          for (final a in planningFixture().data['accounts'] as List) {
            await vault.apply('account', {'operationId': a['id'], 'name': a['name'], 'type': a['type'],
              'currency': 'USD', 'openingBalanceMinor': a['openingBalanceMinor']});
          }
        });
        final revision = vault.ledger.revision;
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(16), child: PlanningPanel(api: LocalFinanceApi(vault), calendar: calendar,
            today: '2026-10-28', onOpenTransaction: (_) async {}, onOpenScheduled: () {}))))));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
        if (calendar) {
          await tester.tap(find.byKey(const ValueKey('calendar-2026-10-15'))); await tester.pumpAndSettle();
          expect(find.text('Activity on 2026-10-15'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('calendar-next'))); await tester.pumpAndSettle();
          expect(find.text('November 2026'), findsOneWidget);
        } else {
          expect(find.text('Scheduled cash-flow forecast'), findsOneWidget);
          await tester.ensureVisible(find.byType(Slider));
          await tester.drag(find.byType(Slider), const Offset(60, 0)); await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull); expect(vault.ledger.revision, revision);
        await tester.pumpWidget(const SizedBox.shrink()); await tester.runAsync(vault.close);
      });
    }
  }
}
