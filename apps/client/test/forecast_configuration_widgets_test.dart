import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/planning_api.dart';
import 'package:budgetism/local/planning_widgets.dart';
import 'planning_test.dart' show planningFixture;
import 'schedules_test.dart' show scheduleInput;

class ReadOnlyPlanningApi implements PlanningWorkspaceApi {
  ReadOnlyPlanningApi(this.data);
  final Json data;
  @override
  Json get planningSnapshot => data;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('Unexpected planning mutation');
}

void main() {
  for (final width in [390.0, 1100.0]) {
    testWidgets('forecast scenario apply cancel reset and single-day chart at $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      var ledger = planningFixture();
      ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-28', amount: 120001));
      final data = ledger.snapshot(), before = jsonEncode(ledger.data), snapshotBefore = jsonEncode(data);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(16), child: PlanningPanel(api: ReadOnlyPlanningApi(data), calendar: false,
          today: '2026-10-28', onOpenTransaction: (_) async {}, onOpenScheduled: () {}))))));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('configure-forecast')));
      await tester.tap(find.byKey(const ValueKey('configure-forecast'))); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), '1');
      await tester.tap(find.byKey(const ValueKey('forecast-exclude-all')));
      await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:30')), findsOneWidget);
      expect(find.text('Baseline: all active unresolved schedules. No what-if exclusions.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('configure-forecast'))); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), '366');
      await tester.tap(find.byKey(const ValueKey('apply-forecast-configuration'))); await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 365 days.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), '1');
      await tester.tap(find.byKey(const ValueKey('forecast-exclude-all')));
      await tester.tap(find.byKey(const ValueKey('apply-forecast-configuration'))); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:1')), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('What-if scenario: 1 schedule(s) excluded.'), findsOneWidget);
      expect(find.textContaining('Normal schedule baseline:'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('reset-forecast')));
      await tester.tap(find.byKey(const ValueKey('reset-forecast'))); await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('forecast-horizon:30')), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Baseline: all active unresolved schedules. No what-if exclusions.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(jsonEncode(ledger.data), before); expect(jsonEncode(data), snapshotBefore);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('forecast configuration rejects invalid syntax and preserves exclusions on cancel', (tester) async {
    final ledger = planningFixture();
    ForecastConfiguration? accepted;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () async { accepted = await showDialog<ForecastConfiguration>(context: context,
        builder: (_) => ForecastConfigurationDialog(days: 30, excludedScheduleIds: const {}, schedules: LocalLedger.rows(ledger.data['schedules']))); },
      child: const Text('Open')))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    for (final value in ['0', '-1', '1.5', '1e2', '']) {
      await tester.enterText(find.byKey(const ValueKey('forecast-custom-days')), value);
      await tester.tap(find.byKey(const ValueKey('apply-forecast-configuration'))); await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 365 days.'), findsOneWidget);
    }
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle(); expect(accepted, isNull);
  });
}
