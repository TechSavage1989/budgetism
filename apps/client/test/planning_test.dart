import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/planning.dart';
import 'local_ledger_test.dart' show account, accounts, category;
import 'schedules_test.dart' show scheduleInput, onlySchedule, occurrenceInput;

LocalLedger planningFixture() => LocalLedger.empty()
  .apply('account', account('cash', 'Fictional checking', 100000))
  .apply('account', account('saving', 'Fictional savings', 20000, type: 'savings'));
Json recordInput(LocalLedger ledger, String op, String date, int amount, {String kind = 'expense'}) => {
  'operationId': op, 'kind': kind, 'amountMinor': amount, 'effectiveDate': date,
  'accountId': accounts(ledger).first['id'], 'currency': 'USD', 'payee': 'Fictional test', 'notes': '',
  'counterpartyAccountId': kind == 'transfer' ? accounts(ledger).last['id'] : category(ledger, kind == 'income' ? 'Income' : 'Expense'),
};

void main() {
  test('1000 plus scheduled 500 then minus 200 predicts 1500 then 1300 without any mutation', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'pay', kind: 'income', start: '2026-10-29', amount: 50000));
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-30', amount: 20000));
    final data = ledger.snapshot(includeVoided: true), before = jsonEncode(ledger.data), copy = jsonEncode(data);
    final id = accounts(ledger).first['id'];
    final result = PlanningEngine.forecast(data, today: '2026-10-28', days: 3);
    expect(result.starting[id], 100000);
    expect(result.days.map((d) => d.projected[id]), [100000, 150000, 130000]);
    expect(result.days.map((d) => d.recorded[id]), [100000, 100000, 100000]);
    expect(jsonEncode(ledger.data), before); expect(jsonEncode(data), copy);
  });
  test('today actuals are in start once; future actuals enter on their effective date', () {
    var ledger = planningFixture();
    ledger = ledger.apply('transaction', recordInput(ledger, 'today', '2026-10-28', 1000));
    ledger = ledger.apply('transaction', recordInput(ledger, 'future', '2026-10-29', 5000, kind: 'income'));
    final id = accounts(ledger).first['id'];
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 3);
    expect(result.starting[id], 99000);
    expect(result.days.map((d) => d.projected[id]), [99000, 104000, 104000]);
    expect(result.days.first.events.single.status, 'Recorded');
    expect(result.days[1].events.single.status, 'Recorded future');
  });
  test('confirmed bill changes from plan to actual once, even when recorded on another day', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-29', amount: 2000));
    ledger = ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'confirm', 0),
      'amountMinor': 2500, 'effectiveDate': '2026-10-28'});
    final id = accounts(ledger).first['id'];
    var result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 3);
    expect(result.starting[id], 97500); expect(result.days.last.projected[id], 97500);
    expect(result.days.expand((d) => d.events).length, 1);
    final tx = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('transaction', {...tx, 'operationId': 'edit', 'expectedVersion': 1, 'effectiveDate': '2026-10-30'});
    result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 3);
    expect(result.days.map((d) => d.projected[id]), [100000, 100000, 97500]);
    ledger = ledger.apply('void', {'operationId': 'void', 'id': tx['id'], 'expectedVersion': 2});
    result = PlanningEngine.forecast(ledger.snapshot(includeVoided: true), today: '2026-10-28', days: 3);
    expect(result.days.last.projected[id], 100000);
    expect(result.days.last.events.single.status, 'Voided');
    expect(result.days.expand((d) => d.events).any((e) => e.planned), isFalse);
  });
  test('postponing an old occurrence into range includes it once and respects the series end', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', {...scheduleInput(ledger, 'bill', start: '2026-01-31'), 'endDate': '2026-01-31'});
    ledger = ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'move', 0), 'dueDate': '2026-10-30'});
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 3);
    final id = accounts(ledger).first['id'];
    expect(result.days.last.projected[id], 98000);
    expect(result.days.last.events.single.status, 'Postponed');
    expect(result.overdueCounts[id], 0);
    final original = PlanningEngine.calendar(ledger.snapshot(), from: '2026-01-01', through: '2026-01-31', today: '2026-10-28');
    expect(original, isEmpty);
  });
  test('overdue backlog cannot truncate or displace future forecast activity', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'old', start: '1900-01-01', frequency: 'weekly', amount: 1));
    final id = accounts(ledger).first['id'];
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 365);
    expect(result.overdueCounts[id], greaterThan(6000));
    final planned = result.days.expand((d) => d.events).where((e) => e.planned).toList();
    expect(planned.length, greaterThanOrEqualTo(52)); expect(planned.length, lessThanOrEqualTo(53));
    expect(planned.every((e) => e.date.compareTo('2026-10-28') >= 0), isTrue);
    expect(result.days.last.projected[id], 100000 - planned.length);
  });
  test('skipped/paused schedules have no effect, history still shows skips', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-28'));
    ledger = ledger.apply('schedule-skip', occurrenceInput(ledger, 'skip', 0));
    final s = onlySchedule(ledger);
    ledger = ledger.apply('schedule-state', {'operationId': 'pause', 'id': s['id'], 'expectedVersion': 1, 'paused': true});
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 90);
    final id = accounts(ledger).first['id'];
    expect(result.days.every((d) => d.projected[id] == 100000), isTrue);
    expect(result.days.first.events.single.status, 'Skipped');
  });
  test('transfers move both accounts and cancel in the combined cash view', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'transfer', kind: 'transfer', start: '2026-10-29', amount: 5000));
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 2);
    final a = accounts(ledger);
    expect(result.days.last.projected[a.first['id']], 95000);
    expect(result.days.last.projected[a.last['id']], 25000);
    expect(result.days.last.total(a.map((a) => a['id'] as String).toSet()), 120000);
  });
  test('overdue and allocations do not become actual or scheduled spending', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', {...scheduleInput(ledger, 'old', start: '2026-09-01'), 'endDate': '2026-09-01'});
    ledger = ledger.apply('budget', {'operationId': 'budget', 'month': '2026-10', 'categoryId': category(ledger, 'Expense'),
      'amountMinor': 80000, 'rollover': 'all', 'expectedVersion': 0});
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28');
    final id = accounts(ledger).first['id'];
    expect(result.overdueCounts[id], 1); expect(result.days.last.projected[id], 100000);
  });
  test('month end and leap-day anchors are shared by calendar and forecast', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2028-01-31'));
    final events = PlanningEngine.calendar(ledger.snapshot(), from: '2028-02-01', through: '2028-03-31', today: '2028-02-01');
    expect(events.map((e) => e.date), ['2028-02-29', '2028-03-31']);
    expect(PlanningEngine.forecast(ledger.snapshot(), today: '2028-02-28', days: 3).days.map((d) => d.date),
      ['2028-02-28', '2028-02-29', '2028-03-01']);
  });
  test('minimum warning uses strict end-of-day comparison and each account separately', () {
    var ledger = planningFixture();
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'bill', start: '2026-10-29', amount: 100000));
    final result = PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 3);
    final id = accounts(ledger).first['id'];
    expect(result.firstBelow(id, 0), isNull); expect(result.firstBelow(id, 1), '2026-10-29');
    expect(result.firstBelow(accounts(ledger).last['id'], 1), isNull);
  });
  test('legacy schemas read without migration and unsupported ranges fail explicitly', () {
    final source = LocalLedger.clone(planningFixture().data)..['schema'] = 1
      ..remove('budgets')..remove('schedules')..remove('occurrences');
    final ledger = LocalLedger(source), before = jsonEncode(source);
    PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28');
    expect(jsonEncode(source), before); expect(ledger.data['schema'], 1);
    expect(() => PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 0), throwsFormatException);
    expect(() => PlanningEngine.forecast(ledger.snapshot(), today: '2026-10-28', days: 366), throwsFormatException);
    expect(() => PlanningEngine.forecast(ledger.snapshot(), today: '9999-12-31', days: 2), throwsFormatException);
  });
}
