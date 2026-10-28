import 'package:flutter_test/flutter_test.dart';
import 'package:budgetism/local/ledger.dart';
import 'package:budgetism/local/recurrence.dart';
import 'package:budgetism/local/schedules.dart';
import 'package:budgetism/local/budgets.dart';
import 'local_ledger_test.dart' show account, accounts, category;
import 'budgets_test.dart' show plan;

Json scheduleInput(LocalLedger ledger, String operation, {String kind = 'expense', String start = '2026-01-31',
    String frequency = 'monthly', int amount = 2000}) => {
  'operationId': operation, 'expectedVersion': 0, 'name': 'Fictional scheduled $kind', 'kind': kind,
  'accountId': accounts(ledger).first['id'], 'counterpartyAccountId': kind == 'transfer'
    ? accounts(ledger).last['id'] : category(ledger, kind == 'income' ? 'Income' : 'Expense'),
  'amountMinor': amount, 'currency': 'USD', 'payee': 'Fictional payee', 'notes': '',
  'startDate': start, 'frequency': frequency, 'endDate': null,
};
Json onlySchedule(LocalLedger ledger) => LocalLedger.rows(ledger.data['schedules']).single;
Json occurrenceInput(LocalLedger ledger, String operation, int index) {
  final schedule = onlySchedule(ledger);
  final records = LocalLedger.rows(ledger.data['occurrences']).where((o) => o['index'] == index).toList();
  return {'operationId': operation, 'scheduleId': schedule['id'], 'index': index,
    'expectedScheduleVersion': schedule['version'], 'expectedOccurrenceVersion': records.isEmpty ? 0 : records.single['version']};
}

