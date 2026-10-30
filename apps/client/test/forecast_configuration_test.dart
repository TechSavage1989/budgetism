import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/planning.dart';
import 'local_ledger_test.dart' show accounts;
import 'planning_test.dart' show planningFixture, recordInput;
import 'schedules_test.dart' show scheduleInput, occurrenceInput;

void main() {
  test('schedule exclusions retain recorded future activity, exact baseline and immutable input', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-29', amount: 20000));
    final schedule = LocalLedger.rows(ledger.data['schedules']).single;
    ledger = ledger.apply('transaction', recordInput(ledger, 'future', '2026-10-30', 5000, kind: 'income'));
    final data = ledger.snapshot(), before = jsonEncode(ledger.data), snapshotBefore = jsonEncode(data);
    final id = accounts(ledger).first['id'];
    final baseline = PlanningEngine.forecast(data, today: '2026-10-28', days: 3);
    final scenario = PlanningEngine.forecast(data, today: '2026-10-28', days: 3,
      excludedScheduleIds: {schedule['id'] as String});
    expect(baseline.days.map((d) => d.projected[id]), [100000, 80000, 85000]);
    expect(scenario.days.map((d) => d.projected[id]), [100000, 100000, 105000]);
    expect(scenario.days.map((d) => d.recorded[id]), baseline.days.map((d) => d.recorded[id]));
    expect(scenario.days.expand((d) => d.events).where((e) => e.planned), isEmpty);
    final reset = PlanningEngine.forecast(data, today: '2026-10-28', days: 3, excludedScheduleIds: {});
    expect(reset.days.map((d) => d.projected[id]), baseline.days.map((d) => d.projected[id]));
    expect(jsonEncode(ledger.data), before); expect(jsonEncode(data), snapshotBefore);
  });
  test('excluding linked schedule never removes confirmed future transaction', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-29', amount: 2000));
    final schedule = LocalLedger.rows(ledger.data['schedules']).single;
    ledger = ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'confirm', 0),
      'amountMinor': 2500, 'effectiveDate': '2026-10-30'});
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 3,
      excludedScheduleIds: {schedule['id'] as String});
    final id = accounts(ledger).first['id'];
    expect(result.days.map((d) => d.projected[id]), [100000, 100000, 97500]);
    expect(result.days.last.events.single.status, 'Recorded future');
  });
  test('excluded transfer preserves both sides and overdue disclosure without fake payments', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'transfer', kind: 'transfer', start: '2026-09-29', amount: 5000));
    final schedule = LocalLedger.rows(ledger.data['schedules']).single;
    final data = ledger.snapshot();
    final baseline = PlanningEngine.forecast(data, today: '2026-10-28', days: 3);
    final scenario = PlanningEngine.forecast(data, today: '2026-10-28', days: 3,
      excludedScheduleIds: {schedule['id'] as String});
    final a = accounts(ledger), ids = a.map((a) => a['id'] as String).toSet();
    expect(baseline.days.last.total(ids), scenario.days.last.total(ids));
    expect(scenario.days.last.projected[a.first['id']], 100000);
    expect(scenario.days.last.projected[a.last['id']], 20000);
    expect(scenario.overdueCounts, baseline.overdueCounts);
    expect(scenario.overdueCounts[a.first['id']], 1);
  });
  test('one day includes today unresolved schedules and handles zero and negative balances', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-28', amount: 120001));
    final id = accounts(ledger).first['id'];
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 1);
    expect(result.days.length, 1); expect(result.days.single.projected[id], -20001);
    expect(result.days.single.recorded[id], 100000);
    expect(result.firstBelow(id, 0), '2026-10-28');
    expect(() => PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', excludedScheduleIds: {'unknown'}),
      throwsFormatException);
  });
}