void main() {
  late LocalLedger ledger;
  setUp(() {
    ledger = LocalLedger.empty().apply('account', account('cash', 'Fictional checking', 100000))
      .apply('account', account('card', 'Fictional card', 0, type: 'credit_card'));
  });
  test('calendar anchors do not drift across short months, leap years or DST', () {
    expect([for (var i = 0; i < 4; i++) Recurrence.at('2026-01-31', 'monthly', i)],
      ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30']);
    expect(Recurrence.at('2024-02-29', 'yearly', 1), '2025-02-28');
    expect(Recurrence.at('2024-02-29', 'yearly', 4), '2028-02-29');
    expect(Recurrence.at('2026-03-01', 'weekly', 2), '2026-03-15');
    expect(Recurrence.at('2026-10-25', 'fortnightly', 1), '2026-11-08');
    expect(Recurrence.lastIndex('2026-01-31', 'monthly', '2026-02-27'), 0);
    expect(Recurrence.lastIndex('2026-01-31', 'monthly', '2026-02-28'), 1);
    expect(Recurrence.lastIndex('2026-01-31', 'monthly', '2025-12-31'), -1);
    expect(Recurrence.at('9999-12-31', 'monthly', 1), isNull);
    expect(() => Recurrence.parse('2026-02-29'), throwsFormatException);
    expect(() => Recurrence.parse('2026-13-01'), throwsFormatException);
    expect(() => Recurrence.at('2026-01-01', 'daily', 0), throwsFormatException);
  });
  test('a schedule and postponement never change balances or budget spending', () {
    final cat = category(ledger, 'Expense');
    ledger = ledger.apply('budget', plan('budget', cat, '2026-01', 5000));
    final balances = ledger.snapshot()['accounts'];
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'create'));
    expect(ledger.snapshot()['accounts'], balances);
    expect(BudgetEngine.calculate(ledger.snapshot(), '2026-01').spent, 0);
    ledger = ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'delay', 0), 'dueDate': '2026-02-05'});
    final upcoming = ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-02-01', days: 60).items;
    expect(upcoming.map((o) => o.dueDate), ['2026-02-05', '2026-02-28', '2026-03-31']);
    expect(ledger.snapshot()['transactions'], isEmpty);
    expect(ledger.snapshot()['accounts'], balances);
  });
  test('confirmation changes actual balances and budget exactly once across new operation IDs', () {
    ledger = ledger.apply('budget', plan('budget', category(ledger, 'Expense'), '2026-01', 10000));
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'schedule'));
    final command = {...occurrenceInput(ledger, 'record', 0), 'amountMinor': 2345, 'effectiveDate': '2026-01-30'};
    ledger = ledger.apply('schedule-confirm', command);
    expect(accounts(ledger).first['balanceMinor'], 97655);
    expect(BudgetEngine.calculate(ledger.snapshot(), '2026-01').remaining, 7655);
    expect(identical(ledger.apply('schedule-confirm', command), ledger), isTrue);
    expect(() => ledger.apply('schedule-confirm', {...command, 'operationId': 'duplicate'}), throwsFormatException);
    expect(() => ledger.apply('schedule-confirm', {...command, 'amountMinor': 1}), throwsFormatException);
    expect(LocalLedger.rows(ledger.data['transactions']).length, 1);
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-02-01').items.first.index, 1);
  });
  test('income and transfer/card payment post correctly and do not count as expenses', () {
    for (final kind in ['income', 'transfer']) {
      var value = ledger.apply('schedule', scheduleInput(ledger, 'create-$kind', kind: kind));
      value = value.apply('schedule-confirm', {...occurrenceInput(value, 'confirm-$kind', 0),
        'amountMinor': 5000, 'effectiveDate': '2026-01-31'});
      expect(accounts(value).first['balanceMinor'], kind == 'income' ? 105000 : 95000);
      expect(accounts(value).last['balanceMinor'], kind == 'transfer' ? 5000 : 0);
      expect(BudgetEngine.calculate(value.snapshot(), '2026-01').spent, 0);
    }
  });
  test('skipping settles one occurrence without posting or shifting later dates', () {
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'create'));
    ledger = ledger.apply('schedule-skip', occurrenceInput(ledger, 'skip', 0));
    expect(ledger.snapshot()['transactions'], isEmpty);
    expect(accounts(ledger).first['balanceMinor'], 100000);
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-02-01').items.first.dueDate, '2026-02-28');
    expect(() => ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'try-again', 0),
      'amountMinor': 1000, 'effectiveDate': '2026-01-31'}), throwsFormatException);
  });
  test('edit and void preserve occurrence linkage and never regenerate a settled bill', () {
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'create'));
    ledger = ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'confirm', 0),
      'amountMinor': 2000, 'effectiveDate': '2026-01-31'});
    final tx = LocalLedger.rows(ledger.data['transactions']).single;
    ledger = ledger.apply('transaction', {...tx, 'operationId': 'edit', 'expectedVersion': 1, 'amountMinor': 3000});
    expect(LocalLedger.rows(ledger.data['transactions']).single['scheduleId'], onlySchedule(ledger)['id']);
    expect(BudgetEngine.calculate(ledger.snapshot(), '2026-01').spent, 3000);
    ledger = ledger.apply('void', {'operationId': 'void', 'id': tx['id'], 'expectedVersion': 2});
    expect(accounts(ledger).first['balanceMinor'], 100000);
    expect(BudgetEngine.calculate(ledger.snapshot(), '2026-01').spent, 0);
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-02-01').items.every((o) => o.index != 0), isTrue);
  });
  test('pause/resume retains overdue dates; future template edits reject stale confirmation', () {
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'create'));
    final stale = occurrenceInput(ledger, 'stale', 0);
    var schedule = onlySchedule(ledger);
    ledger = ledger.apply('schedule-state', {'operationId': 'pause', 'id': schedule['id'], 'expectedVersion': 1, 'paused': true});
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-10-27').items, isEmpty);
    expect(() => ledger.apply('schedule-skip', stale), throwsFormatException);
    ledger = ledger.apply('schedule-state', {'operationId': 'resume', 'id': schedule['id'], 'expectedVersion': 2, 'paused': false});
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-10-27').items.first.dueDate, '2026-01-31');
    schedule = onlySchedule(ledger);
    ledger = ledger.apply('schedule', {...schedule, 'operationId': 'edit', 'expectedVersion': 3, 'amountMinor': 9900});
    expect(() => ledger.apply('schedule-confirm', {...stale, 'amountMinor': 2000, 'effectiveDate': '2026-01-31'}), throwsFormatException);
    expect(ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-02-01').items.first.amount, 9900);
    expect(() => ledger.apply('schedule', {...onlySchedule(ledger), 'operationId': 'move-anchor',
      'expectedVersion': 4, 'frequency': 'weekly'}), throwsFormatException);
  });
  test('inclusive end date, postponed final date and bounded earliest-date ordering', () {
    ledger = ledger.apply('schedule', {...scheduleInput(ledger, 'create', frequency: 'weekly', start: '2026-01-01'), 'endDate': '2026-01-15'});
    ledger = ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'p0', 0), 'dueDate': '2026-01-30'});
    ledger = ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'p2', 2), 'dueDate': '2026-02-10'});
    final first = ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-01-01', days: 60, limit: 1);
    expect(first.items.single.dueDate, '2026-01-08'); expect(first.hasMore, isTrue);
    final all = ScheduleEngine.upcoming(ledger.snapshot(), today: '2026-01-01', days: 60);
    expect(all.items.map((o) => o.dueDate), ['2026-01-08', '2026-01-30', '2026-02-10']);
    expect(() => ledger.apply('schedule-skip', occurrenceInput(ledger, 'outside', 3)), throwsFormatException);
  });
  test('occurrence revisions, invalid dates and invalid amounts fail without changing data', () {
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'create'));
    final stale = occurrenceInput(ledger, 'stale', 0);
    ledger = ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'postpone', 0), 'dueDate': '2026-02-01'});
    expect(() => ledger.apply('schedule-skip', stale), throwsFormatException);
    expect(() => ledger.apply('schedule-postpone', {...occurrenceInput(ledger, 'backwards', 0), 'dueDate': '2026-01-31'}), throwsFormatException);
    expect(() => ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'zero', 0),
      'amountMinor': 0, 'effectiveDate': '2026-02-01'}), throwsFormatException);
    expect(ledger.snapshot()['transactions'], isEmpty);
  });
  test('schema-2 upgrade requires consent and retains budgets, accounts and transactions', () {
    ledger = ledger.apply('budget', plan('budget', category(ledger, 'Expense'), '2026-01', 10000));
    final oldData = LocalLedger.clone(ledger.data)..['schema'] = LocalLedger.budgetSchema;
    oldData.remove('schedules'); oldData.remove('occurrences');
    final old = LocalLedger(oldData);
    final command = scheduleInput(old, 'migrate');
    expect(() => old.apply('schedule', command), throwsFormatException);
    final upgraded = old.apply('schedule', {...command, 'confirmScheduleUpgrade': true});
    expect(upgraded.data['schema'], LocalLedger.schema);
    for (final key in ['accounts', 'categories', 'transactions', 'budgets']) { expect(upgraded.data[key], oldData[key]); }
    expect(() => LocalLedger({...upgraded.data, 'schema': LocalLedger.budgetSchema}), throwsFormatException);
  });
  test('restored data rejects duplicate occurrences and broken transaction relationships', () {
    ledger = ledger.apply('schedule', scheduleInput(ledger, 'create'));
    ledger = ledger.apply('schedule-confirm', {...occurrenceInput(ledger, 'confirm', 0), 'amountMinor': 2000, 'effectiveDate': '2026-01-31'});
    var altered = LocalLedger.clone(ledger.data);
    (altered['occurrences'] as List).add({...LocalLedger.rows(altered['occurrences']).single, 'id': 'duplicate-occurrence'});
    expect(() => LocalLedger(altered), throwsFormatException);
    altered = LocalLedger.clone(ledger.data);
    (altered['transactions'] as List).single.remove('scheduleId');
    expect(() => LocalLedger(altered), throwsFormatException);
    altered = LocalLedger.clone(ledger.data);
    (altered['occurrences'] as List).single['originalDueDate'] = '2026-02-28';
    expect(() => LocalLedger(altered), throwsFormatException);
  });
}
